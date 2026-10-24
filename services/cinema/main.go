// Pengloo's Emby gateway follows plex-watchparty's server timeline + HLS proxy architecture.
// See THIRD_PARTY.md for the reviewed upstream and the vendored browser decoder.
package main

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/subtle"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

//go:embed web/*
var web embed.FS

type State struct {
	Title      Title   `json:"media"`
	Playing    bool    `json:"playing"`
	Position   float64 `json:"position"`
	Updated    int64   `json:"updatedAt"`
	Generation int64   `json:"generation"`
	Revision   int64   `json:"revision"`
	Controller string  `json:"controller"`
	Viewers    int     `json:"viewers"`
	ServerNow  int64   `json:"serverNow"`
}
type session struct {
	ID, Name      string
	Eligible      bool
	Expires, Seen time.Time
}
type mediaURL struct {
	URL        *url.URL
	Generation int64
}
type Server struct {
	mu                           sync.Mutex
	commands                     sync.Mutex
	provider                     Provider
	origin, hostCode, viewerCode string
	secure                       bool
	sessions                     map[string]*session
	resources                    map[string]mediaURL
	reverse                      map[string]string
	state                        State
	controller, upstreamSession  string
	seenCommands                 map[string]bool
	attempts                     map[string][]time.Time
	tickets                      map[string]handoff
	sources                      map[string]string // segment token -> media id (segments.go)
	segments                     map[string]*cachedSegment
	ffmpeg, selfURL              string
	ffmpegSlots                  chan struct{}
}

// handoff lets the game client (which signed in with the invite code) open the embedded video
// surface without the webview ever seeing the code: single use, 60 s, view-only session.
type handoff struct {
	Name    string
	Expires time.Time
}

func randomID() string {
	b := make([]byte, 24)
	if _, e := rand.Read(b); e != nil {
		panic(e)
	}
	return hex.EncodeToString(b)
}
func newServer(p Provider, origin, host, viewer string) *Server {
	return &Server{provider: p, origin: origin, hostCode: host, viewerCode: viewer, secure: strings.HasPrefix(origin, "https:"), sessions: map[string]*session{}, resources: map[string]mediaURL{}, reverse: map[string]string{}, seenCommands: map[string]bool{}, attempts: map[string][]time.Time{}, tickets: map[string]handoff{}, sources: map[string]string{}, segments: map[string]*cachedSegment{}, ffmpeg: ffmpegPath(), selfURL: "http://127.0.0.1:8095", ffmpegSlots: make(chan struct{}, 4)}
}
func ffmpegPath() string {
	p, _ := exec.LookPath("ffmpeg")
	return p
}
func jsonOut(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(v)
}
func fail(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
func bodyJSON(w http.ResponseWriter, r *http.Request, out any) error {
	return json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(out)
}
func (s *Server) auth(r *http.Request) (session, bool) {
	c, e := r.Cookie("pengloo_cinema")
	if e != nil {
		return session{}, false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	u, ok := s.sessions[c.Value]
	if !ok || time.Now().After(u.Expires) {
		return session{}, false
	}
	return *u, true
}
func (s *Server) touch(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if u := s.sessions[id]; u != nil {
		u.Seen = time.Now()
	}
}
func (s *Server) snapshot() State {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	// One controller. Its disconnected browser cannot hold control forever.
	if s.controller != "" {
		u := s.sessions[s.controller]
		if u == nil || now.Sub(u.Seen) > 15*time.Second {
			s.state.Position = s.positionLocked()
			s.state.Playing = false
			s.state.Updated = now.UnixMilli()
			s.state.Revision++
			s.controller = ""
			s.state.Controller = ""
		}
	}
	out := s.state
	out.ServerNow = now.UnixMilli()
	for id, u := range s.sessions {
		if now.After(u.Expires) {
			delete(s.sessions, id)
		} else if now.Sub(u.Seen) < 15*time.Second {
			out.Viewers++
		}
	}
	return out
}
func (s *Server) positionLocked() float64 {
	p := s.state.Position
	if s.state.Playing {
		p += float64(time.Now().UnixMilli()-s.state.Updated) / 1000
	}
	return math.Max(0, math.Min(p, s.state.Title.Duration))
}
func (s *Server) handler() http.Handler {
	mux := http.NewServeMux()
	files, _ := fs.Sub(web, "web")
	mux.Handle("GET /cinema/", http.StripPrefix("/cinema/", http.FileServer(http.FS(files))))
	mux.HandleFunc("GET /cinema/health", func(w http.ResponseWriter, r *http.Request) {
		jsonOut(w, map[string]any{"ok": true, "provider": "emby", "screenings": 1})
	})
	mux.HandleFunc("POST /cinema/api/login", s.login)
	mux.HandleFunc("POST /cinema/api/logout", s.protect(s.logout))
	mux.HandleFunc("POST /cinema/api/handoff", s.protect(s.issueHandoff))
	mux.HandleFunc("POST /cinema/api/ticket", s.redeemHandoff)
	mux.HandleFunc("GET /cinema/api/me", s.protect(func(w http.ResponseWriter, r *http.Request, u session) {
		s.touch(u.ID)
		st := s.snapshot()
		jsonOut(w, map[string]any{"name": u.Name, "eligible": u.Eligible, "controller": st.Controller == u.ID, "id": u.ID})
	}))
	mux.HandleFunc("GET /cinema/api/library", s.protect(func(w http.ResponseWriter, r *http.Request, u session) {
		titles, e := s.provider.Catalog(r.Context(), r.URL.Query().Get("q"))
		if e != nil {
			fail(w, 502, e.Error())
			return
		}
		jsonOut(w, titles)
	}))
	mux.HandleFunc("GET /cinema/api/state", s.protect(func(w http.ResponseWriter, r *http.Request, u session) { s.touch(u.ID); jsonOut(w, s.snapshot()) }))
	mux.HandleFunc("POST /cinema/api/claim", s.protect(s.claim))
	mux.HandleFunc("GET /cinema/api/segment", s.protect(s.segment))
	if dir := os.Getenv("CINEMA_WEB_DIR"); dir != "" { // optional: serve a web game build same-origin (cookies + Origin just work)
		mux.Handle("GET /cinema/play/", http.StripPrefix("/cinema/play/", http.FileServer(http.Dir(dir))))
	}
	mux.HandleFunc("GET /cinema/internal/source/{token}", s.internalSource)
	mux.HandleFunc("POST /cinema/api/control", s.protect(s.control))
	mux.HandleFunc("GET /cinema/events", s.protect(s.events))
	mux.HandleFunc("GET /cinema/media/{id}", s.protect(s.media))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		csp := "default-src 'self'; script-src 'self'; style-src 'self'; media-src 'self' blob:; connect-src 'self'; worker-src blob:; frame-ancestors 'self'"
		if strings.HasPrefix(r.URL.Path, "/cinema/play/") { // Godot's web shell: inline boot script + WebAssembly
			csp = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'self'"
		}
		w.Header().Set("Content-Security-Policy", csp)
		if r.Method != "GET" && r.Method != "HEAD" && r.Header.Get("Origin") != s.origin {
			fail(w, 403, "Origin rejected")
			return
		}
		mux.ServeHTTP(w, r)
	})
}
func (s *Server) protect(fn func(http.ResponseWriter, *http.Request, session)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		u, ok := s.auth(r)
		if !ok {
			fail(w, 401, "Sign in to the cinema")
			return
		}
		fn(w, r, u)
	}
}
func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	ip := strings.Split(r.RemoteAddr, ":")[0]
	now := time.Now()
	attempts := s.attempts[ip][:0]
	for _, t := range s.attempts[ip] {
		if now.Sub(t) < time.Minute {
			attempts = append(attempts, t)
		}
	}
	if len(attempts) >= 10 {
		s.mu.Unlock()
		fail(w, 429, "Wait a minute before trying again")
		return
	}
	s.attempts[ip] = append(attempts, now)
	s.mu.Unlock()
	var in struct{ Name, Code string }
	if bodyJSON(w, r, &in) != nil {
		fail(w, 400, "Invalid login")
		return
	}
	host := subtle.ConstantTimeCompare([]byte(in.Code), []byte(s.hostCode)) == 1
	viewer := subtle.ConstantTimeCompare([]byte(in.Code), []byte(s.viewerCode)) == 1
	if (!host && !viewer) || in.Code == "" {
		fail(w, 403, "Invalid cinema access code")
		return
	}
	in.Name = strings.TrimSpace(in.Name)
	if in.Name == "" || len(in.Name) > 40 {
		fail(w, 400, "Use a name of 1–40 characters")
		return
	}
	s.snapshot()
	s.mu.Lock()
	if len(s.sessions) >= 1024 {
		s.mu.Unlock()
		fail(w, 503, "Cinema session limit reached")
		return
	}
	u := &session{randomID(), in.Name, host, time.Now().Add(12 * time.Hour), time.Now()}
	s.sessions[u.ID] = u
	if host && s.controller == "" {
		s.controller = u.ID
		s.state.Controller = u.ID
		s.state.Revision++
	}
	s.mu.Unlock()
	http.SetCookie(w, &http.Cookie{Name: "pengloo_cinema", Value: u.ID, Path: "/cinema/", HttpOnly: true, Secure: s.secure, SameSite: http.SameSiteStrictMode, MaxAge: 43200})
	jsonOut(w, map[string]bool{"ok": true})
}
func (s *Server) issueHandoff(w http.ResponseWriter, r *http.Request, u session) {
	t := randomID()
	s.mu.Lock()
	now := time.Now()
	for k, h := range s.tickets {
		if now.After(h.Expires) {
			delete(s.tickets, k)
		}
	}
	s.tickets[t] = handoff{u.Name, now.Add(60 * time.Second)}
	s.mu.Unlock()
	jsonOut(w, map[string]string{"ticket": t})
}
func (s *Server) redeemHandoff(w http.ResponseWriter, r *http.Request) {
	var in struct{ Ticket string }
	if bodyJSON(w, r, &in) != nil || in.Ticket == "" {
		fail(w, 400, "Invalid ticket")
		return
	}
	s.mu.Lock()
	h, ok := s.tickets[in.Ticket]
	delete(s.tickets, in.Ticket) // single use, even when expired
	if !ok || time.Now().After(h.Expires) {
		s.mu.Unlock()
		fail(w, 403, "Ticket expired")
		return
	}
	u := &session{randomID(), h.Name, false, time.Now().Add(12 * time.Hour), time.Now()}
	s.sessions[u.ID] = u
	s.mu.Unlock()
	http.SetCookie(w, &http.Cookie{Name: "pengloo_cinema", Value: u.ID, Path: "/cinema/", HttpOnly: true, Secure: s.secure, SameSite: http.SameSiteStrictMode, MaxAge: 43200})
	jsonOut(w, map[string]bool{"ok": true})
}
func (s *Server) logout(w http.ResponseWriter, r *http.Request, u session) {
	s.mu.Lock()
	delete(s.sessions, u.ID)
	s.mu.Unlock()
	s.snapshot()
	http.SetCookie(w, &http.Cookie{Name: "pengloo_cinema", Path: "/cinema/", MaxAge: -1, HttpOnly: true, Secure: s.secure, SameSite: http.SameSiteStrictMode})
	jsonOut(w, map[string]bool{"ok": true})
}
func (s *Server) claim(w http.ResponseWriter, r *http.Request, u session) {
	s.snapshot()
	s.mu.Lock()
	defer s.mu.Unlock()
	if !u.Eligible || (s.controller != "" && s.controller != u.ID) {
		fail(w, 403, "Another controller is active")
		return
	}
	s.controller = u.ID
	s.state.Controller = u.ID
	s.state.Revision++
	jsonOut(w, map[string]bool{"ok": true})
}
func (s *Server) control(w http.ResponseWriter, r *http.Request, u session) {
	var in struct {
		Action, ID, RequestID string
		Position              float64
		Generation            int64
	}
	if bodyJSON(w, r, &in) != nil || in.RequestID == "" || len(in.RequestID) > 100 || math.IsNaN(in.Position) || math.IsInf(in.Position, 0) {
		fail(w, 400, "Invalid command")
		return
	}
	s.commands.Lock()
	defer s.commands.Unlock()
	s.mu.Lock()
	if s.controller != u.ID {
		s.mu.Unlock()
		fail(w, 403, "Only the controller can change playback")
		return
	}
	key := u.ID + ":" + in.RequestID
	if s.seenCommands[key] {
		s.mu.Unlock()
		jsonOut(w, s.snapshot())
		return
	}
	if in.Generation != s.state.Generation {
		s.mu.Unlock()
		fail(w, 409, "Screening changed; refresh state")
		return
	}
	s.mu.Unlock()
	if in.Action == "load" {
		if !regexp.MustCompile(`^[a-zA-Z0-9_-]{1,100}$`).MatchString(in.ID) {
			fail(w, 400, "Invalid media ID")
			return
		}
		play, e := s.provider.Open(r.Context(), in.ID)
		if e != nil {
			fail(w, 502, e.Error())
			return
		}
		s.mu.Lock()
		if s.controller != u.ID {
			s.mu.Unlock()
			_ = s.provider.Stop(r.Context(), play.SessionID)
			fail(w, 409, "Controller changed during media load")
			return
		}
		old := s.upstreamSession
		s.upstreamSession = play.SessionID
		s.state.Generation++
		s.state.Title = play.Title
		s.state.Position = 0
		s.state.Playing = false
		s.state.Updated = time.Now().UnixMilli()
		s.resources = map[string]mediaURL{}
		s.reverse = map[string]string{}
		s.addURLLocked(play.URL, s.state.Generation, "stream")
		s.mu.Unlock()
		if old != "" {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			_ = s.provider.Stop(ctx, old)
			cancel()
		}
	} else {
		s.mu.Lock()
		if s.state.Title.ID == "" {
			s.mu.Unlock()
			fail(w, 409, "Choose a film first")
			return
		}
		pos := s.positionLocked()
		switch in.Action {
		case "play":
			s.state.Playing = true
		case "pause":
			s.state.Playing = false
		case "seek":
			if in.Position < 0 || in.Position > s.state.Title.Duration {
				s.mu.Unlock()
				fail(w, 400, "Seek out of range")
				return
			}
			pos = in.Position
		default:
			s.mu.Unlock()
			fail(w, 400, "Unknown command")
			return
		}
		s.state.Position = pos
		s.state.Updated = time.Now().UnixMilli()
		s.mu.Unlock()
	}
	s.mu.Lock()
	if len(s.seenCommands) > 4096 {
		s.seenCommands = map[string]bool{}
	}
	s.seenCommands[key] = true
	s.state.Revision++
	s.mu.Unlock()
	jsonOut(w, s.snapshot())
}
func (s *Server) events(w http.ResponseWriter, r *http.Request, u session) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	f, ok := w.(http.Flusher)
	if !ok {
		return
	}
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		if _, ok := s.auth(r); !ok {
			return
		}
		s.touch(u.ID)
		b, _ := json.Marshal(s.snapshot())
		_ = http.NewResponseController(w).SetWriteDeadline(time.Now().Add(10 * time.Second))
		if _, e := fmt.Fprintf(w, "data: %s\n\n", b); e != nil {
			return
		}
		f.Flush()
		select {
		case <-r.Context().Done():
			return
		case <-ticker.C:
		}
	}
}
func (s *Server) addURLLocked(u *url.URL, generation int64, id string) string {
	key := strconv.FormatInt(generation, 10) + ":" + u.String()
	if old := s.reverse[key]; old != "" {
		return old
	}
	if id == "" {
		id = randomID()
	}
	s.resources[id] = mediaURL{u, generation}
	s.reverse[key] = id
	return id
}

var uriAttr = regexp.MustCompile(`URI="([^"]+)"`)

func (s *Server) rewritePlaylist(text string, base *url.URL, generation int64) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if generation != s.state.Generation {
		return "", errors.New("screening changed")
	}
	link := func(raw string) (string, error) {
		ref, e := url.Parse(raw)
		if e != nil {
			return "", errors.New("invalid HLS URI")
		}
		u := base.ResolveReference(ref)
		if u.Scheme != base.Scheme || u.Host != base.Host || u.User != nil {
			return "", errors.New("cross-origin HLS URI rejected")
		}
		if len(s.resources) > 16384 {
			return "", errors.New("playlist resource limit reached")
		}
		return "/cinema/media/" + s.addURLLocked(u, generation, "") + "?g=" + strconv.FormatInt(generation, 10), nil
	}
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "#") {
			var err error
			lines[i] = uriAttr.ReplaceAllStringFunc(line, func(m string) string {
				parts := uriAttr.FindStringSubmatch(m)
				v, e := link(parts[1])
				if e != nil {
					err = e
				}
				return `URI="` + v + `"`
			})
			if err != nil {
				return "", err
			}
		} else {
			u, e := link(line)
			if e != nil {
				return "", e
			}
			lines[i] = u
		}
	}
	return strings.Join(lines, "\n"), nil
}
func (s *Server) media(w http.ResponseWriter, r *http.Request, u session) {
	generation, e := strconv.ParseInt(r.URL.Query().Get("g"), 10, 64)
	if e != nil {
		fail(w, 400, "Missing stream generation")
		return
	}
	s.mu.Lock()
	resource, ok := s.resources[r.PathValue("id")]
	valid := ok && generation == s.state.Generation && generation == resource.Generation
	s.mu.Unlock()
	if !valid {
		fail(w, 410, "Stream has changed")
		return
	}
	resp, e := s.provider.Fetch(r.Context(), resource.URL, r.Header.Get("Range"))
	if e != nil {
		fail(w, 502, e.Error())
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 && resp.StatusCode != 206 {
		fail(w, 502, fmt.Sprintf("Media server returned HTTP %d", resp.StatusCode))
		return
	}
	w.Header().Set("Cache-Control", "private, no-store")
	typ := resp.Header.Get("Content-Type")
	if strings.Contains(strings.ToLower(typ), "mpegurl") || strings.HasSuffix(strings.ToLower(resource.URL.Path), ".m3u8") {
		b, e := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
		if e != nil {
			fail(w, 502, "Playlist unavailable")
			return
		}
		result, e := s.rewritePlaylist(string(b), resource.URL, generation)
		if e != nil {
			fail(w, 502, e.Error())
			return
		}
		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		io.WriteString(w, result)
		return
	}
	for _, h := range []string{"Content-Type", "Content-Length", "Content-Range", "Accept-Ranges"} {
		if v := resp.Header.Get(h); v != "" {
			w.Header().Set(h, v)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}
func loadEnv(path string) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	scan := bufio.NewScanner(f)
	for scan.Scan() {
		line := strings.TrimSpace(scan.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if ok && os.Getenv(k) == "" {
			os.Setenv(k, v)
		}
	}
	return scan.Err()
}
func main() {
	env := flag.String("env", "", "Private environment file")
	flag.Parse()
	if *env != "" {
		if e := loadEnv(*env); e != nil {
			log.Fatal("Cannot read private configuration")
		}
	}
	for _, key := range []string{"EMBY_URL", "EMBY_API_KEY", "EMBY_USER_ID", "CINEMA_HOST_CODE", "CINEMA_VIEWER_CODE", "CINEMA_ORIGIN"} {
		if os.Getenv(key) == "" {
			log.Fatalf("Set %s in private configuration", key)
		}
	}
	if os.Getenv("CINEMA_HOST_CODE") == os.Getenv("CINEMA_VIEWER_CODE") {
		log.Fatal("Host and viewer codes must differ")
	}
	p, e := newEmby(os.Getenv("EMBY_URL"), os.Getenv("EMBY_API_KEY"), os.Getenv("EMBY_USER_ID"))
	if e != nil {
		log.Fatal(e)
	}
	s := newServer(p, os.Getenv("CINEMA_ORIGIN"), os.Getenv("CINEMA_HOST_CODE"), os.Getenv("CINEMA_VIEWER_CODE"))
	addr := os.Getenv("CINEMA_LISTEN")
	if addr == "" {
		addr = "127.0.0.1:8095"
	}
	s.selfURL = "http://" + addr
	log.Printf("Cinema listening on %s; Emby credentials remain server-side", addr)
	server := &http.Server{Addr: addr, Handler: s.handler(), ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	shutdownDone := make(chan struct{})
	go func() {
		defer close(shutdownDone)
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				stopCtx, stopCancel := context.WithTimeout(context.Background(), 10*time.Second)
				defer stopCancel()
				_ = server.Shutdown(stopCtx)
				s.stopStream(stopCtx)
				return
			case <-ticker.C:
				s.cleanupIdle()
			}
		}
	}()
	if e := server.ListenAndServe(); e != nil && e != http.ErrServerClosed {
		log.Fatal("Cinema listener failed")
	}
	<-shutdownDone
}

func (s *Server) stopStream(ctx context.Context) {
	s.commands.Lock()
	defer s.commands.Unlock()
	s.stopStreamLocked(ctx)
}
func (s *Server) stopStreamLocked(ctx context.Context) {
	s.mu.Lock()
	id := s.upstreamSession
	s.upstreamSession = ""
	s.state.Title = Title{}
	s.state.Playing = false
	s.state.Generation++
	s.state.Revision++
	s.resources = map[string]mediaURL{}
	s.reverse = map[string]string{}
	s.mu.Unlock()
	_ = s.provider.Stop(ctx, id)
}
func (s *Server) cleanupIdle() {
	s.snapshot()
	s.commands.Lock()
	defer s.commands.Unlock()
	s.mu.Lock()
	active := false
	for _, u := range s.sessions {
		if time.Since(u.Seen) < 60*time.Second {
			active = true
			break
		}
	}
	has := s.upstreamSession != ""
	s.mu.Unlock()
	if !active && has {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		s.stopStreamLocked(ctx)
	}
}
