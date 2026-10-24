package main

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func internalRequest(s *Server, path, body, key string) *httptest.ResponseRecorder {
	r := httptest.NewRequest("POST", path, strings.NewReader(body))
	r.Header.Set("X-Pengloo-Server-Key", key)
	w := httptest.NewRecorder()
	s.handler().ServeHTTP(w, r)
	return w
}
func TestLobbyHandoff(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	s.gameKey = "server-only-secret"
	roster := `{"instance":"lobby-instance-12345","members":[{"id":"1","name":"Nick","eligible":true},{"id":"2","name":"Friend","eligible":false}]}`
	if w := internalRequest(s, "/cinema/internal/roster", roster, ""); w.Code != 403 {
		t.Fatal("untrusted roster accepted")
	}
	if w := internalRequest(s, "/cinema/internal/roster", roster, s.gameKey); w.Code != 200 {
		t.Fatal(w.Code, w.Body)
	}
	if w := internalRequest(s, "/cinema/internal/roster", strings.ReplaceAll(roster, "lobby-instance-12345", "different-lobby-12345"), s.gameKey); w.Code != 409 {
		t.Fatal("cross-lobby mixing", w.Code)
	}
	if w := request(s, "POST", "/cinema/api/login", `{"name":"Nick","code":"host"}`, ""); w.Code != 403 {
		t.Fatal("invite bypass")
	}
	if w := internalRequest(s, "/cinema/internal/ticket", `{"instance":"lobby-instance-12345","member":"999"}`, s.gameKey); w.Code != 403 {
		t.Fatal("nonmember ticket")
	}
	exchange := func(member string) string {
		w := internalRequest(s, "/cinema/internal/ticket", `{"instance":"lobby-instance-12345","member":"`+member+`"}`, s.gameKey)
		var d map[string]string
		json.Unmarshal(w.Body.Bytes(), &d)
		body := `{"ticket":"` + d["ticket"] + `"}`
		r := request(s, "POST", "/cinema/api/ticket", body, "")
		if r.Code != 200 {
			t.Fatal(r.Code, r.Body)
		}
		if again := request(s, "POST", "/cinema/api/ticket", body, ""); again.Code != 403 {
			t.Fatal("replayed ticket")
		}
		return r.Result().Cookies()[0].String()
	}
	host := exchange("1")
	viewer := exchange("2")
	if w := request(s, "POST", "/cinema/api/control", `{"action":"load","id":"1","generation":0,"requestId":"x"}`, viewer); w.Code != 403 {
		t.Fatal("viewer control")
	}
	if w := request(s, "POST", "/cinema/api/control", `{"action":"load","id":"1","generation":0,"requestId":"x"}`, host); w.Code != 200 {
		t.Fatal("host control", w.Code)
	}
	internalRequest(s, "/cinema/internal/roster", `{"instance":"lobby-instance-12345","members":[{"id":"1","name":"Nick","eligible":true}]}`, s.gameKey)
	if w := request(s, "GET", "/cinema/media/stream?g=1", "", viewer); w.Code != 401 {
		t.Fatal("departed player retained media")
	}
	s.membersSeen = time.Now().Add(-16 * time.Second)
	if w := request(s, "GET", "/cinema/api/me", "", host); w.Code != 401 {
		t.Fatal("dead host retained authorization")
	}
}
func TestExpiredLobbyTicket(t *testing.T) {
	s := newServer(&fakeProvider{}, "http://localhost", "host", "viewer")
	s.instance = "instance"
	s.membersSeen = time.Now()
	s.members["1"] = lobbyMember{ID: "1", Name: "Nick"}
	s.tickets["old"] = lobbyTicket{"1", "instance", time.Now().Add(-time.Second)}
	if w := request(s, "POST", "/cinema/api/ticket", `{"ticket":"old"}`, ""); w.Code != 403 {
		t.Fatal("expired ticket accepted")
	}
}
