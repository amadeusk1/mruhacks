package main

import (
	"context"
	"crypto/subtle"
	"net/http"
	"time"
)

// Only the trusted game host may publish membership and mint a one-use handoff.
// A gateway serves one lobby instance; a different live instance cannot join it.
type lobbyMember struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Eligible bool   `json:"eligible"`
}
type lobbyTicket struct {
	Member, Instance string
	Expires          time.Time
}

func (s *Server) internal(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if s.gameKey == "" || subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Pengloo-Server-Key")), []byte(s.gameKey)) != 1 {
			fail(w, 403, "Game host authentication required")
			return
		}
		fn(w, r)
	}
}
func (s *Server) memberValidLocked(u *session) bool {
	if u.Member == "" {
		return true
	}
	m, ok := s.members[u.Member]
	return ok && u.Instance == s.instance && time.Since(s.membersSeen) < 15*time.Second && m.Eligible == u.Eligible
}
func (s *Server) rosterUpdate(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Instance string        `json:"instance"`
		Members  []lobbyMember `json:"members"`
	}
	if bodyJSON(w, r, &in) != nil || len(in.Instance) < 16 || len(in.Instance) > 128 || len(in.Members) > 64 {
		fail(w, 400, "Invalid lobby membership")
		return
	}
	members := map[string]lobbyMember{}
	for _, m := range in.Members {
		if m.ID == "" || len(m.ID) > 32 || m.Name == "" || len(m.Name) > 64 {
			fail(w, 400, "Invalid member")
			return
		}
		if _, exists := members[m.ID]; exists {
			fail(w, 400, "Duplicate member")
			return
		}
		members[m.ID] = m
	}
	s.mu.Lock()
	if s.instance != "" && s.instance != in.Instance && time.Since(s.membersSeen) < 15*time.Second {
		s.mu.Unlock()
		fail(w, 409, "This gateway belongs to another active lobby")
		return
	}
	oldStream := ""
	if s.instance != "" && s.instance != in.Instance {
		oldStream = s.upstreamSession
		s.upstreamSession = ""
		s.state.Title = Title{}
		s.state.Playing = false
		s.state.Generation++
		s.state.Revision++
		s.resources = map[string]mediaURL{}
		s.reverse = map[string]string{}
	}
	s.instance = in.Instance
	s.members = members
	s.membersSeen = time.Now()
	for id, u := range s.sessions {
		if !s.memberValidLocked(u) {
			delete(s.sessions, id)
		}
	}
	for id, t := range s.tickets {
		_, present := members[t.Member]
		if !present || t.Instance != s.instance || time.Now().After(t.Expires) {
			delete(s.tickets, id)
		}
	}
	s.mu.Unlock()
	s.snapshot()
	if oldStream != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = s.provider.Stop(ctx, oldStream)
	}
	jsonOut(w, map[string]bool{"ok": true})
}
func (s *Server) mintTicket(w http.ResponseWriter, r *http.Request) {
	var in struct{ Instance, Member string }
	if bodyJSON(w, r, &in) != nil {
		fail(w, 400, "Invalid handoff")
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.members[in.Member]
	if !ok || in.Instance != s.instance || time.Since(s.membersSeen) >= 15*time.Second {
		fail(w, 403, "Player is not in this cinema")
		return
	}
	for id, t := range s.tickets {
		if time.Now().After(t.Expires) || (t.Instance == in.Instance && t.Member == in.Member) {
			delete(s.tickets, id)
		}
	}
	ticket := randomID()
	s.tickets[ticket] = lobbyTicket{in.Member, in.Instance, time.Now().Add(30 * time.Second)}
	jsonOut(w, map[string]string{"ticket": ticket})
}
func (s *Server) exchangeTicket(w http.ResponseWriter, r *http.Request) {
	var in struct{ Ticket string }
	if bodyJSON(w, r, &in) != nil {
		fail(w, 400, "Invalid handoff")
		return
	}
	s.mu.Lock()
	t, ok := s.tickets[in.Ticket]
	delete(s.tickets, in.Ticket)
	m, present := s.members[t.Member]
	if !ok || !present || t.Instance != s.instance || time.Now().After(t.Expires) || time.Since(s.membersSeen) >= 15*time.Second {
		s.mu.Unlock()
		fail(w, 403, "Cinema access expired. Re-enter from your game lobby.")
		return
	}
	// Re-entry replaces this player's previous player session, including its remote.
	wasController := false
	for id, u := range s.sessions {
		if u.Member == t.Member && u.Instance == t.Instance {
			wasController = wasController || s.controller == id
			delete(s.sessions, id)
		}
	}
	u := &session{ID: randomID(), Name: m.Name, Eligible: m.Eligible, Expires: time.Now().Add(12 * time.Hour), Seen: time.Now(), Member: t.Member, Instance: t.Instance}
	s.sessions[u.ID] = u
	if u.Eligible && (s.controller == "" || wasController) {
		s.controller = u.ID
		s.state.Controller = u.ID
		s.state.Revision++
	}
	s.mu.Unlock()
	http.SetCookie(w, &http.Cookie{Name: "pengloo_cinema", Value: u.ID, Path: "/cinema/", HttpOnly: true, Secure: s.secure, SameSite: http.SameSiteStrictMode, MaxAge: 43200})
	jsonOut(w, map[string]bool{"ok": true})
}
