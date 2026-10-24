package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
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
func (p *fakeProvider) Source(context.Context, string) (*url.URL, error) {
	return url.Parse("https://emby.example/emby/Videos/1/stream?static=true")
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

func TestSegmentValidationAndLoopbackSource(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	if w := request(s, "GET", "/cinema/api/segment?kind=video&start=0&len=5", "", ""); w.Code != 401 {
		t.Fatal("anonymous segment", w.Code)
	}
	viewer := login(t, s, "viewer")
	for _, q := range []string{"kind=x&start=0&len=5", "kind=video&start=-1&len=5", "kind=video&start=0&len=99", "kind=video&start=NaN&len=5"} {
		if w := request(s, "GET", "/cinema/api/segment?"+q, "", viewer); w.Code != 400 {
			t.Fatal(q, w.Code)
		}
	}
	s.ffmpeg = "/bin/true"
	if w := request(s, "GET", "/cinema/api/segment?kind=video&start=0&len=5", "", viewer); w.Code != 409 {
		t.Fatal("no film", w.Code)
	}
	s.sources["tok"] = "1"
	if w := request(s, "GET", "/cinema/internal/source/tok", "", ""); w.Code != 404 {
		t.Fatal("non-loopback source must 404", w.Code)
	}
}

func TestFrameJPEGs(t *testing.T) {
	a, b := []byte{0xFF, 0xD8, 0xFF, 1, 2, 0xFF, 0xD9}, []byte{0xFF, 0xD8, 0xFF, 3, 0xFF, 0xD9}
	out := frameJPEGs(append(append([]byte{}, a...), b...))
	if len(out) != 8+len(a)+len(b) || out[0] != byte(len(a)) || out[4+len(a)] != byte(len(b)) {
		t.Fatal("framing", out)
	}
}

func TestSegmentCacheSharesOneTranscode(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	dir := t.TempDir()
	count := dir + "/count"
	script := dir + "/ffmpeg"
	os.WriteFile(script, []byte("#!/bin/sh\necho x >> "+count+"\nprintf 'ID3audio'\n"), 0o755)
	s.ffmpeg = script
	s.state.Title = Title{ID: "1", Title: "Test", Duration: 120}
	viewer := login(t, s, "viewer")
	for i := 0; i < 3; i++ {
		if w := request(s, "GET", "/cinema/api/segment?kind=audio&start=10&len=10", "", viewer); w.Code != 200 || w.Body.String() != "ID3audio" {
			t.Fatal(i, w.Code, w.Body)
		}
	}
	if b, _ := os.ReadFile(count); strings.Count(string(b), "x") != 1 {
		t.Fatal("expected one transcode, got", string(b))
	}
}
