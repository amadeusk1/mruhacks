package main

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/netip"
	"strings"
	"sync"
	"time"
)

// A community server's own cinema gateway (services/cinema, run by the host with the host's own
// media server and codes) is reached at /s/<id>/cinema/*. Each request is reverse-proxied over a
// fresh raw TCP channel on the host socket; LobbyLink connects that channel to its local gateway.
// The host's credentials never reach pengloo.party: only HTTP traffic passes through.

const cinemaLimitMsg = "Cinema bandwidth limit reached on this server. Try again in a little while."

type cinemaUse struct {
	limit   *bucket
	mu      sync.Mutex
	streams int
	hour    time.Time
	bytes   int64
}

// charge counts relayed cinema bytes against the server's hourly budget; false once it's spent.
func (c *cinemaUse) charge(n int, budget int64) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if now := time.Now(); now.Sub(c.hour) >= time.Hour {
		c.hour, c.bytes = now, 0
	}
	c.bytes += int64(n)
	return budget <= 0 || c.bytes <= budget
}

func (c *cinemaUse) spent(budget int64) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return budget > 0 && time.Since(c.hour) < time.Hour && c.bytes >= budget
}

func (l *Lobby) serveCinema(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	l.mu.Lock()
	h := l.hosts[id]
	l.mu.Unlock()
	if h == nil {
		fail(w, 404, "That server is offline")
		return
	}
	if !h.Cinema {
		fail(w, 404, "No cinema on this server")
		return
	}
	h.cin.mu.Lock()
	busy := h.cin.streams >= l.cfg.CinemaStreams
	if !busy {
		h.cin.streams++
	}
	h.cin.mu.Unlock()
	if busy || h.cin.spent(l.cfg.CinemaBytesPerHour) {
		if !busy {
			h.cin.mu.Lock()
			h.cin.streams--
			h.cin.mu.Unlock()
		}
		fail(w, 429, cinemaLimitMsg)
		return
	}
	defer func() {
		h.cin.mu.Lock()
		h.cin.streams--
		h.cin.mu.Unlock()
	}()
	prefix := "/s/" + id
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.Out.URL.Scheme, pr.Out.URL.Host = "http", "host-cinema"
			pr.Out.URL.Path = strings.TrimPrefix(pr.In.URL.Path, prefix) // the gateway serves /cinema/*
			pr.Out.URL.RawPath = ""
			pr.Out.Host = pr.In.Host // CINEMA_ORIGIN on the host is https://pengloo.party
			pr.Out.Header.Del("X-Forwarded-For")
			// The gateway's login throttle keys on X-Real-IP; hosts get a per-server pseudonym, never a player's IP.
			pr.Out.Header.Set("X-Real-IP", pseudonym(id, clientIP(pr.In)))
		},
		Transport: &http.Transport{
			DialContext:       func(ctx context.Context, _, _ string) (net.Conn, error) { return l.openTunnel(h) },
			DisableKeepAlives: true, // one channel per request keeps the tunnel a dumb pipe
		},
		FlushInterval: -1, // server-sent events (/cinema/events) must not be buffered
		ModifyResponse: func(resp *http.Response) error {
			// Sessions are per server: scope the gateway's /cinema/ cookie to this server's path so it
			// is never sent to the official cinema or another community server.
			cs := resp.Header.Values("Set-Cookie")
			resp.Header.Del("Set-Cookie")
			for _, raw := range cs {
				if c, err := http.ParseSetCookie(raw); err == nil {
					c.Path = prefix + "/cinema/"
					resp.Header.Add("Set-Cookie", c.String())
				}
			}
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			if errors.Is(err, errCinemaBudget) {
				fail(w, 429, cinemaLimitMsg)
				return
			}
			fail(w, 502, "This server's cinema isn't responding")
		},
	}
	proxy.ServeHTTP(w, r)
}

// pseudonym maps a player address to a stable fake IPv6 (2001:db8::/32 documentation range) per server.
func pseudonym(serverID, ip string) string {
	sum := sha256.Sum256([]byte(serverID + "|" + ip))
	var a [16]byte
	a[0], a[1], a[2], a[3] = 0x20, 0x01, 0x0d, 0xb8
	copy(a[4:], sum[:12])
	return netip.AddrFrom16(a).String()
}

var errCinemaBudget = errors.New("cinema budget spent")

func (l *Lobby) openTunnel(h *host) (net.Conn, error) {
	t := &tunnel{l: l, h: h, in: make(chan []byte, 1024), done: make(chan struct{})}
	h.mu.Lock()
	h.next++
	t.ch = h.next
	h.chans[t.ch] = t
	h.mu.Unlock()
	if err := sendCtrl(h.ws, ctrl{T: "open", Ch: t.ch, Kind: "cinema"}); err != nil {
		t.drop()
		return nil, err
	}
	return t, nil
}

// tunnel is a net.Conn over one host-socket channel (raw TCP bytes to the host's local gateway).
type tunnel struct {
	l    *Lobby
	h    *host
	ch   uint32
	in   chan []byte
	rest []byte
	done chan struct{}
	once sync.Once
}

// deliver runs on the host's read loop: never block it (that would stall every player), so a
// tunnel whose reader fell 1024 frames behind is dropped instead.
func (t *tunnel) deliver(_ byte, data []byte) error {
	select {
	case <-t.done:
		return net.ErrClosed
	case t.in <- append([]byte(nil), data...):
		return nil
	default:
		return errors.New("cinema tunnel backed up")
	}
}

func (t *tunnel) Read(p []byte) (int, error) {
	if len(t.rest) == 0 {
		select {
		case b := <-t.in:
			t.rest = b
		case <-t.done:
			select { // drain what arrived before the close
			case b := <-t.in:
				t.rest = b
			default:
				return 0, io.EOF
			}
		}
	}
	n := copy(p, t.rest)
	t.rest = t.rest[n:]
	if !t.account(n) {
		return n, errCinemaBudget
	}
	return n, nil
}

func (t *tunnel) Write(p []byte) (int, error) {
	if !t.account(len(p)) {
		return 0, errCinemaBudget
	}
	frame := binary.LittleEndian.AppendUint32(make([]byte, 0, 5+len(p)), t.ch)
	frame = append(append(frame, opBinary), p...)
	if err := t.h.ws.WriteMessage(opBinary, frame); err != nil {
		return 0, err
	}
	return len(p), nil
}

func (t *tunnel) account(n int) bool {
	t.h.cin.limit.wait(n)
	t.l.global.wait(n)
	return t.h.cin.charge(n, t.l.cfg.CinemaBytesPerHour)
}

func (t *tunnel) Close() error { t.drop(); return nil }

func (t *tunnel) drop() {
	t.once.Do(func() {
		close(t.done)
		t.h.mu.Lock()
		_, mine := t.h.chans[t.ch]
		delete(t.h.chans, t.ch)
		t.h.mu.Unlock()
		if mine {
			sendCtrl(t.h.ws, ctrl{T: "close", Ch: t.ch})
		}
	})
}

// net.Conn plumbing for http.Transport.
func (t *tunnel) LocalAddr() net.Addr              { return tunnelAddr{} }
func (t *tunnel) RemoteAddr() net.Addr             { return tunnelAddr{} }
func (t *tunnel) SetDeadline(time.Time) error      { return nil }
func (t *tunnel) SetReadDeadline(time.Time) error  { return nil }
func (t *tunnel) SetWriteDeadline(time.Time) error { return nil }

type tunnelAddr struct{}

func (tunnelAddr) Network() string { return "pengloo-tunnel" }
func (tunnelAddr) String() string  { return "host-cinema" }
