package main

import (
	"bufio"
	"crypto/rand"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// test client: dials, masks its frames, reads server frames.
type client struct {
	c  net.Conn
	br *bufio.Reader
}

func dial(t *testing.T, srv *httptest.Server, path string) (*client, int) {
	t.Helper()
	c, err := net.Dial("tcp", strings.TrimPrefix(srv.URL, "http://"))
	if err != nil {
		t.Fatal(err)
	}
	key := make([]byte, 16)
	rand.Read(key)
	fmt.Fprintf(c, "GET %s HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: %s\r\n\r\n",
		path, base64.StdEncoding.EncodeToString(key))
	br := bufio.NewReader(c)
	resp, err := http.ReadResponse(br, nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 101 {
		c.Close()
		return nil, resp.StatusCode
	}
	return &client{c, br}, 101
}

func (c *client) send(op byte, data []byte) {
	hdr := []byte{0x80 | op}
	switch n := len(data); {
	case n < 126:
		hdr = append(hdr, 0x80|byte(n))
	case n <= 0xffff:
		hdr = binary.BigEndian.AppendUint16(append(hdr, 0x80|126), uint16(n))
	default:
		hdr = binary.BigEndian.AppendUint64(append(hdr, 0x80|127), uint64(n))
	}
	mask := []byte{1, 2, 3, 4}
	body := make([]byte, len(data))
	for i := range data {
		body[i] = data[i] ^ mask[i%4]
	}
	c.c.Write(append(append(hdr, mask...), body...))
}

func (c *client) ctrl(m ctrl) { b, _ := json.Marshal(m); c.send(opText, b) }

func (c *client) read(t *testing.T) (byte, []byte) {
	t.Helper()
	c.c.SetReadDeadline(time.Now().Add(3 * time.Second))
	var h [2]byte
	if _, err := io.ReadFull(c.br, h[:]); err != nil {
		t.Fatal("read:", err)
	}
	n := int(h[1] & 0x7f)
	if n == 126 {
		var b [2]byte
		io.ReadFull(c.br, b[:])
		n = int(binary.BigEndian.Uint16(b[:]))
	} else if n == 127 {
		var b [8]byte
		io.ReadFull(c.br, b[:])
		n = int(binary.BigEndian.Uint64(b[:]))
	}
	p := make([]byte, n)
	io.ReadFull(c.br, p)
	return h[0] & 0x0f, p
}

// readCtrl skips pings and returns the next control message.
func (c *client) readCtrl(t *testing.T) ctrl {
	t.Helper()
	for {
		op, p := c.read(t)
		if op != opText {
			t.Fatalf("want text, got op %d", op)
		}
		var m ctrl
		json.Unmarshal(p, &m)
		if m.T != "ping" {
			return m
		}
	}
}

func testLobby(mut func(*config)) (*Lobby, *httptest.Server) {
	cfg := config{MaxPerIP: 3, MaxPerServer: 32, MaxChannels: 100, HostTimeout: 45 * time.Second, PingEvery: time.Hour, CinemaStreams: 8,
		Official: map[string]bool{}, Banned: map[string]bool{}, Blocked: defaultBlocked}
	if mut != nil {
		mut(&cfg)
	}
	l := newLobby(cfg)
	return l, httptest.NewServer(l.handler())
}

func register(t *testing.T, srv *httptest.Server, token, name string, maxP int) (*client, ctrl) {
	t.Helper()
	h, code := dial(t, srv, "/host?token="+token)
	if h == nil {
		t.Fatalf("host dial %d", code)
	}
	h.ctrl(ctrl{T: "register", Name: name, Max: maxP, Version: "v1", Region: "ca"})
	return h, h.readCtrl(t)
}

func listing(t *testing.T, srv *httptest.Server) []map[string]any {
	resp, err := http.Get(srv.URL + "/lobby/servers")
	if err != nil {
		t.Fatal(err)
	}
	var out struct{ Servers []map[string]any }
	json.NewDecoder(resp.Body).Decode(&out)
	return out.Servers
}

const tokA = "aaaaaaaaaaaaaaaaaaaaaaaa"

func TestRegisterListRelay(t *testing.T) {
	_, srv := testLobby(nil)
	defer srv.Close()
	h, reg := register(t, srv, tokA, "Ice Cream Igloo", 8)
	if reg.T != "registered" || reg.ID != hostID(tokA) || reg.URL != "/s/"+reg.ID {
		t.Fatalf("register reply %+v", reg)
	}
	h.ctrl(ctrl{T: "hb", Players: 3})
	time.Sleep(50 * time.Millisecond)
	ls := listing(t, srv)
	if len(ls) != 1 || ls[0]["name"] != "Ice Cream Igloo" || ls[0]["players"].(float64) != 3 || ls[0]["official"] != false {
		t.Fatalf("listing %+v", ls)
	}
	for k := range ls[0] {
		if strings.Contains(k, "ip") || strings.Contains(k, "addr") {
			t.Fatalf("listing leaks %s", k)
		}
	}
	p, code := dial(t, srv, reg.URL)
	if p == nil {
		t.Fatalf("player dial %d", code)
	}
	open := h.readCtrl(t)
	if open.T != "open" || open.Ch == 0 {
		t.Fatalf("open %+v", open)
	}
	p.send(opBinary, []byte("hello host"))
	op, frame := h.read(t)
	if op != opBinary || binary.LittleEndian.Uint32(frame) != open.Ch || frame[4] != opBinary || string(frame[5:]) != "hello host" {
		t.Fatalf("host got %d %q", op, frame)
	}
	back := binary.LittleEndian.AppendUint32(nil, open.Ch)
	h.send(opBinary, append(append(back, opBinary), []byte("hello player")...))
	if op, data := p.read(t); op != opBinary || string(data) != "hello player" {
		t.Fatalf("player got %d %q", op, data)
	}
	big := make([]byte, 70000) // 64-bit length path
	p.send(opBinary, big)
	if _, frame := h.read(t); len(frame) != 5+len(big) {
		t.Fatalf("big frame %d", len(frame))
	}
	p.send(opClose, nil)
	if m := h.readCtrl(t); m.T != "close" || m.Ch != open.Ch {
		t.Fatalf("close %+v", m)
	}
}

func TestHostDropsPlayer(t *testing.T) {
	_, srv := testLobby(nil)
	defer srv.Close()
	h, reg := register(t, srv, tokA, "Snowy Spot", 8)
	p, _ := dial(t, srv, reg.URL)
	open := h.readCtrl(t)
	h.ctrl(ctrl{T: "close", Ch: open.Ch})
	if op, _ := p.read(t); op != opClose {
		t.Fatalf("player not closed, op %d", op)
	}
}

func TestNamesAndLimits(t *testing.T) {
	_, srv := testLobby(func(c *config) { c.Banned[hostID("banned-token-0000000")] = true })
	defer srv.Close()
	for _, bad := range []string{"ab", "Official Hangout", "PENGLOO party", "shitty igloo", " spaced", "a<script>"} {
		h, m := register(t, srv, "bad-name-token-"+fmt.Sprint(len(bad))+"xxxx", bad, 8)
		if m.T != "error" {
			t.Fatalf("%q accepted", bad)
		}
		h.c.Close()
	}
	if _, code := dial(t, srv, "/host?token=short"); code != 400 {
		t.Fatalf("short token %d", code)
	}
	if _, code := dial(t, srv, "/host?token=banned-token-0000000"); code != 403 {
		t.Fatalf("banned %d", code)
	}
	for i := 0; i < 3; i++ {
		register(t, srv, fmt.Sprintf("ip-limit-token-%04d", i), fmt.Sprintf("Server %d", i), 8)
	}
	if _, code := dial(t, srv, "/host?token=ip-limit-token-9999"); code != 429 {
		t.Fatalf("4th server from one ip %d", code)
	}
	if _, code := dial(t, srv, "/s/nope"); code != 404 {
		t.Fatalf("unknown server %d", code)
	}
}

func TestOfficialOnlyByConfig(t *testing.T) {
	_, srv := testLobby(func(c *config) { c.Official[hostID(tokA)] = true })
	defer srv.Close()
	_, m := register(t, srv, tokA, "Pengloo Party", 8)
	if m.T != "registered" {
		t.Fatalf("official register %+v", m)
	}
	_, other := register(t, srv, "bbbbbbbbbbbbbbbbbbbb", "Cozy Cove", 8)
	ls := listing(t, srv)
	if len(ls) != 2 || ls[0]["official"] != true || ls[0]["url"] != "/multiplayer" || ls[1]["official"] != false || other.T != "registered" {
		t.Fatalf("listing %+v", ls)
	}
}

func TestFullServerAndReplace(t *testing.T) {
	_, srv := testLobby(nil)
	defer srv.Close()
	h, reg := register(t, srv, tokA, "Tiny Igloo", 1)
	if p, _ := dial(t, srv, reg.URL); p == nil {
		t.Fatal("first player refused")
	}
	h.readCtrl(t)
	if _, code := dial(t, srv, reg.URL); code != 503 {
		t.Fatalf("second player on max=1 got %d", code)
	}
	h2, reg2 := register(t, srv, tokA, "Tiny Igloo Again", 1) // same token: replaces, same id
	if reg2.ID != reg.ID {
		t.Fatal("id not stable for a token")
	}
	if op, _ := h.read(t); op != opClose {
		t.Fatal("old host socket not closed")
	}
	if ls := listing(t, srv); len(ls) != 1 || ls[0]["name"] != "Tiny Igloo Again" {
		t.Fatalf("listing after replace %+v", ls)
	}
	h2.c.Close()
}

func TestSilentHostDropped(t *testing.T) {
	_, srv := testLobby(func(c *config) { c.HostTimeout = 200 * time.Millisecond })
	defer srv.Close()
	register(t, srv, tokA, "Quiet Place", 8)
	if len(listing(t, srv)) != 1 {
		t.Fatal("not listed")
	}
	time.Sleep(400 * time.Millisecond)
	if len(listing(t, srv)) != 0 {
		t.Fatal("silent host still listed")
	}
}

func TestPingReportsHostLatency(t *testing.T) {
	_, srv := testLobby(func(c *config) { c.PingEvery = 50 * time.Millisecond })
	defer srv.Close()
	h, _ := register(t, srv, tokA, "Ping Palace", 8)
	op, p := h.read(t)
	var m ctrl
	json.Unmarshal(p, &m)
	if op != opText || m.T != "ping" {
		t.Fatalf("want ping, got %s", p)
	}
	time.Sleep(20 * time.Millisecond)
	h.ctrl(ctrl{T: "pong", At: m.At})
	time.Sleep(50 * time.Millisecond)
	if ms := listing(t, srv)[0]["host_ms"].(float64); ms < 15 {
		t.Fatalf("host_ms %v", ms)
	}
}

func TestBucketThrottles(t *testing.T) {
	b := newBucket(10000) // 10 kB/s, starts full
	start := time.Now()
	b.wait(10000)
	b.wait(5000) // 5 kB of debt = 0.5 s
	if d := time.Since(start); d < 400*time.Millisecond || d > 900*time.Millisecond {
		t.Fatalf("throttle took %v", d)
	}
	newBucket(0).wait(1 << 30) // unlimited never blocks
}

// fakeGateway answers one cinema request arriving over the host socket like services/cinema would.
func fakeGateway(t *testing.T, h *client, gotReq chan string) {
	open := h.readCtrl(t)
	if open.T != "open" || open.Kind != "cinema" {
		t.Errorf("want cinema open, got %+v", open)
		return
	}
	var req []byte
	for !strings.Contains(string(req), "\r\n\r\n") {
		op, frame := h.read(t)
		if op != opBinary {
			continue // e.g. the close of an earlier channel
		}
		req = append(req, frame[5:]...)
	}
	gotReq <- string(req)
	resp := "HTTP/1.1 200 OK\r\nContent-Length: 5\r\nSet-Cookie: pengloo_cinema=abc; Path=/cinema/; HttpOnly\r\nConnection: close\r\n\r\nhello"
	h.send(opBinary, append(append(binary.LittleEndian.AppendUint32(nil, open.Ch), opBinary), resp...))
	h.ctrl(ctrl{T: "close", Ch: open.Ch})
}

func registerCinema(t *testing.T, srv *httptest.Server) (*client, ctrl) {
	h, code := dial(t, srv, "/host?token="+tokA)
	if h == nil {
		t.Fatalf("host dial %d", code)
	}
	h.ctrl(ctrl{T: "register", Name: "Movie Igloo", Max: 8, Version: "v1", Cinema: true})
	return h, h.readCtrl(t)
}

func TestCinemaTunnel(t *testing.T) {
	_, srv := testLobby(nil)
	defer srv.Close()
	h, reg := registerCinema(t, srv)
	if ls := listing(t, srv); ls[0]["cinema"] != true {
		t.Fatalf("listing %+v", ls)
	}
	gotReq := make(chan string, 1)
	go fakeGateway(t, h, gotReq)
	req, _ := http.NewRequest("GET", srv.URL+reg.URL+"/cinema/api/me", nil)
	req.Header.Set("X-Forwarded-For", "6.6.6.6")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 || string(body) != "hello" {
		t.Fatalf("got %d %q", resp.StatusCode, body)
	}
	if c := resp.Header.Get("Set-Cookie"); !strings.Contains(c, "Path="+reg.URL+"/cinema/") {
		t.Fatalf("cookie not scoped to this server: %q", c)
	}
	raw := <-gotReq
	if !strings.HasPrefix(raw, "GET /cinema/api/me ") {
		t.Fatalf("gateway saw %q", strings.SplitN(raw, "\r\n", 2)[0])
	}
	if strings.Contains(raw, "6.6.6.6") || strings.Contains(strings.ToLower(raw), "x-forwarded-for") || !strings.Contains(raw, "X-Real-Ip: 2001:db8:") {
		t.Fatalf("player address leaked or missing pseudonym:\n%s", raw)
	}
}

func TestCinemaLimits(t *testing.T) {
	_, srv := testLobby(func(c *config) { c.CinemaStreams = 0 })
	defer srv.Close()
	_, reg := registerCinema(t, srv)
	resp, _ := http.Get(srv.URL + reg.URL + "/cinema/api/me")
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 429 || !strings.Contains(string(body), "Cinema bandwidth limit reached") {
		t.Fatalf("stream cap: %d %s", resp.StatusCode, body)
	}
	_, srv2 := testLobby(nil)
	defer srv2.Close()
	_, reg2 := register(t, srv2, tokA, "No Movies Here", 8)
	if resp, _ := http.Get(srv2.URL + reg2.URL + "/cinema/api/me"); resp.StatusCode != 404 {
		t.Fatalf("server without a cinema: %d", resp.StatusCode)
	}
	var c cinemaUse
	c.charge(100, 150)
	if c.spent(150) || c.charge(100, 150) || !c.spent(150) {
		t.Fatal("hourly budget")
	}
}
