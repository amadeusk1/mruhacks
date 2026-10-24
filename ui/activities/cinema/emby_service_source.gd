class_name EmbyServiceSource
extends CinemaSource
## CinemaSource over the Pengloo cinema gateway (services/cinema). The gateway holds the Emby
## server URL and API key; this client only ever holds its own session cookie, opaque item ids
## and poster bytes. The invite code typed at the kiosk goes straight to /api/login and is dropped.

var base := ""          ## ".../cinema" (no trailing slash)
var _origin := ""
var _cookie := ""
var _me := {}
var _poll: Timer
var _search_gen := 0
var _posters := {}


func _init(service_url: String) -> void:
	base = service_url.trim_suffix("/")
	var scheme_end := base.find("://") + 3
	var path_at := base.find("/", scheme_end)
	_origin = base if path_at < 0 else base.substr(0, path_at)
	provider_type = "emby"


func connect_source() -> void:
	_status("connecting", "")
	var r := await _call(HTTPClient.METHOD_GET, "/health")
	if r["code"] != 200:
		_status("offline", "Cinema service unreachable")
		return
	source_name = "Emby"
	_status("signed_out", "Enter your cinema invite code")


func sign_in(player_name: String, code: String) -> void:
	_status("signing_in", "")
	var r := await _call(HTTPClient.METHOD_POST, "/api/login", {"name": player_name, "code": code})
	if r["code"] != 200 or not r.has("cookie"):
		_status("signed_out", _error(r, "Sign-in failed"))
		return
	_cookie = r["cookie"]
	var me := await _call(HTTPClient.METHOD_GET, "/api/me")
	_me = me["data"] if me["data"] is Dictionary else {}
	_status("connected", "")
	if _poll == null:
		_poll = Timer.new()
		_poll.wait_time = 1.0
		_poll.timeout.connect(_refresh)
		add_child(_poll)
	_poll.start()
	_refresh()
	search("")


func can_host() -> bool:
	return bool(_me.get("eligible", false))


func search(query: String) -> void:
	_search_gen += 1
	var gen := _search_gen
	var r := await _call(HTTPClient.METHOD_GET, "/api/library?q=" + query.uri_encode())
	if gen != _search_gen:
		return
	if r["code"] != 200 or not r["data"] is Array:
		notice.emit(_error(r, "Library unavailable"))
		return
	items = []
	for t in r["data"]:
		var id := str(t.get("id", ""))
		items.append({"id": id, "title": str(t.get("title", "")), "year": int(t.get("year", 0)),
			"duration_s": float(t.get("duration", 0.0)), "genres": t.get("genres", []) if t.get("genres") is Array else [],
			"summary": str(t.get("overview", "")), "thumb": _posters.get(id)})
	var want := "empty" if items.is_empty() and query == "" else "connected"
	if status != want:
		_status(want, "")
	catalog_changed.emit(items)
	_load_posters(items.duplicate(), gen)


func _load_posters(list: Array, gen: int) -> void:
	for t in list:
		if gen != _search_gen:
			return
		var id: String = t["id"]
		if _posters.has(id):
			continue
		var r := await _call(HTTPClient.METHOD_GET, "/api/poster/" + id.uri_encode(), null, true)
		var tex: Texture2D = _texture(r["body"]) if r["code"] == 200 else null
		_posters[id] = tex
		if tex:
			t["thumb"] = tex
			for it in items:
				if it["id"] == id:
					it["thumb"] = tex
			thumb_ready.emit(id, tex)


static func _texture(b: PackedByteArray) -> Texture2D:
	if b.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if b[0] == 0xFF and b[1] == 0xD8:
		err = img.load_jpg_from_buffer(b)
	elif b[0] == 0x89 and b[1] == 0x50:
		err = img.load_png_from_buffer(b)
	elif b.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(b)
	return ImageTexture.create_from_image(img) if err == OK else null


## The gateway is one screening: take the controller seat if free, then load and start the film.
func request_load(media_id: String) -> void:
	if not is_controller(str(Net.local_id())):
		var c := await _call(HTTPClient.METHOD_POST, "/api/claim", {})
		if c["code"] != 200:
			notice.emit(_error(c, "Someone else is hosting Screen 1"))
			return
		await _refresh()
	if await _control({"action": "load", "id": media_id}):
		await _control({"action": "play"})


func request_play() -> void:
	_control({"action": "play"})


func request_pause() -> void:
	_control({"action": "pause"})


func request_seek(seconds: float) -> void:
	_control({"action": "seek", "position": seconds})


func closeup_url() -> String:
	if _cookie == "":
		return ""
	var r := await _call(HTTPClient.METHOD_POST, "/api/handoff", {})
	if r["code"] != 200 or not r["data"] is Dictionary:
		notice.emit(_error(r, "Close-up unavailable"))
		return ""
	return "%s/?embed=1&ticket=%s" % [base, str(r["data"].get("ticket", "")).uri_encode()]


func _control(cmd: Dictionary) -> bool:
	for attempt in 2:
		cmd["generation"] = int(snapshot.get("stream_generation", 0))
		cmd["requestId"] = "%d-%d" % [Time.get_ticks_usec(), randi()]
		var r := await _call(HTTPClient.METHOD_POST, "/api/control", cmd)
		if r["code"] == 200:
			await _refresh()
			return true
		if r["code"] != 409 or attempt == 1:
			notice.emit(_error(r, "Playback command failed"))
			return false
		await _refresh()  # stale generation: pick up the new one and retry once
	return false


func _refresh() -> void:
	var r := await _call(HTTPClient.METHOD_GET, "/api/state")
	if r["code"] == 401:
		_cookie = ""
		if _poll:
			_poll.stop()
		_status("signed_out", "Session expired · sign in again")
		return
	if r["code"] != 200 or not r["data"] is Dictionary:
		return
	var st: Dictionary = r["data"]
	var media: Dictionary = st.get("media", {}) if st.get("media") is Dictionary else {}
	var playing := bool(st.get("playing", false))
	var pos := float(st.get("position", 0.0))
	if playing:
		pos += maxf(0.0, float(st.get("serverNow", 0)) - float(st.get("updatedAt", 0))) / 1000.0
	var ctrl := str(st.get("controller", ""))
	var media_id := str(media.get("id", ""))
	snapshot = {"screening_id": "screen1", "media_id": media_id, "title": str(media.get("title", "")),
		"year": int(media.get("year", 0)), "stream_generation": int(st.get("generation", 0)),
		"revision": int(st.get("revision", 0)), "playing": playing, "position_s": pos,
		"duration_s": float(media.get("duration", 0.0)), "viewers": int(st.get("viewers", 0)),
		"controller_player_id": str(Net.local_id()) if ctrl != "" and ctrl == str(_me.get("id", "")) else ctrl,
		"phase": "idle" if media_id == "" else ("playing" if playing else "paused"), "_local_ms": Time.get_ticks_msec()}
	snapshot_changed.emit(snapshot)


func _status(s: String, d: String) -> void:
	status = s
	detail = d
	status_changed.emit(s, d)


static func _error(r: Dictionary, fallback: String) -> String:
	var d: Variant = r.get("data")
	return str(d.get("error", fallback)) if d is Dictionary else fallback


func _call(method: int, path: String, body: Variant = null, raw := false) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0 if raw else 8.0   # async; a slow or dead service just yields code 0
	add_child(http)
	var headers := PackedStringArray(["Origin: " + _origin, "Content-Type: application/json"])
	if _cookie != "":
		headers.append("Cookie: " + _cookie)
	var out := {"code": 0, "data": null, "body": PackedByteArray()}
	if http.request(base + path, headers, method, "" if body == null else JSON.stringify(body)) != OK:
		http.queue_free()
		return out
	var res: Array = await http.request_completed
	http.queue_free()
	out["code"] = int(res[1])
	out["body"] = res[3]
	for h in res[2] as PackedStringArray:
		if h.to_lower().begins_with("set-cookie:"):
			var c := h.substr(11).strip_edges().get_slice(";", 0)
			if c.begins_with("pengloo_cinema="):
				out["cookie"] = c
	if not raw:
		out["data"] = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return out
