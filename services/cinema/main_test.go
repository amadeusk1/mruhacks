package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

type fakeProvider struct{ opens int }

func (p *fakeProvider) Catalog(context.Context, string) ([]Title, error) {
	return []Title{{"1", "Test", 2026, 120}}, nil
}
func (p *fakeProvider) Open(context.Context, string) (Playback, error) {
	p.opens++
	u, _ := url.Parse("https://emby.example/emby/videos/1/master.m3u8?api_key=secret")
	return Playback{u, "session", Title{"1", "Test", 2026, 120}}, nil
}
func (p *fakeProvider) Stop(context.Context, string) error { return nil }
func (p *fakeProvider) Fetch(context.Context, *url.URL, string) (*http.Response, error) {
	return &http.Response{StatusCode: 200, Header: http.Header{"Content-Type": []string{"application/vnd.apple.mpegurl"}}, Body: io.NopCloser(strings.NewReader("#EXTM3U\nsegment.ts?api_key=secret\n"))}, nil
}
func request(s *Server, method, path, body, cookie string) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("Origin", s.origin)
	if cookie != "" {
		r.Header.Set("Cookie", cookie)
	}
	w := httptest.NewRecorder()
	s.handler().ServeHTTP(w, r)
	return w
}
func login(t *testing.T, s *Server, code string) string {
	t.Helper()
	w := request(s, "POST", "/cinema/api/login", `{"name":"Test","code":"`+code+`"}`, "")
	if w.Code != 200 {
		t.Fatal(w.Code, w.Body)
	}
	return w.Result().Cookies()[0].String()
}
func TestPermissionsAndDedup(t *testing.T) {
	p := &fakeProvider{}
	s := newServer(p, "http://localhost", "host", "viewer")
	host := login(t, s, "host")
	viewer := login(t, s, "viewer")
	payload := `{"action":"load","id":"1","generation":0,"requestId":"one"}`
	if w := request(s, "POST", "/cinema/api/control", payload, viewer); w.Code != 403 {
		t.Fatal("viewer changed state", w.Code)
	}
	if w := request(s, "POST", "/cinema/api/control", payload, host); w.Code != 200 {
		t.Fatal(w.Code, w.Body)
	}
	if w := request(s, "POST", "/cinema/api/control", payload, host); w.Code != 200 {
		t.Fatal(w.Code, w.Body)
	}
	if p.opens != 1 {
		t.Fatal("duplicate load", p.opens)
	}
	if w := request(s, "POST", "/cinema/api/control", `{"action":"seek","position":999,"generation":1,"requestId":"bad"}`, host); w.Code != 400 {
		t.Fatal(w.Code)
	}
	if w := request(s, "POST", "/cinema/api/control", `{"action":"play","generation":0,"requestId":"stale"}`, host); w.Code != 409 {
		t.Fatal(w.Code)
	}
	if w := request(s, "GET", "/cinema/media/stream?g=1", "", ""); w.Code != 401 {
		t.Fatal("unauthed media", w.Code)
	}
	w := request(s, "GET", "/cinema/media/stream?g=1", "", viewer)
	if w.Code != 200 || strings.Contains(w.Body.String(), "secret") {
		t.Fatal("media rewrite", w.Code, w.Body)
	}
	if w := request(s, "GET", "/cinema/media/stream?g=0", "", viewer); w.Code != 410 {
		t.Fatal("stale media", w.Code)
	}
}
func TestPlaylistRewriteAndOrigin(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	s.state.Generation = 2
	u, _ := url.Parse("https://emby.example/a/master.m3u8?api_key=secret")
	out, e := s.rewritePlaylist("#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"key?api_key=secret\"\n#EXT-X-MAP:URI=\"init.mp4\"\nchild/index.m3u8\n", u, 2)
	if e != nil || strings.Contains(out, "secret") || strings.Count(out, "/cinema/media/") != 3 {
		t.Fatal(out, e)
	}
	for _, bad := range []string{"https://evil.example/a", "//evil.example/b", "file:///etc/passwd"} {
		if _, e := s.rewritePlaylist("#EXTM3U\n"+bad, u, 2); e == nil {
			t.Fatal("accepted", bad)
		}
	}
	if _, e := s.rewritePlaylist("#EXTM3U\na.ts", u, 1); e == nil {
		t.Fatal("stale generation accepted")
	}
}
func TestCSRFAndHostLoss(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	host := login(t, s, "host")
	r := httptest.NewRequest("POST", "/cinema/api/logout", strings.NewReader("{}"))
	r.Header.Set("Cookie", host)
	r.Header.Set("Origin", "https://evil.example")
	w := httptest.NewRecorder()
	s.handler().ServeHTTP(w, r)
	if w.Code != 403 {
		t.Fatal(w.Code)
	}
	s.mu.Lock()
	s.state.Title.Duration = 120
	s.state.Playing = true
	s.state.Position = 20
	s.state.Updated = time.Now().Add(-time.Second).UnixMilli()
	s.sessions[s.controller].Seen = time.Now().Add(-20 * time.Second)
	s.mu.Unlock()
	st := s.snapshot()
	if st.Playing || st.Controller != "" || st.Position < 20 {
		t.Fatal(st)
	}
}
func TestEmbyNegotiation(t *testing.T) {
	var called bool
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Emby-Token") != "key" {
			t.Error("missing auth")
		}
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/emby/Users/user/Items/1":
			io.WriteString(w, `{"Id":"1","Name":"Test","RunTimeTicks":1200000000}`)
		case "/emby/Items/1/PlaybackInfo":
			var body map[string]any
			json.NewDecoder(r.Body).Decode(&body)
			if body["UserId"] != "user" || body["EnableDirectPlay"] != false {
				t.Error(body)
			}
			called = true
			io.WriteString(w, `{"PlaySessionId":"session","MediaSources":[{"TranscodingUrl":"/emby/videos/1/master.m3u8?api_key=key"}]}`)
		default:
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()
	p, e := newEmby(upstream.URL, "key", "user")
	if e != nil {
		t.Fatal(e)
	}
	play, e := p.Open(context.Background(), "1")
	if e != nil || !called || play.Title.Duration != 120 || play.URL.Host != strings.TrimPrefix(upstream.URL, "http://") {
		t.Fatal(play, e)
	}
	evil, _ := url.Parse("https://other.example/movie")
	if _, e := p.Fetch(context.Background(), evil, ""); e == nil {
		t.Fatal("leaked credentials to other origin")
	}
}

func TestIdleRoomReleasesStream(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	host := login(t, s, "host")
	request(s, "POST", "/cinema/api/control", `{"action":"load","id":"1","generation":0,"requestId":"load"}`, host)
	s.cleanupIdle()
	if s.upstreamSession == "" {
		t.Fatal("active room was stopped")
	}
	for _, u := range s.sessions {
		u.Seen = time.Now().Add(-61 * time.Second)
	}
	s.cleanupIdle()
	if s.upstreamSession != "" || s.state.Title.ID != "" || len(s.resources) != 0 {
		t.Fatal("idle stream retained")
	}
}

func TestHandoffTicketIsSingleUseAndViewOnly(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	host := login(t, s, "host")
	if w := request(s, "POST", "/cinema/api/handoff", `{}`, ""); w.Code != 401 {
		t.Fatal("handoff without session", w.Code)
	}
	w := request(s, "POST", "/cinema/api/handoff", `{}`, host)
	var out struct{ Ticket string }
	json.NewDecoder(w.Body).Decode(&out)
	if w.Code != 200 || out.Ticket == "" {
		t.Fatal(w.Code)
	}
	r := request(s, "POST", "/cinema/api/ticket", `{"ticket":"`+out.Ticket+`"}`, "")
	if r.Code != 200 {
		t.Fatal(r.Code, r.Body)
	}
	surface := r.Result().Cookies()[0].String()
	if again := request(s, "POST", "/cinema/api/ticket", `{"ticket":"`+out.Ticket+`"}`, ""); again.Code != 403 {
		t.Fatal("ticket reused", again.Code)
	}
	if c := request(s, "POST", "/cinema/api/claim", `{}`, surface); c.Code != 403 {
		t.Fatal("video surface could claim the remote", c.Code)
	}
	if m := request(s, "GET", "/cinema/api/state", "", surface); m.Code != 200 {
		t.Fatal("surface cannot read state", m.Code)
	}
}
