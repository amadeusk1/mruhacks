// Pengloo lobby: lists community servers and relays players to them through pengloo.party.
// A community server dials OUT to /host (no port forwarding, no TLS of its own); players join
// wss://pengloo.party/s/<id> and the lobby multiplexes their sockets over that one host socket.
// In-memory only: a restart forgets everything and servers simply re-register.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

// Host socket protocol. Text frames are JSON control messages:
//
//	host -> lobby  {"t":"register","name","max","version","region"}  first frame, within 10 s
//	               {"t":"hb","players":N}                            every 15 s
//	               {"t":"pong","at":ms}                              answer to ping
//	               {"t":"close","ch":N}                              host dropped that player
//	lobby -> host  {"t":"registered","id","url"} / {"t":"error","error"}
//	               {"t":"open","ch":N} / {"t":"close","ch":N} / {"t":"ping","at":ms}
//
// Binary frames carry player traffic both ways: [u32 LE channel][u8 opcode][payload].
type ctrl struct {
	T       string `json:"t"`
	Name    string `json:"name,omitempty"`
	Max     int    `json:"max,omitempty"`
	Version string `json:"version,omitempty"`
	Region  string `json:"region,omitempty"`
	Cinema  bool   `json:"cinema,omitempty"`
	Kind    string `json:"kind,omitempty"`
	Players int    `json:"players,omitempty"`
	Ch      uint32 `json:"ch,omitempty"`
	At      int64  `json:"at,omitempty"`
	ID      string `json:"id,omitempty"`
	URL     string `json:"url,omitempty"`
	Error   string `json:"error,omitempty"`
}

type Listing struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Players  int    `json:"players"`
	Max      int    `json:"max"`
	Version  string `json:"version"`
	Region   string `json:"region"`
	Official bool   `json:"official"`
	Cinema   bool   `json:"cinema"`
	PingMS   int    `json:"host_ms"`
	URL      string `json:"url"`
}

type config struct {
	MaxPerIP, MaxPerServer, MaxChannels int
	ServerBps, GlobalBps                float64
	CinemaBps                           float64 // per server, on top of game traffic
	CinemaStreams                       int     // concurrent cinema requests per server
	CinemaBytesPerHour                  int64
	HostTimeout, PingEvery              time.Duration
	Official, Banned                    map[string]bool
	Blocked                             []string
}

type host struct {
	Listing
	ip      string
	ws      *wsConn
	limit   *bucket
	mu      sync.Mutex
	chans   map[uint32]sink
	next    uint32
	relayed int // player channels (cinema tunnels don't count against max players)
	bytes   atomic.Int64
	since   time.Time
	cin     cinemaUse
}

// sink is where the host's binary frames for one channel go: a player's socket or a cinema tunnel.
type sink interface {
	deliver(op byte, data []byte) error
	drop()
}

func (ws *wsConn) deliver(op byte, data []byte) error { return ws.WriteMessage(op, data) }
func (ws *wsConn) drop()                              { ws.Close() }

type Lobby struct {
	cfg      config
	mu       sync.Mutex
	hosts    map[string]*host
	channels int
	global   *bucket
}

const maxMsg = 1 << 20

func newLobby(cfg config) *Lobby {
	return &Lobby{cfg: cfg, hosts: map[string]*host{}, global: newBucket(cfg.GlobalBps)}
}

func (l *Lobby) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /lobby/health", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok\n")) })
	mux.HandleFunc("GET /lobby/servers", func(w http.ResponseWriter, r *http.Request) { jsonOut(w, map[string]any{"servers": l.list()}) })
	mux.HandleFunc("GET /host", l.serveHost)
	mux.HandleFunc("GET /s/{id}", l.servePlayer)
	mux.HandleFunc("/s/{id}/cinema/", l.serveCinema)
	return mux
}

func (l *Lobby) list() []Listing {
	l.mu.Lock()
	out := make([]Listing, 0, len(l.hosts))
	for _, h := range l.hosts {
		h.mu.Lock()
		out = append(out, h.Listing) // no ip: host addresses never leave the lobby
		h.mu.Unlock()
	}
	l.mu.Unlock()
	sort.Slice(out, func(i, j int) bool {
		if out[i].Official != out[j].Official {
			return out[i].Official
		}
		if out[i].Players != out[j].Players {
			return out[i].Players > out[j].Players
		}
		return out[i].Name < out[j].Name
	})
	return out
}

func hostID(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:6])
}

var nameRe = regexp.MustCompile(`^[\p{L}\p{N} '._!?&-]{3,32}$`)
var defaultBlocked = []string{"fuck", "shit", "cunt", "nigg", "fag", "nazi", "porn", "rape"}

func (l *Lobby) validName(name string, official bool) bool {
	if !nameRe.MatchString(name) || strings.TrimSpace(name) != name || strings.Contains(name, "  ") {
		return false
	}
	low := strings.ToLower(name)
	if !official && (strings.Contains(low, "pengloo") || strings.Contains(low, "official")) {
		return false // only config-marked servers may look official
	}
	for _, w := range l.cfg.Blocked {
		if strings.Contains(low, w) {
			return false
		}
	}
	return true
}

func (l *Lobby) serveHost(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if len(token) < 16 || len(token) > 128 {
		fail(w, 400, "A host token of 16-128 characters is required")
		return
	}
	id, ip := hostID(token), clientIP(r)
	if l.cfg.Banned[id] {
		fail(w, 403, "This server is not allowed to list")
		return
	}
	l.mu.Lock()
	same := 0
	for hid, h := range l.hosts {
		if h.ip == ip && hid != id {
			same++
		}
	}
	l.mu.Unlock()
	if same >= l.cfg.MaxPerIP {
		fail(w, 429, "Too many servers from this address")
		return
	}
	ws, err := wsUpgrade(w, r, maxMsg)
	if err != nil {
		fail(w, 400, "WebSocket upgrade required")
		return
	}
	defer ws.Close()
	op, data, err := ws.ReadMessage(10 * time.Second)
	var reg ctrl
	if err != nil || op != opText || json.Unmarshal(data, &reg) != nil || reg.T != "register" {
		sendCtrl(ws, ctrl{T: "error", Error: "Register first"})
		return
	}
	official := l.cfg.Official[id]
	if !l.validName(reg.Name, official) {
		sendCtrl(ws, ctrl{T: "error", Error: "Server name not allowed (3-32 letters, numbers, simple punctuation)"})
		return
	}
	if reg.Max < 1 || reg.Max > l.cfg.MaxPerServer {
		reg.Max = l.cfg.MaxPerServer
	}
	h := &host{Listing: Listing{ID: id, Name: reg.Name, Max: reg.Max, Version: trim(reg.Version, 32), Region: trim(reg.Region, 16),
		Official: official, Cinema: reg.Cinema, URL: "/s/" + id}, ip: ip, since: time.Now(), ws: ws, limit: newBucket(l.cfg.ServerBps), chans: map[uint32]sink{},
		cin: cinemaUse{limit: newBucket(l.cfg.CinemaBps)}}
	if official {
		h.URL = "/multiplayer" // the official island lists for its player count; players connect to it directly
	}
	l.mu.Lock()
	old := l.hosts[id]
	l.hosts[id] = h // same token re-registering replaces the stale socket
	l.mu.Unlock()
	if old != nil {
		old.ws.Close()
	}
	log.Printf("Lobby: server %s registered (%d listed)", id, len(l.list()))
	sendCtrl(ws, ctrl{T: "registered", ID: id, URL: h.URL})
	stop := make(chan struct{})
	defer close(stop)
	go func() {
		t := time.NewTicker(l.cfg.PingEvery)
		defer t.Stop()
		for {
			select {
			case <-stop:
				return
			case <-t.C:
				sendCtrl(ws, ctrl{T: "ping", At: time.Now().UnixMilli()})
			}
		}
	}()
	defer l.dropHost(h)
	for {
		op, data, err := ws.ReadMessage(l.cfg.HostTimeout) // silence past the timeout drops the listing
		if err != nil {
			return
		}
		if op == opBinary {
			if len(data) < 5 {
				continue
			}
			ch := binary.LittleEndian.Uint32(data)
			h.mu.Lock()
			p := h.chans[ch]
			h.mu.Unlock()
			if p != nil {
				h.bytes.Add(int64(len(data)))
				h.limit.wait(len(data))
				l.global.wait(len(data))
				if p.deliver(data[4], data[5:]) != nil {
					p.drop()
				}
			}
			continue
		}
		var m ctrl
		if json.Unmarshal(data, &m) != nil {
			continue
		}
		switch m.T {
		case "hb":
			h.mu.Lock()
			h.Players = max(0, min(m.Players, h.Max))
			h.mu.Unlock()
		case "pong":
			h.mu.Lock()
			h.PingMS = int(time.Now().UnixMilli() - m.At)
			h.mu.Unlock()
		case "close":
			h.mu.Lock()
			p := h.chans[m.Ch]
			h.mu.Unlock()
			if p != nil {
				p.drop()
			}
		}
	}
}

func (l *Lobby) dropHost(h *host) {
	l.mu.Lock()
	if l.hosts[h.ID] == h {
		delete(l.hosts, h.ID)
	}
	l.mu.Unlock()
	h.mu.Lock()
	for _, p := range h.chans {
		if p != nil {
			p.drop()
		}
	}
	h.mu.Unlock()
	mins := time.Since(h.since).Minutes()
	log.Printf("Lobby: server %s left after %.1f min, relayed %d kB (%.1f kB/s)", h.ID, mins, h.bytes.Load()/1000, float64(h.bytes.Load())/1000/max(mins*60, 1))
}

func (l *Lobby) servePlayer(w http.ResponseWriter, r *http.Request) {
	l.mu.Lock()
	h := l.hosts[r.PathValue("id")]
	if h == nil {
		l.mu.Unlock()
		fail(w, 404, "That server is offline")
		return
	}
	h.mu.Lock()
	if l.channels >= l.cfg.MaxChannels || h.relayed >= h.Max {
		h.mu.Unlock()
		l.mu.Unlock()
		fail(w, 503, "That server is full")
		return
	}
	h.next++
	ch := h.next
	h.chans[ch] = nil // reserve the slot before upgrading, so two joiners can't both take the last one
	h.relayed++
	l.channels++
	h.mu.Unlock()
	l.mu.Unlock()
	release := func() {
		h.mu.Lock()
		delete(h.chans, ch)
		h.relayed--
		h.mu.Unlock()
		l.mu.Lock()
		l.channels--
		l.mu.Unlock()
	}
	ws, err := wsUpgrade(w, r, maxMsg)
	if err != nil {
		release()
		fail(w, 400, "WebSocket upgrade required")
		return
	}
	h.mu.Lock()
	h.chans[ch] = ws
	h.mu.Unlock()
	defer func() {
		release()
		sendCtrl(h.ws, ctrl{T: "close", Ch: ch})
		ws.Close()
	}()
	if sendCtrl(h.ws, ctrl{T: "open", Ch: ch}) != nil {
		return
	}
	frame := make([]byte, 5, 5+4096)
	binary.LittleEndian.PutUint32(frame, ch)
	for {
		op, data, err := ws.ReadMessage(5 * time.Minute)
		if err != nil {
			return
		}
		frame = append(frame[:4], op)
		frame = append(frame, data...)
		h.bytes.Add(int64(len(frame)))
		h.limit.wait(len(frame))
		l.global.wait(len(frame))
		if h.ws.WriteMessage(opBinary, frame) != nil {
			return
		}
	}
}

func sendCtrl(ws *wsConn, m ctrl) error {
	b, _ := json.Marshal(m)
	return ws.WriteMessage(opText, b)
}

func trim(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}

// bucket is a blocking token bucket: relay goroutines sleep (TCP backpressure) rather than drop
// game packets, which would corrupt the reliable multiplayer stream. rate <= 0 means unlimited.
type bucket struct {
	mu     sync.Mutex
	rate   float64
	tokens float64
	last   time.Time
}

func newBucket(bytesPerSec float64) *bucket {
	return &bucket{rate: bytesPerSec, tokens: bytesPerSec, last: time.Now()}
}

func (b *bucket) wait(n int) {
	if b.rate <= 0 {
		return
	}
	b.mu.Lock()
	now := time.Now()
	b.tokens = min(b.rate, b.tokens+now.Sub(b.last).Seconds()*b.rate) - float64(n)
	b.last = now
	debt := b.tokens
	b.mu.Unlock()
	if debt < 0 {
		time.Sleep(time.Duration(-debt / b.rate * float64(time.Second)))
	}
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

// clientIP: behind the pengloo nginx every request arrives from the proxy, so X-Real-IP (set by
// nginx from Cloudflare's CF-Connecting-IP) is only trusted from an internal peer. Same as cinema.
func clientIP(r *http.Request) string {
	peer, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		peer = r.RemoteAddr
	}
	if p := net.ParseIP(peer); p != nil && (p.IsLoopback() || p.IsPrivate()) {
		if h := net.ParseIP(strings.TrimSpace(r.Header.Get("X-Real-IP"))); h != nil {
			return h.String()
		}
	}
	return peer
}

func envInt(k string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil && v > 0 {
		return v
	}
	return def
}

func envSet(k string) map[string]bool {
	out := map[string]bool{}
	for _, v := range strings.Split(os.Getenv(k), ",") {
		if v = strings.TrimSpace(strings.ToLower(v)); v != "" {
			out[v] = true
		}
	}
	return out
}

func configFromEnv() config {
	blocked := append([]string{}, defaultBlocked...)
	for w := range envSet("LOBBY_BLOCKED_WORDS") {
		blocked = append(blocked, w)
	}
	return config{
		MaxPerIP:           envInt("LOBBY_MAX_PER_IP", 3),
		MaxPerServer:       envInt("LOBBY_MAX_PER_SERVER", 32),
		MaxChannels:        envInt("LOBBY_MAX_CHANNELS", 300),
		ServerBps:          float64(envInt("LOBBY_SERVER_KBPS", 4000)) * 125, // kbit/s -> bytes/s
		GlobalBps:          float64(envInt("LOBBY_GLOBAL_KBPS", 40000)) * 125,
		CinemaBps:          float64(envInt("LOBBY_CINEMA_KBPS", 8000)) * 125,
		CinemaStreams:      envInt("LOBBY_CINEMA_STREAMS", 24),
		CinemaBytesPerHour: int64(envInt("LOBBY_CINEMA_MB_PER_HOUR", 2500)) << 20,
		HostTimeout:        45 * time.Second,
		PingEvery:          15 * time.Second,
		Official:           envSet("LOBBY_OFFICIAL_IDS"),
		Banned:             envSet("LOBBY_BANNED_IDS"),
		Blocked:            blocked,
	}
}

func main() {
	addr := os.Getenv("LOBBY_LISTEN")
	if addr == "" {
		addr = "127.0.0.1:8096"
	}
	l := newLobby(configFromEnv())
	server := &http.Server{Addr: addr, Handler: l.handler(), ReadHeaderTimeout: 10 * time.Second}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	go func() {
		<-ctx.Done()
		stop, c := context.WithTimeout(context.Background(), 5*time.Second)
		defer c()
		server.Shutdown(stop)
	}()
	log.Printf("Lobby listening on %s", addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal("Lobby listener failed")
	}
}
