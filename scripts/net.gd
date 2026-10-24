extends Node

## Listen server for two windows on this machine.
## Each penguin simulates its own walk. The host owns the roster,
## which place everyone is in, and who is sitting.

signal session_started
signal roster_changed
signal remote_pose(peer_id: int, x: float, y: float, z: float, yaw: float, speed: float, sitting: bool)
signal seat_denied(bench_key: String)
signal connect_failed(message: String)
signal host_lost
signal chat_received(speaker: String, message: String)
signal invite_received(from_id: int, from_name: String, kind: String, ticket: String)
signal visit_denied(owner_name: String)
signal home_layout(owner_id: int, layout: String)
signal sled_gate(race_id: int, phase: String, seconds: float)
signal sled_pose(peer_id: int, x: float, y: float, z: float, yaw: float, steer: float, crashed: bool)
signal arcade_state(state: Dictionary)
signal emote_played(peer_id: int, clip: String)

const _CourtMatch := preload("res://scripts/court_match.gd")
const _SnowMatch := preload("res://scripts/snow_match.gd")
const EMOTE_GAP_MS := 800
const DEFAULT_PORT := 7777
## --net-port=N on the command line: parallel local test sessions without colliding on 7777.
var PORT := DEFAULT_PORT
const ADDRESS := "127.0.0.1"
const COATS: Array[Color] = [
	Color(0.18, 0.45, 0.78),
	Color(0.18, 0.62, 0.42),
	Color(0.90, 0.72, 0.22),
	Color(0.86, 0.38, 0.58),
	Color(0.52, 0.38, 0.78),
	Color(0.85, 0.42, 0.22),
]

enum Mode { OFF, SOLO, HOST, CLIENT }

var _mode := Mode.OFF
var _players: Dictionary = {}
## Headless dedicated server (deploy): peer 1 is authority only, never a player in _players/roster.
var dedicated := OS.get_cmdline_user_args().has("--dedicated")
var _roster: Array = []
var _local_name := "Penguin"
var _local_color := 0
## Coat chosen on the Your Penguin screen (UI core). Used for solo and hosting; a joining client
## still gets the host's pick. shortcut: send it in hello() when the protocol next changes.
var preferred_color := -1
var _color_next := 0
var _session_open := false
var _closing := false
var _place_location := ""
var _place_spawn := ""
var _place_hidden := true
var _place_igloo := 0
var _latest_pose: Dictionary = {}
var _have_pose := false
var _pose_wait := 0.0
var _latest_sled: Dictionary = {}
var _have_sled := false
var _sled_wait := 0.0
var _sled_race := 0
var _sled_phase := ""
var _sled_left := 0.0
var _sled_status: Dictionary = {}
var _sled_notice: Dictionary = {}
var _arc_cab := ""
var _arc_solo := false
var _arc_pad := 0.5
var _arc: Dictionary = {}
var _court: RefCounted
var _court_bodies: Dictionary = {}
var _court_state: Dictionary = {}
var _court_send := 0.0
var _court_sig := ""
var _court_box := AABB()
var _court_on := false
var _voice_pos: Dictionary = {}     # host: peer -> last pose position (voice proximity)
var _voice_budget: Dictionary = {}  # host: peer -> bytes allowed this second
const VOICE_RANGE := 20.0
const VOICE_BYTES_PER_SEC := 24000
var _snow: RefCounted
var _snow_state: Dictionary = {}
var _snow_send := 0.0
var _snow_sig := ""
var _snow_area := Rect2()  # the field; players within SNOW_REACH of it count as at the arena
var _snow_on := false
const SNOW_REACH := 3.0
var _emote_at: Dictionary = {}  # host: peer -> msec of the last emote it relayed
var _emote_seen: Dictionary = {}  # client: peer -> host stamp of the last emote played
var _clock_offset := 0.0  # server clock minus ours; the host is the world-time authority
var _clock_wait := 0.0
var _clock_skew := 0.0  # debug builds: --clock-skew=SECONDS fakes a wrong local clock (tools/daynight_sync)
const CLOCK_RESYNC_S := 30.0
const INVITE_KINDS := ["home", "cinema"]
const INVITE_COOLDOWN_MS := 4000   # same sender, target and kind: drop repeats inside this window
const HOME_MAX_BYTES := 32768
var _invite_sent: Dictionary = {}  # host: "from:target:kind" -> ticks msec of the last delivery
var _granted: Dictionary = {}      # host: owner id -> {guest id: true} (invited into that home)
var _homes: Dictionary = {}        # host: owner id -> home layout JSON
var court_loft := 0.5  # how high the local player aims a shot: 0 flattest, 1 tallest lob


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-port="):
			PORT = int(a.trim_prefix("--net-port="))
		elif a.begins_with("--clock-skew=") and OS.is_debug_build():
			_clock_skew = float(a.trim_prefix("--clock-skew="))
	_court = _CourtMatch.new()
	_court_state = _court.view()
	_snow = _SnowMatch.new()
	if OS.get_cmdline_user_args().has("--snow-1v1"):
		_snow.team_size = 1
	_snow_state = _snow.view()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _closing:
		return
	_tick_clock(delta)
	_tick_arcade(delta)
	_tick_sled(delta)
	_tick_court(delta)
	_tick_snow(delta)
	if _place_location == "sled_hill":
		_tick_sled_pose(delta)
		return
	if not is_online() or _place_hidden or not _have_pose:
		return
	_pose_wait -= delta
	if _pose_wait > 0.0:
		return
	_pose_wait = 0.05
	if _mode == Mode.HOST:
		_relay_pose(local_id(), _latest_pose)
	elif multiplayer.multiplayer_peer != null:
		submit_pose.rpc_id(
			1,
			float(_latest_pose["x"]),
			float(_latest_pose["y"]),
			float(_latest_pose["z"]),
			float(_latest_pose["yaw"]),
			float(_latest_pose["speed"]),
			bool(_latest_pose["sitting"])
		)


## Shared world clock (unix seconds as the host sees them). Day/night, the dance beat and other
## time-driven visuals read this so every player sees the same moment.
func world_time() -> float:
	return _now() + _clock_offset


func _now() -> float:
	return Time.get_unix_time_from_system() + _clock_skew


func _tick_clock(delta: float) -> void:
	if _mode != Mode.CLIENT or not _session_open:
		return
	_clock_wait -= delta
	if _clock_wait <= 0.0:
		_clock_wait = CLOCK_RESYNC_S
		request_clock.rpc_id(1, _now())


@rpc("any_peer", "call_remote", "reliable")
func request_clock(client_sent: float) -> void:
	if _mode == Mode.HOST:
		answer_clock.rpc_id(multiplayer.get_remote_sender_id(), client_sent, _now())


@rpc("authority", "call_remote", "reliable")
func answer_clock(client_sent: float, server_now: float) -> void:
	if _mode != Mode.CLIENT:
		return
	var now := _now()
	_clock_offset = server_now + (now - client_sent) * 0.5 - now  # assume a symmetric trip


func is_online() -> bool:
	return _mode == Mode.HOST or _mode == Mode.CLIENT


func local_id() -> int:
	if _mode == Mode.HOST or _mode == Mode.CLIENT:
		return multiplayer.get_unique_id()
	return 1


func local_profile() -> Dictionary:
	return {"name": _local_name, "color": _local_color}


func role_label() -> String:
	match _mode:
		Mode.HOST:
			return "Host"
		Mode.CLIENT:
			return "Join"
		_:
			return "Solo"


func roster() -> Array:
	return _roster


func coat_color(index: int) -> Color:
	return COATS[posmod(index, COATS.size())]


func bench_held_by_other(key: String) -> bool:
	if not is_online() or key == "":
		return false
	var owner := _bench_owner(key)
	return owner != 0 and owner != local_id()


func play_solo(player_name: String) -> void:
	if _mode != Mode.OFF:
		return
	_mode = Mode.SOLO
	_local_name = _clean_name(player_name)
	_local_color = maxi(preferred_color, 0)
	_session_open = true
	print("Net solo as %s" % _local_name)
	session_started.emit()


func host_game(player_name: String) -> String:
	if _mode != Mode.OFF:
		return "Already in a session."
	var peer: MultiplayerPeer
	var err: Error
	if use_websocket():
		peer = WebSocketMultiplayerPeer.new()
		err = peer.create_server(PORT)
	else:
		peer = ENetMultiplayerPeer.new()
		err = peer.create_server(PORT, 8)
	if err != OK:
		return "Port %s is already in use." % PORT
	_mode = Mode.HOST
	multiplayer.multiplayer_peer = peer
	_local_name = _clean_name(player_name)
	_local_color = _take_color() if preferred_color < 0 else preferred_color
	_place_hidden = true
	if not dedicated:  # a listen-server host plays; a dedicated one never joins its own roster
		_players[local_id()] = _blank(local_id(), _local_name, _local_color)
	_session_open = true
	print("Net hosting on %s:%s as peer %s (%s)" % [ADDRESS, PORT, local_id(), _local_name])
	_broadcast()
	session_started.emit()
	return ""


func join_game(player_name: String) -> String:
	if _mode != Mode.OFF:
		return "Already in a session."
	var peer: MultiplayerPeer
	var err: Error
	if use_websocket():
		peer = WebSocketMultiplayerPeer.new()
		err = peer.create_client(websocket_url())
	else:
		peer = ENetMultiplayerPeer.new()
		err = peer.create_client(ADDRESS, PORT)
	if err != OK:
		return "Couldn't open a connection to %s:%s." % [ADDRESS, PORT]
	_mode = Mode.CLIENT
	_local_name = _clean_name(player_name)
	_place_hidden = true
	multiplayer.multiplayer_peer = peer
	print("Net joining %s:%s as %s" % [ADDRESS, PORT, _local_name])
	get_tree().create_timer(6.0).timeout.connect(_on_hello_timeout, CONNECT_ONE_SHOT)
	return ""


func shutdown() -> void:
	_force_offline()


func hide_presence() -> void:
	if not is_online():
		return
	_send_place(_place_location, _place_spawn, true, _place_igloo)


func arrive(location: String, spawn: String, hidden: bool, igloo: int = 0) -> void:
	# Solo never opens a peer, but the court still needs to know you are in town.
	_send_place(location, spawn, hidden, igloo)


## kind "home" (your igloo) or "cinema" (ticket: an optional single-use cinema view ticket, so the
## guest watches without signing in).
func invite(target_id: int, kind := "home", ticket := "") -> void:
	if not is_online() or _closing or target_id <= 0 or target_id == local_id():
		return
	if _mode == Mode.HOST:
		_host_invite(local_id(), target_id, kind, ticket)
	else:
		request_invite.rpc_id(1, target_id, kind, ticket)


## Who may walk into your home uninvited: "only_me" | "friends" | "anyone" (Home Visitors screen).
## There is no friends service yet, so "friends" means players you invited or who invited you.
func set_visitors(policy: String) -> void:
	if _mode == Mode.HOST:
		_host_visitors(local_id(), policy)
	elif _mode == Mode.CLIENT and not _closing:
		request_visitors.rpc_id(1, policy)


## Share your saved home layout so visitors see your furniture, not theirs.
func publish_home(layout: String) -> void:
	if _mode == Mode.HOST:
		_host_home(local_id(), layout)
	elif _mode == Mode.CLIENT and not _closing:
		submit_home.rpc_id(1, layout)


## Ask for an owner's layout; answered through home_layout(owner_id, layout) ("" when unknown).
func fetch_home(owner_id: int) -> void:
	if _mode == Mode.HOST:
		home_layout.emit(owner_id, str(_homes.get(owner_id, "")))
	elif _mode == Mode.CLIENT and not _closing:
		request_home.rpc_id(1, owner_id)


func note_sled(at: Vector3, yaw: float, steer: float, crashed: bool) -> void:
	if not is_online():
		return
	_latest_sled = {
		"x": at.x,
		"y": at.y,
		"z": at.z,
		"yaw": yaw,
		"steer": steer,
		"crashed": crashed,
	}
	_have_sled = true


func sled_retry() -> void:
	_sled_mark("ready")


func sled_done() -> void:
	_sled_mark("done")


func note_pose(at: Vector3, yaw: float, speed: float, sitting: bool) -> void:
	if _place_location == "town" and not _place_hidden:
		_court_bodies[local_id()] = {"x": at.x, "y": at.y, "z": at.z, "yaw": yaw, "speed": speed}
	if not is_online():
		return
	_latest_pose = {
		"x": at.x,
		"y": at.y,
		"z": at.z,
		"yaw": yaw,
		"speed": speed,
		"sitting": sitting,
	}
	_have_pose = true


func claim_bench(key: String) -> bool:
	if not is_online():
		return true
	if bench_held_by_other(key):
		return false
	if _mode == Mode.HOST:
		return _host_claim(local_id(), key)
	request_sit.rpc_id(1, key)
	return true


func say(message: String) -> void:
	if not is_online() or _closing:
		return
	var cleaned := message.strip_edges()
	if cleaned == "":
		return
	if cleaned.length() > 80:
		cleaned = cleaned.substr(0, 80)
	if _mode == Mode.HOST:
		_host_say(local_id(), cleaned)
	else:
		request_say.rpc_id(1, cleaned)


func _host_say(peer_id: int, message: String) -> void:
	message = message.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 80)
	if message.is_empty():
		return
	if not _players.has(peer_id):
		return
	var speaker := str(_players[peer_id]["name"])
	for other_id in _players:
		if int(other_id) == local_id():
			chat_received.emit(speaker, message)
		elif multiplayer.get_peers().has(int(other_id)):
			relay_chat.rpc_id(int(other_id), speaker, message)


func note_fisher(phase: String) -> void:
	if not is_online() or _closing:
		return
	if _mode == Mode.HOST:
		_set_fisher(local_id(), phase)
	else:
		request_fisher.rpc_id(1, phase)


## Seated/station animation style other players should see ("casino", "cinema", "arcade", "").
func note_act(act: String) -> void:
	if not is_online() or _closing:
		return
	if _mode == Mode.HOST:
		_set_act(local_id(), act)
	else:
		request_act.rpc_id(1, act)


## The clip the local penguin is playing right now ("" = plain walk/idle), so every player in the
## room plays it on this penguin's puppet: seats, fishing, activity clips, throws... It rides on the
## roster, so late joiners get ongoing loops too, at the right point (anim_age).
func note_anim(clip: String, loop: bool) -> void:
	if not is_online() or _closing:
		return
	if _mode == Mode.HOST:
		_set_anim(local_id(), clip, loop)
	else:
		request_anim.rpc_id(1, clip, loop)


func _set_anim(id: int, clip: String, loop: bool) -> void:
	if _mode != Mode.HOST or not _players.has(id) or clip.length() > 64:
		return
	if clip != "" and not clip.replace("/", "_").is_valid_identifier():
		return
	var player: Dictionary = _players[id]
	player["anim"] = clip
	player["anim_loop"] = loop
	player["anim_at"] = Time.get_ticks_msec()
	player["anim_n"] = int(player.get("anim_n", 0)) + 1  # a replayed one-shot is a new start
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func request_anim(clip: String, loop: bool) -> void:
	if _mode == Mode.HOST:
		_set_anim(multiplayer.get_remote_sender_id(), clip, loop)


func _set_act(id: int, act: String) -> void:
	if _mode != Mode.HOST or not _players.has(id) or str(_players[id].get("act", "")) == act:
		return
	_players[id]["act"] = act
	_broadcast()


func _set_fisher(id: int, phase: String) -> void:
	if _mode != Mode.HOST or not _players.has(id):
		return
	if str(_players[id].get("fisher", "")) == phase:
		return
	_players[id]["fisher"] = phase
	_broadcast()


func release_bench() -> void:
	if not is_online() or _closing:
		return
	if _mode == Mode.HOST:
		_host_release(local_id())
	else:
		request_stand.rpc_id(1)


func _send_place(location: String, spawn: String, hidden: bool, igloo: int) -> void:
	_place_location = location
	_place_spawn = spawn
	_place_hidden = hidden
	_place_igloo = igloo
	if _mode == Mode.HOST:
		_set_place(local_id(), location, spawn, hidden, igloo)
	elif _mode == Mode.CLIENT and not _closing:
		request_place.rpc_id(1, location, spawn, hidden, igloo)


func _set_place(id: int, location: String, spawn: String, hidden: bool, igloo: int) -> void:
	if not _players.has(id):
		return
	if location == "home" and not hidden and igloo != id and not _may_visit(id, igloo):
		var owner_name := str(_players[igloo]["name"]) if _players.has(igloo) else ""
		if id == local_id():
			visit_denied.emit(owner_name)
		elif multiplayer.get_peers().has(id):
			deny_visit.rpc_id(id, owner_name)
		return
	var player: Dictionary = _players[id]
	var changed := str(player["location"]) != location or bool(player["hidden"]) != hidden or int(player.get("igloo", 0)) != igloo
	player["location"] = location
	player["spawn"] = spawn
	player["hidden"] = hidden
	player["igloo"] = igloo
	if hidden or changed:
		player["bench"] = ""
		player["fisher"] = ""
	if location != "town" or hidden:
		_court_bodies.erase(id)
	_broadcast()
	_sync_sled_members()


func _host_claim(id: int, key: String) -> bool:
	if not _players.has(id) or key == "":
		_deny_seat(id, key)
		return false
	var player: Dictionary = _players[id]
	var location := str(player["location"])
	var expected := location
	if location == "home":
		expected = "home:%s" % int(player.get("igloo", 0))
	if location == "" or bool(player["hidden"]) or expected == "" or not key.begins_with(expected + ":"):
		_deny_seat(id, key)
		return false
	var owner := _owner_id(key)
	if owner != 0 and owner != id:
		_deny_seat(id, key)
		return false
	player["bench"] = key
	_broadcast()
	return true


func _host_release(id: int) -> void:
	if not _players.has(id):
		return
	if str(_players[id]["bench"]) == "":
		return
	_players[id]["bench"] = ""
	_broadcast()


func _deny_seat(id: int, key: String) -> void:
	if _mode != Mode.HOST or id == local_id() or id <= 0:
		return
	if not multiplayer.get_peers().has(id):
		return
	reject_seat.rpc_id(id, key)


func _owner_id(key: String) -> int:
	for peer_id in _players:
		if str(_players[peer_id]["bench"]) == key:
			return int(peer_id)
	return 0


func _bench_owner(key: String) -> int:
	for entry in _roster:
		if str(entry.get("bench", "")) == key:
			return int(entry.get("id", 0))
	return 0


func _relay_pose(from_id: int, pose: Dictionary) -> void:
	if not _players.has(from_id):
		return
	_voice_pos[from_id] = Vector3(float(pose["x"]), float(pose["y"]), float(pose["z"]))
	var sender: Dictionary = _players[from_id]
	if bool(sender["hidden"]) or str(sender["location"]) == "" or str(sender["location"]) == "sled_hill":
		return
	if str(sender["location"]) == "town":
		_court_bodies[from_id] = {
			"x": float(pose["x"]),
			"y": float(pose["y"]),
			"z": float(pose["z"]),
			"yaw": float(pose["yaw"]),
			"speed": float(pose["speed"]),
		}
	for other_id in _players:
		if int(other_id) == from_id:
			continue
		var other: Dictionary = _players[other_id]
		if bool(other["hidden"]) or not _same_room(sender, other):
			continue
		if int(other_id) == local_id():
			remote_pose.emit(
				from_id,
				float(pose["x"]),
				float(pose["y"]),
				float(pose["z"]),
				float(pose["yaw"]),
				float(pose["speed"]),
				bool(pose["sitting"])
			)
		elif multiplayer.get_peers().has(int(other_id)):
			relay_pose.rpc_id(
				int(other_id),
				from_id,
				float(pose["x"]),
				float(pose["y"]),
				float(pose["z"]),
				float(pose["yaw"]),
				float(pose["speed"]),
				bool(pose["sitting"])
			)


# ---- proximity voice (scripts/voice/voice.gd) ------------------------------------------
func send_voice(data: PackedByteArray) -> void:
	if not is_online() or data.size() > 2048:
		return
	if _mode == Mode.HOST:
		_relay_voice(local_id(), data)
	elif multiplayer.multiplayer_peer != null:
		submit_voice.rpc_id(1, data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func submit_voice(data: PackedByteArray) -> void:
	if _mode == Mode.HOST:
		_relay_voice(multiplayer.get_remote_sender_id(), data)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func relay_voice(from_id: int, data: PackedByteArray) -> void:
	Voice.receive(from_id, data)


## Host-authoritative: same room, within VOICE_RANGE, not hidden, rate-capped, quiet rounds dropped.
func _relay_voice(from_id: int, data: PackedByteArray) -> void:
	if not _players.has(from_id) or data.size() > 2048:
		return
	var sec := Time.get_ticks_msec() / 1000
	var b: Dictionary = _voice_budget.get(from_id, {"sec": -1, "left": 0})
	if int(b["sec"]) != sec:
		b = {"sec": sec, "left": VOICE_BYTES_PER_SEC}
	if int(b["left"]) < data.size():
		return
	b["left"] = int(b["left"]) - data.size()
	_voice_budget[from_id] = b
	var sender: Dictionary = _players[from_id]
	if bool(sender["hidden"]) or str(sender["location"]) == "":
		return
	var quiet: Array = SketchClub.game.members() if SketchClub.game.is_quiet() else []
	if quiet.has(from_id):
		return
	for other_id in _players:
		var oid := int(other_id)
		if oid == from_id or quiet.has(oid):
			continue
		var other: Dictionary = _players[other_id]
		if bool(other["hidden"]) or not _same_room(sender, other):
			continue
		if str(sender["location"]) != "sled_hill":  # sled poses don't pass through _relay_pose: room-only there
			if not (_voice_pos.has(from_id) and _voice_pos.has(oid)):
				continue  # position not known yet: stay silent rather than leak across the map
			if (_voice_pos[from_id] as Vector3).distance_to(_voice_pos[oid]) > VOICE_RANGE:
				continue
		if oid == local_id():
			Voice.receive(from_id, data)
		elif multiplayer.get_peers().has(oid):
			relay_voice.rpc_id(oid, from_id, data)


func _broadcast() -> void:
	_roster = _snapshot()
	roster_changed.emit()
	if _mode == Mode.HOST and not _closing and multiplayer.get_peers().size() > 0:
		apply_roster.rpc(_roster)


func _snapshot() -> Array:
	var ids: Array = _players.keys()
	ids.sort()
	var list: Array = []
	for peer_id in ids:
		var player: Dictionary = _players[peer_id]
		list.append({
			"id": int(peer_id),
			"name": str(player["name"]),
			"color": int(player["color"]),
			"location": str(player["location"]),
			"spawn": str(player["spawn"]),
			"hidden": bool(player["hidden"]),
			"bench": str(player["bench"]),
			"igloo": int(player.get("igloo", 0)),
			"fisher": str(player.get("fisher", "")),
			"act": str(player.get("act", "")),
			"anim": str(player.get("anim", "")),
			"anim_loop": bool(player.get("anim_loop", false)),
			"anim_n": int(player.get("anim_n", 0)),
			"anim_age": (Time.get_ticks_msec() - int(player.get("anim_at", 0))) / 1000.0,
			"visitors": str(player.get("visitors", "friends")),
		})
	return list


func _blank(peer_id: int, player_name: String, color_index: int) -> Dictionary:
	return {
		"id": peer_id,
		"name": player_name,
		"color": color_index,
		"location": "",
		"spawn": "",
		"hidden": true,
		"bench": "",
		"igloo": 0,
		"fisher": "",
	}


func _same_room(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("location", "")) == "" or str(a.get("location", "")) != str(b.get("location", "")):
		return false
	if str(a.get("location", "")) == "home" and int(a.get("igloo", 0)) != int(b.get("igloo", 0)):
		return false
	return true


func _host_invite(from_id: int, target_id: int, kind: String, ticket: String) -> void:
	if from_id <= 0 or target_id <= 0 or from_id == target_id or not INVITE_KINDS.has(kind):
		return
	if not _players.has(from_id) or not _players.has(target_id):
		return
	if kind != "cinema" or ticket.length() > 64 or not ticket.is_valid_hex_number():
		ticket = ""  # gateway tickets are hex; anything else is dropped, never relayed
	var guest: Dictionary = _players[target_id]
	if kind == "home":
		if not _granted.has(from_id):
			_granted[from_id] = {}
		_granted[from_id][target_id] = true  # an invite always opens the door, whatever the visitor setting
		if str(guest.get("location", "")) == "home" and int(guest.get("igloo", 0)) == from_id and not bool(guest.get("hidden", false)):
			return
	elif str(guest.get("location", "")) == "cinema" and not bool(guest.get("hidden", false)) and ticket == "":
		return  # already there
	var key := "%d:%d:%s" % [from_id, target_id, kind]
	var now := Time.get_ticks_msec()
	if _invite_sent.has(key) and now - int(_invite_sent[key]) < INVITE_COOLDOWN_MS:
		return
	_invite_sent[key] = now
	var host_name := str(_players[from_id]["name"])
	if target_id == local_id():
		invite_received.emit(from_id, host_name, kind, ticket)
	elif multiplayer.get_peers().has(target_id):
		deliver_invite.rpc_id(target_id, from_id, host_name, kind, ticket)


func _may_visit(guest_id: int, owner_id: int) -> bool:
	if not _players.has(owner_id):
		return false
	if _granted.get(owner_id, {}).has(guest_id):
		return true
	match str(_players[owner_id].get("visitors", "friends")):
		"anyone":
			return true
		"friends":
			return _granted.get(guest_id, {}).has(owner_id)  # they invited you before
	return false


func _host_visitors(id: int, policy: String) -> void:
	if _players.has(id) and policy in ["only_me", "friends", "anyone"]:
		_players[id]["visitors"] = policy
		_broadcast()


func _host_home(id: int, layout: String) -> void:
	if _players.has(id) and layout.length() <= HOME_MAX_BYTES:
		_homes[id] = layout


func _take_color() -> int:
	var index := _color_next
	_color_next += 1
	return index


func _pull_self() -> void:
	for entry in _roster:
		if int(entry.get("id", 0)) != local_id():
			continue
		_local_name = str(entry.get("name", _local_name))
		_local_color = int(entry.get("color", _local_color))
		return


func _clean_name(raw: String) -> String:
	var cleaned := raw.strip_edges().replace("\n", " ").replace("\t", " ")
	if cleaned == "":
		return "Penguin"
	if cleaned.length() > 16:
		cleaned = cleaned.substr(0, 16)
	return cleaned


func _force_offline() -> void:
	_closing = true
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	_players.clear()
	_roster.clear()
	_mode = Mode.OFF
	_session_open = false
	_place_location = ""
	_place_spawn = ""
	_place_hidden = true
	_place_igloo = 0
	_have_pose = false
	_latest_pose.clear()
	_have_sled = false
	_latest_sled.clear()
	_sled_race = 0
	_sled_phase = ""
	_sled_left = 0.0
	_sled_status.clear()
	_sled_notice.clear()
	_arc.clear()
	_arc_cab = ""
	_arc_solo = false
	_court_bodies.clear()
	_invite_sent.clear()
	_granted.clear()
	_homes.clear()
	_court_on = false
	if _court != null:
		_court.reset()
		_court_state = _court.view()
	_court_sig = ""
	_court_send = 0.0
	_snow_on = false
	if _snow != null:
		_snow.reset()
		_snow_state = _snow.view()
	_snow_sig = ""
	_emote_at.clear()
	_emote_seen.clear()
	_color_next = 0
	_clock_offset = 0.0
	_clock_wait = 0.0
	_closing = false


func _on_peer_connected(id: int) -> void:
	if _mode == Mode.HOST and multiplayer.get_peers().size() > 8:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	print("Net peer connected: %s" % id)


func _on_peer_disconnected(id: int) -> void:
	print("Net peer left: %s" % id)
	_voice_pos.erase(id)
	_voice_budget.erase(id)
	if _closing or _mode != Mode.HOST:
		return
	if _players.has(id):
		_players.erase(id)
		_sled_status.erase(id)
		_sled_notice.erase(id)
		_court_bodies.erase(id)
		_emote_at.erase(id)
		_homes.erase(id)
		_granted.erase(id)
		for owner in _granted:
			_granted[owner].erase(id)
		_broadcast()
		_sync_sled_members()


func _on_connected_to_server() -> void:
	if _mode != Mode.CLIENT:
		return
	print("Net joined as peer %s" % local_id())
	hello.rpc_id(1, _local_name)


func _on_connection_failed() -> void:
	if _closing or _mode != Mode.CLIENT:
		return
	_force_offline()
	connect_failed.emit("Couldn't reach a host at %s:%s." % [ADDRESS, PORT])


func _on_server_disconnected() -> void:
	if _closing or _mode != Mode.CLIENT:
		return
	print("Net host left")
	_force_offline()
	host_lost.emit()


func _on_hello_timeout() -> void:
	if _mode != Mode.CLIENT or _session_open:
		return
	_force_offline()
	connect_failed.emit("The host did not answer.")


@rpc("any_peer", "call_remote", "reliable")
func hello(player_name: String) -> void:
	if _mode != Mode.HOST:
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 0:
		return
	var cleaned := _clean_name(player_name)
	if _players.has(id):
		_players[id]["name"] = cleaned
	else:
		_players[id] = _blank(id, cleaned, _take_color())
	print("Net hello from peer %s (%s)" % [id, cleaned])
	_broadcast()


@rpc("authority", "call_remote", "reliable")
func apply_roster(snapshot: Array) -> void:
	if _mode != Mode.CLIENT:
		return
	_roster = snapshot.duplicate(true)
	_pull_self()
	if not _session_open and _roster_has_self():
		_session_open = true
		print("Net roster includes peer %s" % local_id())
		session_started.emit()
	roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func request_place(location: String, spawn: String, hidden: bool, igloo: int) -> void:
	if _mode != Mode.HOST:
		return
	_set_place(multiplayer.get_remote_sender_id(), location, spawn, hidden, igloo)


@rpc("any_peer", "call_remote", "reliable")
func request_invite(target_id: int, kind: String, ticket: String) -> void:
	if _mode != Mode.HOST:
		return
	_host_invite(multiplayer.get_remote_sender_id(), target_id, kind, ticket)


@rpc("authority", "call_remote", "reliable")
func deliver_invite(from_id: int, from_name: String, kind: String, ticket: String) -> void:
	invite_received.emit(from_id, from_name, kind, ticket)


@rpc("any_peer", "call_remote", "reliable")
func request_visitors(policy: String) -> void:
	if _mode == Mode.HOST:
		_host_visitors(multiplayer.get_remote_sender_id(), policy)


@rpc("any_peer", "call_remote", "reliable")
func submit_home(layout: String) -> void:
	if _mode == Mode.HOST:
		_host_home(multiplayer.get_remote_sender_id(), layout)


@rpc("any_peer", "call_remote", "reliable")
func request_home(owner_id: int) -> void:
	if _mode == Mode.HOST:
		send_home.rpc_id(multiplayer.get_remote_sender_id(), owner_id, str(_homes.get(owner_id, "")))


@rpc("authority", "call_remote", "reliable")
func send_home(owner_id: int, layout: String) -> void:
	home_layout.emit(owner_id, layout)


@rpc("authority", "call_remote", "reliable")
func deny_visit(owner_name: String) -> void:
	visit_denied.emit(owner_name)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_pose(x: float, y: float, z: float, yaw: float, speed: float, sitting: bool) -> void:
	if _mode != Mode.HOST:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id) or bool(_players[id]["hidden"]) or str(_players[id]["location"]) == "sled_hill":
		return
	_relay_pose(id, {
		"x": x,
		"y": y,
		"z": z,
		"yaw": yaw,
		"speed": speed,
		"sitting": sitting,
	})


@rpc("authority", "call_remote", "unreliable_ordered")
func relay_pose(from_id: int, x: float, y: float, z: float, yaw: float, speed: float, sitting: bool) -> void:
	remote_pose.emit(from_id, x, y, z, yaw, speed, sitting)


@rpc("any_peer", "call_remote", "reliable")
func request_say(message: String) -> void:
	if _mode != Mode.HOST:
		return
	_host_say(multiplayer.get_remote_sender_id(), message)


@rpc("authority", "call_remote", "reliable")
func relay_chat(speaker: String, message: String) -> void:
	chat_received.emit(speaker, message)


@rpc("any_peer", "call_remote", "reliable")
func request_sit(bench_key: String) -> void:
	if _mode != Mode.HOST:
		return
	_host_claim(multiplayer.get_remote_sender_id(), bench_key)


@rpc("any_peer", "call_remote", "reliable")
func request_fisher(phase: String) -> void:
	if _mode != Mode.HOST:
		return
	_set_fisher(multiplayer.get_remote_sender_id(), phase)


@rpc("any_peer", "call_remote", "reliable")
func request_act(act: String) -> void:
	if _mode != Mode.HOST:
		return
	_set_act(multiplayer.get_remote_sender_id(), act)


@rpc("any_peer", "call_remote", "reliable")
func request_stand() -> void:
	if _mode != Mode.HOST:
		return
	_host_release(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func reject_seat(bench_key: String) -> void:
	seat_denied.emit(bench_key)


@rpc("any_peer", "call_remote", "reliable")
func request_sled_mark(mark: String) -> void:
	if _mode != Mode.HOST:
		return
	_host_sled_mark(multiplayer.get_remote_sender_id(), mark)


@rpc("authority", "call_remote", "reliable")
func deliver_sled_gate(race_id: int, phase: String, seconds: float) -> void:
	sled_gate.emit(race_id, phase, seconds)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_sled(x: float, y: float, z: float, yaw: float, steer: float, crashed: bool) -> void:
	if _mode != Mode.HOST:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _sled_on_hill(id):
		return
	_relay_sled(id, {
		"x": x,
		"y": y,
		"z": z,
		"yaw": yaw,
		"steer": steer,
		"crashed": crashed,
	})


@rpc("authority", "call_remote", "unreliable_ordered")
func relay_sled(from_id: int, x: float, y: float, z: float, yaw: float, steer: float, crashed: bool) -> void:
	sled_pose.emit(from_id, x, y, z, yaw, steer, crashed)


func _sled_mark(mark: String) -> void:
	if not is_online() or _closing:
		return
	if _mode == Mode.HOST:
		_host_sled_mark(local_id(), mark)
	else:
		request_sled_mark.rpc_id(1, mark)


func _sled_on_hill(id: int) -> bool:
	if not _players.has(id):
		return false
	var player: Dictionary = _players[id]
	return str(player["location"]) == "sled_hill" and not bool(player["hidden"])


func _anyone_sled(state: String) -> bool:
	for id in _sled_status:
		if str(_sled_status[id]) == state and _sled_on_hill(int(id)):
			return true
	return false


func _hill_occupied() -> bool:
	for id in _players:
		if _sled_on_hill(int(id)):
			return true
	return false


func _sync_sled_members() -> void:
	if _mode != Mode.HOST:
		return
	var drop: Array = []
	for id in _sled_status:
		if not _sled_on_hill(int(id)):
			drop.append(int(id))
	for id in drop:
		_sled_status.erase(id)
		_sled_notice.erase(id)
	for id in _players:
		if _sled_on_hill(int(id)) and not _sled_status.has(int(id)):
			_sled_status[int(id)] = "ready"
			if _sled_phase == "countdown" or _sled_phase == "racing":
				_notify_sled(int(id))
	if not _hill_occupied():
		_sled_phase = ""
		_sled_left = 0.0
		_sled_notice.clear()
		return
	if _sled_phase == "racing" and not _anyone_sled("racing"):
		_sled_phase = ""
	_consider_sled_start()


func _consider_sled_start() -> void:
	if _mode != Mode.HOST or _sled_phase != "":
		return
	if not _anyone_sled("ready"):
		return
	for id in _sled_status.keys():
		if _sled_on_hill(int(id)):
			_sled_status[id] = "ready"
	_sled_race += 1
	_sled_phase = "countdown"
	_sled_left = 3.0
	_sled_notice.clear()
	_notify_sled_all()


func _tick_sled(delta: float) -> void:
	if _mode != Mode.HOST or _sled_phase != "countdown":
		return
	_sled_left = maxf(0.0, _sled_left - delta)
	if _sled_left > 0.0:
		return
	_sled_phase = "racing"
	for id in _sled_status.keys():
		if _sled_on_hill(int(id)) and str(_sled_status[id]) == "ready":
			_sled_status[id] = "racing"
	print("Net sled go %s" % _sled_race)
	_notify_sled_all()


func _host_sled_mark(id: int, mark: String) -> void:
	if _mode != Mode.HOST or not _sled_on_hill(id):
		return
	if mark == "ready":
		if _sled_phase == "countdown":
			return
		_sled_status[id] = "ready"
		if _sled_phase == "racing" and _anyone_sled("racing"):
			_notify_sled(id)
			return
		if _sled_phase == "racing":
			_sled_phase = ""
		_consider_sled_start()
	elif mark == "done":
		if str(_sled_status.get(id, "")) != "racing":
			return
		_sled_status[id] = "done"
		if not _anyone_sled("racing"):
			_sled_phase = ""
			_consider_sled_start()


func _sled_message(id: int) -> String:
	if not _sled_on_hill(id):
		return ""
	if _sled_phase == "countdown":
		return "countdown"
	if _sled_phase == "racing" and str(_sled_status.get(id, "")) == "ready":
		return "wait"
	if _sled_phase == "racing" and str(_sled_status.get(id, "")) == "racing":
		return "go"
	return ""


func _notify_sled_all() -> void:
	for id in _players:
		_notify_sled(int(id))


func _notify_sled(id: int) -> void:
	var phase := _sled_message(id)
	if phase == "":
		return
	var token := "%s|%s" % [_sled_race, phase]
	if str(_sled_notice.get(id, "")) == token:
		return
	_sled_notice[id] = token
	var seconds := _sled_left if phase == "countdown" else 0.0
	if id == local_id():
		sled_gate.emit(_sled_race, phase, seconds)
	elif multiplayer.get_peers().has(id):
		deliver_sled_gate.rpc_id(id, _sled_race, phase, seconds)


func _tick_sled_pose(delta: float) -> void:
	if not is_online() or not _have_sled:
		return
	_sled_wait -= delta
	if _sled_wait > 0.0:
		return
	_sled_wait = 0.05
	if _mode == Mode.HOST:
		_relay_sled(local_id(), _latest_sled)
	elif multiplayer.multiplayer_peer != null:
		submit_sled.rpc_id(
			1,
			float(_latest_sled["x"]),
			float(_latest_sled["y"]),
			float(_latest_sled["z"]),
			float(_latest_sled["yaw"]),
			float(_latest_sled["steer"]),
			bool(_latest_sled["crashed"])
		)


func _relay_sled(from_id: int, pose: Dictionary) -> void:
	if not _players.has(from_id) or not _sled_on_hill(from_id):
		return
	for other_id in _players:
		if int(other_id) == from_id or not _sled_on_hill(int(other_id)):
			continue
		if int(other_id) == local_id():
			sled_pose.emit(
				from_id,
				float(pose["x"]),
				float(pose["y"]),
				float(pose["z"]),
				float(pose["yaw"]),
				float(pose["steer"]),
				bool(pose["crashed"])
			)
		elif multiplayer.get_peers().has(int(other_id)):
			relay_sled.rpc_id(
				int(other_id),
				from_id,
				float(pose["x"]),
				float(pose["y"]),
				float(pose["z"]),
				float(pose["yaw"]),
				float(pose["steer"]),
				bool(pose["crashed"])
			)


func _roster_has_self() -> bool:
	for entry in _roster:
		if int(entry.get("id", 0)) == local_id():
			return true
	return false


## Puck Rally on a duo cabinet. The host steps the puck; each penguin only sends its paddle.
func arcade_watch(cabinet: String) -> void:
	_arc_cab = cabinet
	_arc_solo = false
	_arc_pad = 0.5
	if _mode == Mode.HOST:
		_arc_set_solo(local_id(), false)
	elif _mode == Mode.CLIENT:
		request_arcade_watch.rpc_id(1)


func arcade_solo() -> void:
	_arc_solo = true
	if _mode == Mode.HOST:
		_arc_set_solo(local_id(), true)
	elif _mode == Mode.CLIENT:
		request_arcade_solo.rpc_id(1)


func arcade_stop() -> void:
	if _arc_cab == "" and not _arc_solo:
		_arc_cab = ""
		return
	_arc_cab = ""
	_arc_solo = false
	if _mode == Mode.HOST:
		_arc_set_solo(local_id(), false)
		_arc_clear_player(local_id())
	elif _mode == Mode.CLIENT:
		request_arcade_stop.rpc_id(1)


func arcade_ready() -> void:
	if _arc_cab == "" or _arc_solo:
		return
	if _mode == Mode.HOST:
		_arc_mark_ready(local_id())
	elif _mode == Mode.CLIENT:
		request_arcade_ready.rpc_id(1)


func arcade_paddle(y: float) -> void:
	_arc_pad = clampf(y, 0.0, 1.0)
	if _arc_cab == "" or _arc_solo or not is_online():
		return
	if _mode == Mode.HOST:
		_arc_set_pad(local_id(), _arc_pad)
	elif _mode == Mode.CLIENT:
		request_arcade_paddle.rpc_id(1, _arc_pad)


func _tick_arcade(delta: float) -> void:
	if _mode != Mode.HOST:
		return
	var groups := {}
	for id in _players.keys():
		var bench := str(_players[id].get("bench", ""))
		var cab := _arc_cab_of(bench)
		if cab == "":
			continue
		if not groups.has(cab):
			groups[cab] = {}
		groups[cab][_arc_side_of(bench)] = int(id)
	var drop: Array = []
	for cab in _arc.keys():
		var seated: Dictionary = groups.get(cab, {})
		if seated.size() < 2 or not seated.has(0) or not seated.has(1):
			if str(_arc[cab].get("phase", "")) == "live":
				_arc_publish(str(cab), seated, "results")
			drop.append(cab)
	for cab in drop:
		_arc.erase(cab)
	for cab in groups.keys():
		var seated: Dictionary = groups[cab]
		if seated.size() < 2 or not seated.has(0) or not seated.has(1):
			continue
		_arc_play(str(cab), seated, delta)


func _arc_play(cab: String, seated: Dictionary, delta: float) -> void:
	var t := _arc_table(cab)
	var a := int(seated[0])
	var b := int(seated[1])
	var solo: Dictionary = t["solo"]
	if bool(solo.get(a, false)) or bool(solo.get(b, false)):
		return
	if str(t["phase"]) != "live":
		var ready: Dictionary = t["ready"]
		if not bool(ready.get(a, false)) or not bool(ready.get(b, false)):
			return
		var fresh := PuckBoard.new()
		fresh.start()
		t["board"] = fresh
		t["phase"] = "live"
		t["send"] = 0.0
		t["sa"] = 0
		t["sb"] = 0
		_arc_publish(cab, seated, "live")
		return
	var board: PuckBoard = t["board"]
	if board == null:
		t["phase"] = "idle"
		return
	var pads: Dictionary = t["pads"]
	board.step_with(delta, float(pads.get(a, 0.5)), float(pads.get(b, 0.5)))
	var pose := board.pose()
	var changed := int(pose["sa"]) != int(t["sa"]) or int(pose["sb"]) != int(t["sb"])
	t["sa"] = int(pose["sa"])
	t["sb"] = int(pose["sb"])
	t["send"] = float(t["send"]) - delta
	var done := not bool(pose["running"])
	if float(t["send"]) > 0.0 and not changed and not done:
		return
	t["send"] = 0.05
	_arc_publish(cab, seated, "results" if done else "live")
	if done:
		t["phase"] = "idle"
		t["ready"] = {}
		t["board"] = null


func _arc_publish(cab: String, seated: Dictionary, phase: String) -> void:
	var t: Dictionary = _arc.get(cab, {})
	var board: PuckBoard = t.get("board")
	var px := 0.5
	var py := 0.5
	var lp := 0.5
	var rp := 0.5
	var sa := int(t.get("sa", 0))
	var sb := int(t.get("sb", 0))
	if board != null:
		var pose := board.pose()
		px = float(pose["px"])
		py = float(pose["py"])
		lp = float(pose["lp"])
		rp = float(pose["rp"])
		sa = int(pose["sa"])
		sb = int(pose["sb"])
	if _arc_cab == cab and not _arc_solo:
		arcade_state.emit({
			"cab": cab, "phase": phase,
			"px": px, "py": py, "lp": lp, "rp": rp, "sa": sa, "sb": sb,
		})
	for side in seated.keys():
		var id := int(seated[side])
		if id == local_id() or not multiplayer.get_peers().has(id):
			continue
		deliver_arcade.rpc_id(id, cab, phase, px, py, lp, rp, sa, sb)


func _arc_table(cab: String) -> Dictionary:
	if cab == "":
		return {}
	if not _arc.has(cab):
		_arc[cab] = {
			"phase": "idle", "ready": {}, "pads": {}, "solo": {},
			"board": null, "send": 0.0, "sa": -1, "sb": -1,
		}
	return _arc[cab]


func _arc_bench(id: int) -> String:
	if not _players.has(id):
		return ""
	return str(_players[id].get("bench", ""))


func _arc_cab_of(bench: String) -> String:
	if bench.ends_with("_player_1"):
		return bench.trim_suffix("_player_1")
	if bench.ends_with("_player_2"):
		return bench.trim_suffix("_player_2")
	return ""


func _arc_side_of(bench: String) -> int:
	return 1 if bench.ends_with("_player_2") else 0


func _arc_set_solo(id: int, on: bool) -> void:
	var cab := _arc_cab_of(_arc_bench(id))
	if cab == "":
		return
	var t := _arc_table(cab)
	if on:
		t["solo"][id] = true
		(t["ready"] as Dictionary).erase(id)
	else:
		(t["solo"] as Dictionary).erase(id)


func _arc_clear_player(id: int) -> void:
	for cab in _arc.keys():
		var t: Dictionary = _arc[cab]
		(t["ready"] as Dictionary).erase(id)
		(t["pads"] as Dictionary).erase(id)
		(t["solo"] as Dictionary).erase(id)


func _arc_mark_ready(id: int) -> void:
	var cab := _arc_cab_of(_arc_bench(id))
	if cab == "":
		return
	var t := _arc_table(cab)
	if bool((t["solo"] as Dictionary).get(id, false)):
		return
	t["ready"][id] = true


func _arc_set_pad(id: int, y: float) -> void:
	var cab := _arc_cab_of(_arc_bench(id))
	if cab == "":
		return
	_arc_table(cab)["pads"][id] = clampf(y, 0.0, 1.0)


@rpc("any_peer", "call_remote", "reliable")
func request_arcade_watch() -> void:
	if _mode != Mode.HOST:
		return
	_arc_set_solo(multiplayer.get_remote_sender_id(), false)


@rpc("any_peer", "call_remote", "reliable")
func request_arcade_solo() -> void:
	if _mode != Mode.HOST:
		return
	_arc_set_solo(multiplayer.get_remote_sender_id(), true)


@rpc("any_peer", "call_remote", "reliable")
func request_arcade_stop() -> void:
	if _mode != Mode.HOST:
		return
	var id := multiplayer.get_remote_sender_id()
	_arc_set_solo(id, false)
	_arc_clear_player(id)


@rpc("any_peer", "call_remote", "reliable")
func request_arcade_ready() -> void:
	if _mode != Mode.HOST:
		return
	_arc_mark_ready(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func request_arcade_paddle(y: float) -> void:
	if _mode != Mode.HOST:
		return
	_arc_set_pad(multiplayer.get_remote_sender_id(), y)


@rpc("authority", "call_remote", "reliable")
func deliver_arcade(cab: String, phase: String, px: float, py: float, lp: float, rp: float, sa: int, sb: int) -> void:
	if _mode != Mode.CLIENT or _arc_solo or cab == "" or cab != _arc_cab:
		return
	arcade_state.emit({
		"cab": cab, "phase": phase,
		"px": px, "py": py, "lp": lp, "rp": rp, "sa": sa, "sb": sb,
	})


func court_view() -> Dictionary:
	if _court_state.is_empty() and _court != null:
		return _court.view()
	return _court_state


func court_carrying() -> bool:
	return str(_court_state.get("mode", "")) == "held" and int(_court_state.get("poss", -1)) == local_id()


func court_witness(id: int, at: Vector3, yaw: float, speed: float) -> void:
	if id <= 0:
		return
	_court_bodies[id] = {"x": at.x, "y": at.y, "z": at.z, "yaw": yaw, "speed": speed}


func court_here(at: Vector3) -> bool:
	return _court_on and _place_location == "town" and not _place_hidden and _inside_court(at)


func court_configure(coral: Vector3, teal: Vector3, bounds: AABB) -> void:
	_court_box = bounds
	_court_on = true
	if _court == null or _mode == Mode.CLIENT:
		return
	_court.configure_ends(coral, teal, bounds)
	_court_state = _court.view()


func court_action(action: String) -> void:
	if _closing or _court == null or not _court_on:
		return
	var mine: Dictionary = _court_bodies.get(local_id(), {})
	if mine.is_empty() or not _inside_court(Vector3(float(mine["x"]), 0.0, float(mine["z"]))):
		return
	if action == "shoot":
		action = "shoot:%.2f" % court_loft
	if _mode == Mode.CLIENT:
		request_court.rpc_id(1, action)
		return
	_court.request(local_id(), action)


func _inside_court(at: Vector3) -> bool:
	var pad := 0.45
	var origin := _court_box.position
	var size := _court_box.size
	return at.x >= origin.x - pad and at.x <= origin.x + size.x + pad \
		and at.z >= origin.z - pad and at.z <= origin.z + size.z + pad


func _tick_court(delta: float) -> void:
	if _court == null or not _court_on or _mode == Mode.CLIENT:
		return
	var present: Array = []
	if _place_location == "town" and not _place_hidden:
		var mine: Dictionary = _court_bodies.get(local_id(), {})
		if not mine.is_empty() and _inside_court(Vector3(float(mine["x"]), 0.0, float(mine["z"]))):
			present.append(local_id())
	for id in _players:
		var player: Dictionary = _players[id]
		if str(player["location"]) != "town" or bool(player["hidden"]):
			continue
		var body: Dictionary = _court_bodies.get(int(id), {})
		if body.is_empty() or not _inside_court(Vector3(float(body["x"]), 0.0, float(body["z"]))):
			continue
		if not present.has(int(id)):
			present.append(int(id))
	if present.is_empty():
		var busy := str(_court.phase) != "practice" or int(_court.coral_score) != 0 or int(_court.teal_score) != 0 \
			or str(_court.ball_mode) != "loose"
		if busy:
			_court.reset()
			_publish_court(delta)
		return
	_court.tick(delta, present, _court_bodies)
	_publish_court(delta)


func _publish_court(delta: float) -> void:
	_court_state = _court.view()
	if _mode != Mode.HOST or multiplayer.multiplayer_peer == null:
		return
	var sig := "%s|%s|%s|%s|%s|%s" % [
		str(_court_state["phase"]),
		str(_court_state["coral"]),
		str(_court_state["teal"]),
		str(_court_state["poss"]),
		str(_court_state["mode"]),
		str(_court_state["text"]),
	]
	_court_send -= delta
	if sig == _court_sig and _court_send > 0.0:
		return
	_court_sig = sig
	_court_send = 0.05
	if multiplayer.get_peers().size() > 0:
		deliver_court.rpc(_court_state)


@rpc("any_peer", "call_remote", "reliable")
func request_court(action: String) -> void:
	if _mode != Mode.HOST or _court == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id):
		return
	if str(_players[id]["location"]) != "town" or bool(_players[id]["hidden"]):
		return
	var body: Dictionary = _court_bodies.get(id, {})
	if body.is_empty() or not _inside_court(Vector3(float(body["x"]), 0.0, float(body["z"]))):
		return
	_court.request(id, action)


@rpc("authority", "call_remote", "reliable")
func deliver_court(state: Dictionary) -> void:
	if _mode != Mode.CLIENT:
		return
	_court_state = state


func use_websocket() -> bool:
	return OS.has_feature("web") or OS.get_cmdline_user_args().has("--net-ws") or not OS.get_environment("PENGLOO_WS_URL").is_empty()

func websocket_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/multiplayer'"))
	var configured := OS.get_environment("PENGLOO_WS_URL")
	return configured if not configured.is_empty() else "ws://127.0.0.1:%s" % PORT


# ---- emotes ----------------------------------------------------------------------------
## The local player started an emote: everyone in the same room plays it on this penguin's puppet.
## Moving cancels it everywhere because puppets drop their overlay clip once they move.
func note_emote(clip: String) -> void:
	if not is_online() or _closing:
		return
	if _mode == Mode.HOST:
		_host_emote(local_id(), clip)
	else:
		request_emote.rpc_id(1, clip)


func _host_emote(id: int, clip: String) -> void:
	if _mode != Mode.HOST or not _players.has(id) or bool(_players[id]["hidden"]):
		return
	if clip.length() > 40 or not clip.replace("/", "_").is_valid_identifier():
		return
	var now := Time.get_ticks_msec()
	if _emote_at.has(id) and now - int(_emote_at[id]) < EMOTE_GAP_MS:
		return  # rate limit: about one emote per 0.8 s per player
	_emote_at[id] = now
	var start := now / 1000.0
	for other_id in _players:
		if int(other_id) == id or bool(_players[other_id]["hidden"]) or not _same_room(_players[id], _players[other_id]):
			continue
		if int(other_id) == local_id():
			emote_played.emit(id, clip)
		elif multiplayer.get_peers().has(int(other_id)):
			deliver_emote.rpc_id(int(other_id), id, clip, start)


@rpc("any_peer", "call_remote", "reliable")
func request_emote(clip: String) -> void:
	if _mode == Mode.HOST:
		_host_emote(multiplayer.get_remote_sender_id(), clip)


## start is the host's clock when it accepted the emote; a stale or repeated delivery is ignored.
## shortcut: no host clock sync, so a late joiner never sees an emote already under way.
@rpc("authority", "call_remote", "reliable")
func deliver_emote(peer_id: int, clip: String, start: float) -> void:
	if _mode != Mode.CLIENT or float(_emote_seen.get(peer_id, -1.0)) >= start:
		return
	_emote_seen[peer_id] = start
	emote_played.emit(peer_id, clip)


# ---- snowball fight (scripts/snow_match.gd, scripts/town_snowball.gd) --------------------
func snow_view() -> Dictionary:
	if _snow_state.is_empty() and _snow != null:
		return _snow.view()
	return _snow_state


func snow_configure(field: Rect2, floor_y: float, pads: Dictionary, spawns: Dictionary, cover: Array) -> void:
	_snow_area = field
	_snow_on = true
	if _snow == null or _mode == Mode.CLIENT:
		return
	_snow.configure(field, floor_y, pads, spawns, cover)
	_snow_state = _snow.view()


## True while at the arena (field plus the waiting strip around it).
func snow_here(at: Vector3) -> bool:
	return _snow_on and _place_location == "town" and not _place_hidden and _snow_area.grow(SNOW_REACH).has_point(Vector2(at.x, at.z))


## The local player's team in the running match, or "".
func snow_team() -> String:
	return str((snow_view().get("teams", {}) as Dictionary).get(local_id(), ""))


func snow_throw(target: Vector3) -> void:
	if _closing or _snow == null or not _snow_on:
		return
	if _mode == Mode.CLIENT:
		request_snow_throw.rpc_id(1, target.x, target.z)
		return
	_snow.throw(local_id(), Vector2(target.x, target.z), _court_bodies)
	_publish_snow(0.0)


func _tick_snow(delta: float) -> void:
	if _snow == null or not _snow_on or _mode == Mode.CLIENT:
		return
	var present: Array = []
	var reach := _snow_area.grow(SNOW_REACH)
	if _place_location == "town" and not _place_hidden and _court_bodies.has(local_id()):
		var mine: Dictionary = _court_bodies[local_id()]
		if reach.has_point(Vector2(float(mine["x"]), float(mine["z"]))):
			present.append(local_id())
	for id in _players:
		var player: Dictionary = _players[id]
		if int(id) == local_id() or str(player["location"]) != "town" or bool(player["hidden"]):
			continue
		var body: Dictionary = _court_bodies.get(int(id), {})
		if not body.is_empty() and reach.has_point(Vector2(float(body["x"]), float(body["z"]))):
			present.append(int(id))
	if present.is_empty() and str(_snow.phase) == "lobby":
		return
	_snow.tick(delta, present, _court_bodies)
	_publish_snow(delta)


func _publish_snow(delta: float) -> void:
	_snow_state = _snow.view()
	if _mode != Mode.HOST or multiplayer.multiplayer_peer == null:
		return
	var events: Array = _snow_state["events"]
	var sig := "%s|%d|%d|%d|%s|%s|%s" % [_snow_state["phase"], int(_snow_state["coral"]), int(_snow_state["teal"]),
		int(events[-1]["n"]) if not events.is_empty() else 0, str(_snow_state["ready"]), str(_snow_state["lives"]), _snow_state["text"]]
	_snow_send -= delta
	if sig == _snow_sig and _snow_send > 0.0:
		return
	_snow_sig = sig
	_snow_send = 0.5  # the clock ticks locally between publishes
	if multiplayer.get_peers().size() > 0:
		deliver_snow.rpc(_snow_state)


func snow_leave() -> void:
	if _closing or _snow == null or not _snow_on:
		return
	if _mode == Mode.CLIENT:
		request_snow_leave.rpc_id(1)
		return
	_snow.leave(local_id())
	_publish_snow(0.0)


@rpc("any_peer", "call_remote", "reliable")
func request_snow_leave() -> void:
	if _mode == Mode.HOST and _snow != null and _players.has(multiplayer.get_remote_sender_id()):
		_snow.leave(multiplayer.get_remote_sender_id())
		_publish_snow(0.0)


@rpc("any_peer", "call_remote", "reliable")
func request_snow_throw(x: float, z: float) -> void:
	if _mode != Mode.HOST or _snow == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id) or str(_players[id]["location"]) != "town" or bool(_players[id]["hidden"]):
		return
	if _snow.throw(id, Vector2(x, z), _court_bodies):
		_publish_snow(0.0)


@rpc("authority", "call_remote", "reliable")
func deliver_snow(state: Dictionary) -> void:
	if _mode != Mode.CLIENT:
		return
	_snow_state = state
