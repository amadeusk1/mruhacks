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
signal home_invite(from_id: int, from_name: String)
signal sled_gate(race_id: int, phase: String, seconds: float)
signal sled_pose(peer_id: int, x: float, y: float, z: float, yaw: float, steer: float, crashed: bool)

const PORT := 7777
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


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _closing:
		return
	_tick_sled(delta)
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
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(connection_port(), 8)
	if err != OK:
		return "Port %s is already in use." % connection_port()
	_mode = Mode.HOST
	multiplayer.multiplayer_peer = peer
	_local_name = _clean_name(player_name)
	_local_color = _take_color() if preferred_color < 0 else preferred_color
	_place_hidden = true
	_players[local_id()] = _blank(local_id(), _local_name, _local_color)
	_session_open = true
	print("Net hosting on %s:%s as peer %s (%s)" % [ADDRESS, connection_port(), local_id(), _local_name])
	_broadcast()
	session_started.emit()
	return ""


func join_game(player_name: String) -> String:
	if _mode != Mode.OFF:
		return "Already in a session."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ADDRESS, connection_port())
	if err != OK:
		return "Couldn't open a connection to %s:%s." % [ADDRESS, connection_port()]
	_mode = Mode.CLIENT
	_local_name = _clean_name(player_name)
	_place_hidden = true
	multiplayer.multiplayer_peer = peer
	print("Net joining %s:%s as %s" % [ADDRESS, connection_port(), _local_name])
	get_tree().create_timer(6.0).timeout.connect(_on_hello_timeout, CONNECT_ONE_SHOT)
	return ""


func shutdown() -> void:
	_force_offline()


func hide_presence() -> void:
	if not is_online():
		return
	_send_place(_place_location, _place_spawn, true, _place_igloo)


func arrive(location: String, spawn: String, hidden: bool, igloo: int = 0) -> void:
	if not is_online():
		return
	_send_place(location, spawn, hidden, igloo)


func invite_home(target_id: int) -> void:
	if not is_online() or _closing or target_id <= 0 or target_id == local_id():
		return
	if _mode == Mode.HOST:
		_host_invite(local_id(), target_id)
	else:
		request_invite.rpc_id(1, target_id)


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
	var player: Dictionary = _players[id]
	var changed := str(player["location"]) != location or bool(player["hidden"]) != hidden or int(player.get("igloo", 0)) != igloo
	player["location"] = location
	player["spawn"] = spawn
	player["hidden"] = hidden
	player["igloo"] = igloo
	if hidden or changed:
		player["bench"] = ""
		player["fisher"] = ""
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
	var sender: Dictionary = _players[from_id]
	if bool(sender["hidden"]) or str(sender["location"]) == "" or str(sender["location"]) == "sled_hill":
		return
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


func _host_invite(from_id: int, target_id: int) -> void:
	if from_id <= 0 or target_id <= 0 or from_id == target_id:
		return
	if not _players.has(from_id) or not _players.has(target_id):
		return
	var guest: Dictionary = _players[target_id]
	if str(guest.get("location", "")) == "home" and int(guest.get("igloo", 0)) == from_id and not bool(guest.get("hidden", false)):
		return
	var host_name := str(_players[from_id]["name"])
	if target_id == local_id():
		home_invite.emit(from_id, host_name)
	elif multiplayer.get_peers().has(target_id):
		deliver_invite.rpc_id(target_id, from_id, host_name)


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
	_color_next = 0
	_closing = false


func _on_peer_connected(id: int) -> void:
	print("Net peer connected: %s" % id)


func _on_peer_disconnected(id: int) -> void:
	print("Net peer left: %s" % id)
	if _closing or _mode != Mode.HOST:
		return
	if _players.has(id):
		_players.erase(id)
		_sled_status.erase(id)
		_sled_notice.erase(id)
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
	connect_failed.emit("Couldn't reach a host at %s:%s." % [ADDRESS, connection_port()])


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
func request_invite(target_id: int) -> void:
	if _mode != Mode.HOST:
		return
	_host_invite(multiplayer.get_remote_sender_id(), target_id)


@rpc("authority", "call_remote", "reliable")
func deliver_invite(from_id: int, from_name: String) -> void:
	home_invite.emit(from_id, from_name)


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


func connection_port() -> int:
	var configured := OS.get_environment("PENGLOO_PORT")
	var port := configured.to_int()
	return port if port >= 1024 and port <= 65535 else PORT
