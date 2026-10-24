extends Node
## CinemaSession autoload: the one shared movie night on Screen 1.
## The host's CinemaSource (the Emby gateway, or the labelled Demo library when the service is
## unreachable) is the playback authority. The host re-broadcasts film / playing / position to
## every peer over Net, so viewers and the in-world screen never need media credentials.
## Scene side (screen video, curtains, lights): read film, playing, position_now() and the signals.
## Lobby kiosk -> cinema_kiosk.gd; cinema seats -> cinema_hud.gd; close-up -> cinema_player.gd.

signal film_selected(film: Dictionary, by_name: String)
signal playback_changed(playing: bool, position: float)
signal watchers_changed(watchers: Array)
signal suggestions_changed(suggestions: Array)
signal seats_changed(saved: Dictionary)
signal source_changed

const KIOSK := preload("res://ui/activities/cinema/cinema_kiosk.gd")
const HUD := preload("res://ui/activities/cinema/cinema_hud.gd")
const PLAYER := preload("res://ui/activities/cinema/cinema_player.gd")
const FILM_KEYS := ["id", "title", "year", "duration_s", "genres", "summary"]

var host_id := 0
var film := {}                ## {id, title, year, duration_s, genres, summary}
var playing := false
var watchers: Array = []      ## [{id, name}] seated in the auditorium
var suggestions: Array = []   ## [{film, by, by_id}] for the host's queue
var saved_seats := {}         ## seat node name -> peer id
var source: CinemaSource
var _pos := 0.0
var _pos_ms := 0
var _watch := {}
var _hud: Control
var _kiosk: Control


func _ready() -> void:
	Activities.requested.connect(_on_activity)
	Net.roster_changed.connect(_on_roster)
	seats_changed.connect(_place_markers)


## Lazily connect the media source: the gateway first, the Demo library if it is unreachable.
func ensure_source() -> CinemaSource:
	if source == null:
		_use(EmbyServiceSource.new(PLAYER.service_url()))
	return source


func use_demo() -> void:
	_use(CinemaSource.DemoSource.new())


func _use(s: CinemaSource) -> void:
	if is_instance_valid(source):
		source.queue_free()
	source = s
	add_child(s)
	source_changed.emit()
	s.status_changed.connect(func(st: String, _d: String) -> void:
		if st == "offline" and s == source and s.provider_type != "demo":
			use_demo.call_deferred())
	s.snapshot_changed.connect(_on_snapshot.bind(s))
	s.notice.connect(func(t: String) -> void: UIWidgets.toast(self, t, "info"))
	s.connect_source()


func is_host() -> bool:
	return host_id != 0 and host_id == Net.local_id()


## Anyone may start when there is no host; the first to start becomes host.
func can_start() -> bool:
	return (host_id == 0 or is_host()) and ensure_source().can_host()


func position_now() -> float:
	var p := _pos + ((Time.get_ticks_msec() - _pos_ms) / 1000.0 if playing else 0.0)
	return minf(p, float(film.get("duration_s", p))) if float(film.get("duration_s", 0.0)) > 0.0 else p


func me_name() -> String:
	return str(Net.local_profile().get("name", "You"))


# ---- intents ---------------------------------------------------------------------------
func start_movie(f: Dictionary) -> void:
	if not can_start():
		return
	_send("_set_host", [Net.local_id()])
	_send("_picked", [_clean(f), me_name()])
	source.request_load(str(f["id"]))
	_send("_drop_suggestion", [str(f["id"])])


func suggest(f: Dictionary) -> void:
	_send("_suggested", [_clean(f), me_name(), Net.local_id()])


func set_playing(on: bool) -> void:
	if is_host() and on:
		source.request_play()
	elif is_host():
		source.request_pause()


func seek(seconds: float) -> void:
	if is_host():
		source.request_seek(seconds)


## The gateway's controller seat stays with this client (it holds the session); the new host
## drives playback through it. shortcut: hand-off is social only until per-peer gateway sessions exist.
func hand_off(peer_id: int) -> void:
	if is_host() and peer_id != Net.local_id():
		_send("_set_host", [peer_id])


func save_seat(seat_name: String) -> void:
	_send("_seat", [seat_name, Net.local_id()])


func say(text: String) -> void:
	if Net.is_online():
		Net.say(text)
	else:
		Net.chat_received.emit(me_name(), text)


# ---- activity routing ------------------------------------------------------------------
func _on_activity(activity: String, anchor: Node, player: Node) -> void:
	if activity != "cinema":
		return
	if anchor is SeatSpot:
		_open_hud(anchor, player)
	else:
		open_kiosk()


func open_kiosk() -> Control:
	if is_instance_valid(_kiosk):
		return _kiosk
	ensure_source()
	_kiosk = KIOSK.new()
	UIRouter.push(_kiosk)
	_kiosk.tree_exiting.connect(func() -> void: UIRouter.remove(_kiosk))
	return _kiosk


func _open_hud(seat: Node, player: Node) -> void:
	if is_instance_valid(_hud):
		return
	_hud = HUD.new()
	_hud.set("seat", seat)
	_hud.set("player", player)
	UIRouter.push(_hud)
	_hud.tree_exiting.connect(func() -> void:
		UIRouter.remove(_hud)
		_send("_watching", [Net.local_id(), me_name(), false]))
	_send("_watching", [Net.local_id(), me_name(), true])
	if host_id != 0 and not is_host():
		_send_to(host_id, "_hello", [Net.local_id()])


## Close-up: the webview video surface (Esc returns to the seat).
func open_closeup() -> void:
	var url := ""
	if source != null:
		url = await source.closeup_url()
	if url == "":
		UIWidgets.toast(self, "Close-up needs the cinema service", "info")
		return
	var p: Control = PLAYER.new()
	p.set("url", url)
	UIRouter.push(p)


# ---- net -------------------------------------------------------------------------------
func _send(method: String, args: Array) -> void:
	if Net.is_online():
		callv("rpc", [method] + args)
	else:
		callv(method, args)


func _send_to(peer: int, method: String, args: Array) -> void:
	if not Net.is_online() or peer == Net.local_id():
		callv(method, args)
	else:
		callv("rpc_id", [peer, method] + args)


func _from_host() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == host_id or host_id == 0 or not Net.is_online()


@rpc("any_peer", "call_local", "reliable")
func _set_host(id: int) -> void:
	if not _from_host() and multiplayer.get_remote_sender_id() != id:
		return
	host_id = id
	watchers_changed.emit(watchers)


@rpc("any_peer", "call_local", "reliable")
func _picked(f: Dictionary, by_name: String) -> void:
	film = f
	_pos = 0.0
	_pos_ms = Time.get_ticks_msec()
	film_selected.emit(film, by_name)
	_pin_doors()
	var world := get_tree().get_first_node_in_group("world")
	if world == null or str(world.call("current_location_id")) == "cinema":
		UIWidgets.toast(self, "%s picked %s · find a seat!" % [by_name, film.get("title", "a film")], "film", 4.0)


@rpc("any_peer", "call_local", "reliable")
func _playback(f: Dictionary, on: bool, pos: float) -> void:
	if not _from_host():
		return
	if str(f.get("id", "")) != str(film.get("id", "")) and not f.is_empty():
		film = f
		_pin_doors()
	playing = on
	_pos = pos
	_pos_ms = Time.get_ticks_msec()
	playback_changed.emit(playing, pos)


@rpc("any_peer", "call_local", "reliable")
func _suggested(f: Dictionary, by_name: String, by_id: int) -> void:
	for s in suggestions:
		if s["film"]["id"] == f["id"]:
			return
	suggestions.append({"film": f, "by": by_name, "by_id": by_id})
	suggestions_changed.emit(suggestions)
	if is_host():
		UIWidgets.toast(self, "%s suggested %s" % [by_name, f.get("title", "")], "film")


@rpc("any_peer", "call_local", "reliable")
func _drop_suggestion(media_id: String) -> void:
	suggestions = suggestions.filter(func(s: Dictionary) -> bool: return s["film"]["id"] != media_id)
	suggestions_changed.emit(suggestions)


@rpc("any_peer", "call_local", "reliable")
func _watching(id: int, who: String, on: bool) -> void:
	if on:
		_watch[id] = who
	else:
		_watch.erase(id)
		for k in saved_seats.keys():
			if saved_seats[k] == id:
				saved_seats.erase(k)
		seats_changed.emit(saved_seats)
	watchers = _watch.keys().map(func(k: int) -> Dictionary: return {"id": k, "name": _watch[k]})
	watchers_changed.emit(watchers)


@rpc("any_peer", "call_local", "reliable")
func _seat(seat_name: String, by_id: int) -> void:
	for k in saved_seats.keys():
		if saved_seats[k] == by_id:
			saved_seats.erase(k)
	saved_seats[seat_name] = by_id
	seats_changed.emit(saved_seats)


## Late joiner asks the host for the current night; the host answers only to them.
@rpc("any_peer", "call_local", "reliable")
func _hello(peer: int) -> void:
	if is_host():
		_send_to(peer, "_sync", [host_id, film, playing, position_now(), _watch, saved_seats, suggestions])


@rpc("any_peer", "call_local", "reliable")
func _sync(h: int, f: Dictionary, on: bool, pos: float, w: Dictionary, seats: Dictionary, sug: Array) -> void:
	host_id = h
	film = f
	_watch.merge(w)
	saved_seats = seats
	suggestions = sug
	_playback(f, on, pos)
	_watching(Net.local_id(), me_name(), _watch.has(Net.local_id()))
	seats_changed.emit(saved_seats)
	suggestions_changed.emit(suggestions)
	_pin_doors()


func _on_snapshot(snap: Dictionary, s: CinemaSource) -> void:
	if s != source or not is_host():
		return
	var f := film
	if str(snap.get("media_id", "")) != "" and str(snap["media_id"]) != str(film.get("id", "")):
		f = _find(str(snap["media_id"]), snap)
	var on := bool(snap.get("playing", false))
	var pos := s.position_now()
	if on != playing or absf(pos - position_now()) > 1.5 or f != film:
		_send("_playback", [f, on, pos])


func _find(media_id: String, snap: Dictionary) -> Dictionary:
	for t in source.items:
		if str(t["id"]) == media_id:
			return _clean(t)
	return {"id": media_id, "title": str(snap.get("title", "Feature")), "year": int(snap.get("year", 0)),
		"duration_s": float(snap.get("duration_s", 0.0)), "genres": [], "summary": ""}


func _clean(f: Dictionary) -> Dictionary:
	var out := {}
	for k in FILM_KEYS:
		if f.has(k):
			out[k] = f[k]
	return out


func _on_roster() -> void:
	if host_id == 0 or not Net.is_online():
		return
	var ids: Array = Net.roster().map(func(p: Dictionary) -> int: return int(p.get("id", 0)))
	if not ids.has(host_id):
		host_id = 0
		watchers_changed.emit(watchers)


## "Now showing" pin over the auditorium doors, for everyone in the lobby.
func _pin_doors() -> void:
	for door_name in ["LobbyScreenDoor"]:
		var door := get_tree().root.find_child(door_name, true, false) as Node3D
		if door == null:
			continue
		var pin := door.get_node_or_null("NowShowing") as Label3D
		if pin == null:
			pin = Label3D.new()
			pin.name = "NowShowing"
			pin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			pin.font = preload("res://fonts/Fredoka-Bold.ttf")
			pin.font_size = 56
			pin.pixel_size = 0.004
			pin.outline_size = 14
			pin.modulate = Color("#FFE7A8")
			pin.outline_modulate = Color("#1B2238")
			pin.position = Vector3(0.0, 2.75, 0.0)
			door.add_child(pin)
		pin.text = "★ Now showing ★\n%s" % str(film.get("title", "")) if not film.is_empty() else ""


## Reservation markers on saved seats (interaction_props/seat_reservation_marker), for everyone.
func _place_markers(_saved: Dictionary = {}) -> void:
	for m in get_tree().get_nodes_in_group("cinema_seat_marker"):
		if not saved_seats.has(String(m.get_parent().name)):
			m.queue_free()
	for seat_name in saved_seats:
		var seat := get_tree().root.find_child(seat_name, true, false) as Node3D
		if seat == null or seat.has_node("SeatMarker"):
			continue
		var m := AssetPack.spawn("interaction_props", "seat_reservation_marker")
		if m:
			m.name = "SeatMarker"
			m.add_to_group("cinema_seat_marker")
			seat.add_child(m)
