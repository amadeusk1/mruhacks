class_name GatewaySource
extends CinemaSource
## CinemaSource over the Pengloo cinema gateway (cinema port 4/5, flag pengloo/cinema/service_enabled).
## Uses the shared CinemaService client (callbacks, timeouts, no coroutines); the playback snapshot
## comes from the shared player's server-state polls, so the UI, 3D screen and overlay agree.
## The invite code goes straight to the gateway and is not kept.

var client: CinemaServiceClient
var _revision := -1


func _init() -> void:
	client = CinemaService.client
	provider_type = "emby"
	source_name = "Pengloo cinema"
	CinemaService.player.state_changed.connect(_on_state)
	CinemaService.signed_in_changed.connect(_on_signed_in)  # signed in elsewhere (pill, overlay)


func _on_signed_in(on: bool) -> void:
	if on and status in ["signed_out", "connecting"]:
		_status("connected", "")
		search("")


func connect_source() -> void:
	if client.signed_in:
		_status("connected", "")
		search("")
		return
	_status("connecting", "")
	client.health(_on_health)


func _on_health(up: bool) -> void:
	_status("signed_out" if up else "offline", "" if up else "Cinema service unreachable")


func sign_in(code: String) -> void:
	_status("connecting", "")
	CinemaService.sign_in(code, _on_login)


func _on_login(ok: bool, err: String) -> void:
	if not ok:
		_status("signed_out", err)
		return
	_status("connected", "")
	search("")


func search(query: String) -> void:
	client.library(query, _on_library)


func _on_library(films: Variant) -> void:
	items = []
	for f in (films if films is Array else []):
		items.append({"id": str(f.get("id", "")), "title": str(f.get("title", "")), "year": int(f.get("year", 0)),
			"duration_s": float(f.get("duration", 0.0)), "summary": "", "kind": str(f.get("kind", "movie")),
			"poster": bool(f.get("poster", false)), "season": int(f.get("season", 0)), "episode": int(f.get("episode", 0))})
	if items.is_empty() and status == "connected":
		_status("empty", "")
	catalog_changed.emit(items)


func fetch_show(id: String, done: Callable) -> void:
	client.show(id, done)


## Host: take the controller seat if free, load the film, start it for everyone.
func request_load(media_id: String) -> void:
	client.claim(func(_claimed: bool) -> void:
		client.control("load", {"id": media_id}, func(ok: bool, _d: Variant) -> void:
			if ok:
				client.control("play", {}, _on_control)))


func request_play() -> void:
	client.control("play", {}, _on_control)


func request_pause() -> void:
	client.control("pause", {}, _on_control)


func request_seek(seconds: float) -> void:
	client.control("seek", {"position": seconds}, _on_control)


func _on_control(ok: bool, d: Variant) -> void:
	if ok and d is Dictionary:
		_on_state(d)
	elif not ok:
		detail = str(d.get("error", "Playback command failed")) if d is Dictionary else "Playback command failed"


## Gateway state -> CinemaSource snapshot. Only meaningful changes are emitted (the UI rebuilds on
## each one); the position in between is extrapolated by position_now().
func _on_state(st: Dictionary) -> void:
	var rev := int(st.get("revision", 0))
	var gen := int(st.get("generation", 0))
	if _revision >= 0 and rev < _revision and gen <= int(snapshot.get("stream_generation", 0)):
		return
	_revision = rev
	var media: Dictionary = st.get("media", {}) if st.get("media") is Dictionary else {}
	var playing := bool(st.get("playing", false))
	var pos := float(st.get("position", 0.0))
	if playing:
		pos += maxf(0.0, float(st.get("serverNow", 0)) - float(st.get("updatedAt", 0))) / 1000.0
	var ctrl := str(st.get("controller", ""))
	var me := str(client.me.get("id", ""))
	var s := {"screening_id": "screen1", "media_id": str(media.get("id", "")), "playing": playing, "position_s": pos,
		"duration_s": float(media.get("duration", 0.0)), "stream_generation": int(st.get("generation", 0)),
		"controller_player_id": str(Net.local_id()) if ctrl != "" and ctrl == me else ctrl,
		"phase": "idle" if str(media.get("id", "")) == "" else ("playing" if playing else "paused"),
		"viewers": int(st.get("viewers", 0)), "title": str(media.get("title", ""))}
	for k in ["media_id", "playing", "controller_player_id", "viewers"]:
		if s[k] != snapshot.get(k):
			_set_snapshot(s)
			return
	if absf(pos - position_now()) > 1.5:
		_set_snapshot(s)


func _status(s: String, d: String) -> void:
	status = s
	detail = d
	status_changed.emit(s, d)


## Signed in with a host code (can pick and control films).
func can_host() -> bool:
	return client.signed_in and bool(client.me.get("eligible", false))
