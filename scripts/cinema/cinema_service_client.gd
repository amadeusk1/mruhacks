class_name CinemaServiceClient
extends Node
## Client for the Pengloo cinema gateway (services/cinema). Proven in the cinema sandbox (Engine Specs/Cinema Sandbox Log).
## Every call is an HTTPRequest child with a timeout and a completion callback: nothing blocks,
## no GDScript coroutines, and a dead or slow service just reports code 0.
## The gateway holds the Emby credentials; this client holds only its session cookie.

signal log_line(text: String)

const TIMEOUT_S := 8.0

var base := ""      ## ".../cinema" without trailing slash
var origin := ""    ## scheme://host:port; the gateway checks Origin on writes
var cookie := ""
var me := {}
var signed_in := false
## Browsers own Origin and cookies (forbidden headers); a same-origin web build just works.
var web := OS.has_feature("web")


func set_service(url: String) -> void:
	base = url.strip_edges().trim_suffix("/")
	var path_at := base.find("/", base.find("://") + 3)
	origin = base if path_at < 0 else base.substr(0, path_at)
	cookie = ""
	me = {}
	signed_in = false


## done(code: int, data: Variant, body: PackedByteArray)
func call_api(method: int, path: String, body: Variant, done: Callable, timeout := TIMEOUT_S) -> void:
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.download_chunk_size = 1 << 20  # default 64 KB/frame makes a 2 MB video chunk take seconds
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not web:
		headers.append("Origin: " + origin)
	if cookie != "" and not web:
		headers.append("Cookie: " + cookie)
	http.request_completed.connect(_finished.bind(http, path, done))
	var err := http.request(base + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		log_line.emit("%s -> request error %d" % [path, err])
		if done.is_valid():
			done.call(0, null, PackedByteArray())


func _finished(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, path: String, done: Callable) -> void:
	http.queue_free()
	for h in headers:
		if h.to_lower().begins_with("set-cookie:"):
			var c := h.substr(11).strip_edges().get_slice(";", 0)
			if c.begins_with("pengloo_cinema="):
				cookie = c
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 and body[0] in [0x7B, 0x5B] else null
	log_line.emit("%s -> %d%s" % [path, code, "" if result == HTTPRequest.RESULT_SUCCESS else " (result %d)" % result])
	if done.is_valid():  # the caller (e.g. a closed screen player) may be gone by now
		done.call(code, data, body)


# ---- API ---------------------------------------------------------------------------------
func health(done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/health", null, func(code: int, _d: Variant, _b: PackedByteArray) -> void: done.call(code == 200))


## The invite code is sent once and not kept.
func login(player_name: String, code: String, done: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/login", {"name": player_name, "code": code}, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		if c != 200 or (cookie == "" and not web):
			done.call(false, str(d.get("error", "Sign-in failed")) if d is Dictionary else "Service unreachable")
			return
		_after_sign_in(done))


## Picks up an existing session (web: the browser's cookie survives reloads). done(ok: bool)
func restore(done: Callable) -> void:
	if not web and cookie == "":
		done.call(false)
		return
	call_api(HTTPClient.METHOD_GET, "/api/me", null, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		if c == 200 and d is Dictionary:
			me = d
			signed_in = true
		if done.is_valid():
			done.call(signed_in))


## A single-use view ticket from a signed-in client (web build / close-up): view-only session.
func redeem_ticket(ticket: String, done: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/ticket", {"ticket": ticket}, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		if c != 200:
			done.call(false, str(d.get("error", "Ticket refused")) if d is Dictionary else "Service unreachable")
			return
		_after_sign_in(done))


func _after_sign_in(done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/api/me", null, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		me = d if d is Dictionary else {}
		signed_in = c == 200
		done.call(signed_in, "" if signed_in else "Session not accepted"))


## done(films: Array[{id, title, year, duration}] or null on failure)
func library(query: String, done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/api/library?q=" + query.uri_encode(), null, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		done.call(d if c == 200 and d is Array else null))


func state(done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/api/state", null, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		if done.is_valid():
			done.call(d if c == 200 and d is Dictionary else null))


func claim(done: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/claim", {}, func(c: int, _d: Variant, _b: PackedByteArray) -> void: done.call(c == 200))


## action: load (extra.id) | play | pause | seek (extra.position). Fetches the current
## generation first so a stale command is never sent. done(ok: bool, state_or_error: Variant)
func control(action: String, extra: Dictionary, done: Callable) -> void:
	state(func(st: Variant) -> void:
		if st == null:
			done.call(false, "No state")
			return
		var cmd := {"action": action, "generation": int(st.get("generation", 0)), "requestId": "%d-%d" % [Time.get_ticks_usec(), randi()]}
		cmd.merge(extra)
		call_api(HTTPClient.METHOD_POST, "/api/control", cmd, func(c: int, d: Variant, _b: PackedByteArray) -> void:
			done.call(c == 200, d)))


## Single-use, view-only ticket another client (e.g. the web build) can redeem. done(ticket, "" on failure)
func view_ticket(done: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/handoff", {}, func(c: int, d: Variant, _b: PackedByteArray) -> void:
		done.call(str(d.get("ticket", "")) if c == 200 and d is Dictionary else ""))


## Ends the session so the controller seat frees immediately (else the gateway waits 15 s).
func logout(done: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/logout", {}, func(_c: int, _d: Variant, _b: PackedByteArray) -> void:
		cookie = ""
		signed_in = false
		done.call())



## One transcoded chunk of the current film: kind "video" (concatenated JPEGs) or "audio" (MP3).
## done(bytes: PackedByteArray, empty on failure)
func segment(kind: String, start: float, length: float, done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/api/segment?kind=%s&start=%.3f&len=%.3f" % [kind, start, length], null,
		func(c: int, _d: Variant, b: PackedByteArray) -> void:
			if done.is_valid():
				done.call(b if c == 200 else PackedByteArray()), 45.0)
