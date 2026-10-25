extends Node3D

## Owns the local penguin, camera, and room swaps.
## Remote penguins live under Players and only appear in the current place.

const PENGUIN := preload("res://scenes/penguin.tscn")

@onready var _host: Node3D = $LocationHost
@onready var _penguin = $Penguin
@onready var _players: Node3D = $Players
@onready var _menu = $BusMenu
@onready var _lobby = $Lobby
@onready var _hud = $PlayHud
@onready var _camera_rig: Node3D = $CameraRig
@onready var _world_camera: Camera3D = $CameraRig/Camera3D

var _current_id := ""
var _igloo_id := 0
var _traveling := false
var _activity := false
var _in_game := false
var _epoch := 0
var _penguin_layer := 0
var _penguin_mask := 0
var _puppets: Dictionary = {}
var _poses: Dictionary = {}
var _place_sig: Dictionary = {}
var _rows: VBoxContainer
var _invite_card: UIModal


func _ready() -> void:
	add_to_group("world")
	_menu.destination_chosen.connect(_on_destination_chosen)
	_menu.dismissed.connect(_on_menu_dismissed)
	_penguin.set_travel_locked(true)
	_penguin.visible = false
	_penguin.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.set_play_visible(false)
	_build_presence()
	_lobby.host_requested.connect(_on_host_pressed)
	_lobby.join_requested.connect(_on_join_pressed)
	_lobby.solo_requested.connect(_on_solo_pressed)
	Net.session_started.connect(_on_session_started)
	Net.roster_changed.connect(_on_roster_changed)
	Net.remote_pose.connect(_on_remote_pose)
	Net.seat_denied.connect(_on_seat_denied)
	Net.connect_failed.connect(_on_connect_failed)
	Net.host_lost.connect(_on_host_lost)
	Net.chat_received.connect(_on_chat)
	Net.emote_played.connect(_on_emote)
	Net.invite_received.connect(_on_invite)
	Net.visit_denied.connect(_on_visit_denied)
	var arcade := preload("res://scripts/arcade_session.gd").new()
	arcade.name = "ArcadeSession"
	add_child(arcade)
	var casino := preload("res://scripts/casino/casino_session.gd").new()
	casino.name = "CasinoSession"
	add_child(casino)
	_apply_launch_args()


func current_location_id() -> String:
	return _current_id


func home_owner_id() -> int:
	return _igloo_id


func is_bus_menu_open() -> bool:
	return _menu.visible


func open_bus_menu() -> void:
	if _traveling or _current_id == "" or not _in_game:
		return
	var here := _current_id
	if _current_id == "home" and _igloo_id != Net.local_id():
		here = ""
	_menu.open_for(here, _describe_place(_current_id, false, _igloo_id, Net.local_id()))
	_penguin.set_travel_locked(true)


func close_bus_menu() -> void:
	_menu.dismiss()
	if not _traveling and _in_game:
		_penguin.set_travel_locked(false)


func is_traveling() -> bool:
	return _traveling


func travel_to(location_id: String, spawn_name: String = "BusArrival", igloo_id: int = -1) -> void:
	var igloo := 0
	if location_id == "home":
		igloo = Net.local_id() if igloo_id < 0 else igloo_id
	if not _in_game or _traveling or (location_id == _current_id and igloo == _igloo_id):
		return
	if not LocationCatalog.has_location(location_id):
		return
	var path := LocationCatalog.scene_path(location_id)
	if not ResourceLoader.exists(path):
		push_error("Missing location scene: %s" % path)
		if location_id != "plaza":
			await travel_to("plaza")
		return
	var epoch := _epoch
	_traveling = true
	_menu.dismiss()
	_penguin.set_travel_locked(true)
	_penguin.halt()
	_despawn_all()
	if _current_id != "":
		Net.hide_presence()
	_clear_room()
	var packed := load(path) as PackedScene
	var room := packed.instantiate()
	_current_id = location_id
	_igloo_id = igloo  # before add_child: the room's _ready asks whose home it is
	_host.add_child(room)
	if epoch != _epoch:
		_traveling = false
		return
	if room.is_in_group("activity"):
		_enter_activity()
		Net.arrive(location_id, "", false, 0)
		_traveling = false
		_sync_puppets()
		_refresh_presence()
		return
	_leave_activity()
	await get_tree().physics_frame
	if epoch != _epoch:
		_traveling = false
		return
	_place_penguin(room, spawn_name)
	await get_tree().physics_frame
	if epoch != _epoch:
		_traveling = false
		return
	_penguin.set_travel_locked(false)
	Net.arrive(location_id, spawn_name, false, _igloo_id)
	_traveling = false
	_sync_puppets()
	_refresh_presence()


## Stand outside the player's snow dome on the town island.
func go_to_homes() -> void:
	if _current_id == LocationCatalog.MAIN:
		shift_to_marker("Home2DoorOut")
	else:
		travel_to(LocationCatalog.MAIN, "Home2DoorOut")


## Door trip inside the current room. The landing marker is outside the door volume.
func shift_to_marker(marker_name: String) -> void:
	if not _in_game or _traveling or _activity or _host.get_child_count() == 0:
		return
	var room := _host.get_child(0)
	var marker := room.get_node_or_null(marker_name) as Node3D
	if marker == null:
		push_error("Missing spawn marker: %s" % marker_name)
		return
	var epoch := _epoch
	_traveling = true
	_penguin.set_travel_locked(true)
	_penguin.halt()
	_penguin.global_position = _ground_at(marker.global_position)
	_penguin.rotation.y = marker.rotation.y
	_penguin.velocity = Vector3.ZERO
	_penguin.halt()
	_apply_camera(room, marker_name)
	await get_tree().physics_frame
	if epoch != _epoch:
		_traveling = false
		return
	await get_tree().create_timer(0.35).timeout
	if epoch != _epoch:
		_traveling = false
		return
	if not _menu.visible:
		_penguin.set_travel_locked(false)
	_traveling = false
	_sync_puppets()


## Floor under a spawn marker: raycast down from 2 m above it onto walkable floor (layer 1),
## so arrivals on raised floors (cinema tiers, hills, docks) don't sink. Falls back to the
## marker's own height when there is no floor under it.
func _ground_at(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var y: float = (hit.position.y if not hit.is_empty() else at.y) + 0.05
	return Vector3(at.x, y, at.z)


func _place_penguin(room: Node, spawn_name: String) -> void:
	var arrival := room.get_node(spawn_name) as Node3D
	var extra := 0.0
	if spawn_name == "BusArrival" and Net.is_online():
		extra = float(posmod(Net.local_id(), 4)) * 0.65
	_penguin.global_position = _ground_at(arrival.global_position + Vector3(extra, 0.0, 0.0))
	_penguin.velocity = Vector3.ZERO
	_penguin.process_mode = Node.PROCESS_MODE_INHERIT
	_penguin.visible = true
	_hud.set_play_visible(true)
	_penguin.rotation.y = arrival.rotation.y
	_penguin.halt()
	_apply_camera(room, spawn_name)


func _apply_camera(room: Node, spawn_name: String) -> void:
	if room.has_method("camera_for_spawn"):
		var frame: Dictionary = room.call("camera_for_spawn", spawn_name)
		_camera_rig.call(
			"set_frame",
			frame["center"],
			float(frame["limit_x"]),
			float(frame["limit_z"]),
			float(frame.get("height", -1.0)),
			float(frame.get("distance", -1.0))
		)
		# a room may turn the view to its concept's three-quarter angle (the walls on that side are cut away)
		_camera_rig.rotation.y = deg_to_rad(float(frame.get("yaw_deg", 0.0)))
	else:
		_camera_rig.call("set_frame", Vector3.ZERO, 7.5, 5.0)
		_camera_rig.rotation.y = 0.0


func _enter_activity() -> void:
	_activity = true
	_penguin_layer = _penguin.collision_layer
	_penguin_mask = _penguin.collision_mask
	_penguin.collision_layer = 0
	_penguin.collision_mask = 0
	_penguin.visible = false
	_penguin.process_mode = Node.PROCESS_MODE_DISABLED
	_penguin.global_position = Vector3(0.0, -40.0, 0.0)
	_hud.set_play_visible(false)
	_camera_rig.set_process(false)
	_world_camera.current = false


func _leave_activity() -> void:
	if not _activity:
		return
	_activity = false
	_penguin.collision_layer = _penguin_layer
	_penguin.collision_mask = _penguin_mask
	_penguin.visible = true
	_camera_rig.set_process(true)
	_world_camera.current = true


func _clear_room() -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		child.free()


func _on_destination_chosen(location_id: String) -> void:
	travel_to(location_id)


func _on_menu_dismissed() -> void:
	if _traveling or not _in_game:
		return
	_penguin.set_travel_locked(false)


func _on_host_pressed() -> void:
	_lobby.set_busy(true)
	_lobby.set_status("Opening 127.0.0.1:7777…")
	var error := Net.host_game(_lobby.player_name())
	if error != "":
		_lobby.set_busy(false)
		_lobby.set_status(error)


func _on_join_pressed() -> void:
	_lobby.set_busy(true)
	_lobby.set_status("Joining Pengloo Party…" if Net.public_client() else "Connecting to 127.0.0.1:7777…")
	var error := Net.join_game(_lobby.player_name())
	if error != "":
		_lobby.set_busy(false)
		_lobby.set_status(error)


func _on_solo_pressed() -> void:
	_lobby.set_busy(true)
	Net.play_solo(_lobby.player_name())


func _on_connect_failed(message: String) -> void:
	if _in_game:
		return
	_lobby.set_busy(false)
	_lobby.set_status(message)


func _on_session_started() -> void:
	if _in_game:
		return
	_in_game = true
	_lobby.hide_lobby()
	var profile := Net.local_profile()
	_penguin.apply_identity(str(profile["name"]), int(profile["color"]))
	DisplayServer.window_set_title("%s — %s" % [Net.role_label(), str(profile["name"])])
	_share_home()
	await travel_to(LocationCatalog.MAIN, "BusArrival")
	if OS.get_cmdline_user_args().has("--dedicated"):
		Net.hide_presence()
		_penguin.visible = false
		_penguin.process_mode = Node.PROCESS_MODE_DISABLED
	_refresh_presence()
	if OS.has_feature("web") and OS.is_debug_build():  # probe-only: release exports never teleport
		_goto_from_url()


## Probe hook (debug web exports only, headless Chrome): ?goto=location:Marker puts the penguin on that marker after joining.
func _goto_from_url() -> void:
	var trip := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('goto') || ''")).split(":")
	if trip.size() != 2:
		return
	if trip[0] != _current_id:
		await travel_to(trip[0], trip[1])
		return
	var marker := _host.find_child(trip[1], true, false) as Node3D
	if marker:
		_penguin.global_position = _ground_at(marker.global_position)
		_penguin.halt()


func _on_host_lost() -> void:
	_end_session("The host left. Host a new game or join again.")


func _end_session(message: String) -> void:
	Music.play_title()
	_epoch += 1
	_in_game = false
	_traveling = false
	Net.shutdown()
	_leave_activity()
	_menu.dismiss()
	_clear_room()
	_current_id = ""
	_igloo_id = 0
	if is_instance_valid(_invite_card):
		_invite_card.close()
	_despawn_all()
	_penguin.set_travel_locked(true)
	_penguin.visible = false
	_penguin.process_mode = Node.PROCESS_MODE_DISABLED
	_camera_rig.set_process(true)
	_world_camera.current = true
	_clear_presence()
	_hud.set_play_visible(false)
	_lobby.show_lobby(message)


func grant_coins(amount: int) -> void:
	_hud.add_coins(amount)


func send_chat(message: String) -> void:
	var text := message.strip_edges()
	if text == "":
		return
	if text.length() > 80:
		text = text.substr(0, 80)
	if Net.is_online():
		Net.say(text)
	else:
		var speaker := str(Net.local_profile()["name"]) if _in_game else "You"
		_hud.add_line(speaker, text)


func _on_chat(speaker: String, message: String) -> void:
	_hud.add_line(speaker, message)


func _on_roster_changed() -> void:
	if _in_game:
		var profile := Net.local_profile()
		_penguin.apply_identity(str(profile["name"]), int(profile["color"]))
	_sync_puppets()
	_refresh_presence()
	if _in_game and _current_id == "home" and Net.is_online() and _igloo_id != Net.local_id() and not _traveling \
			and not Net.roster().any(func(e): return int(e.get("id", 0)) == _igloo_id):
		UIWidgets.toast(self, "Your host left, so you're back in town.", "home", 3.5)
		travel_to(LocationCatalog.MAIN, "BusArrival")


func _on_remote_pose(peer_id: int, x: float, y: float, z: float, yaw: float, speed: float, sitting: bool) -> void:
	_poses[peer_id] = {
		"at": Vector3(x, y, z),
		"yaw": yaw,
		"speed": speed,
		"sitting": sitting,
	}
	var puppet: Node = _puppets.get(peer_id)
	if puppet == null or not is_instance_valid(puppet):
		return
	puppet.present_remote(Vector3(x, y, z), yaw, speed, sitting)
	puppet.visible = true


func _on_emote(peer_id: int, clip: String) -> void:
	var puppet: Node = _puppets.get(peer_id)
	if puppet != null and is_instance_valid(puppet) and puppet.has_method("play_emote"):
		puppet.play_emote(clip)


func _on_seat_denied(key: String) -> void:
	if not _penguin.is_sitting():
		return
	var bench: Object = _penguin.current_bench()
	if bench != null and is_instance_valid(bench) and bench.has_method("bench_key"):
		if str(bench.call("bench_key")) != key:
			return
	_penguin.stand_up()


func _sync_puppets() -> void:
	if not _in_game or _traveling or _activity:
		if _activity and not _puppets.is_empty():
			_despawn_all()
		return
	var live: Dictionary = {}
	for entry in Net.roster():
		var id := int(entry.get("id", 0))
		live[id] = true
		if id == Net.local_id():
			continue
		var hidden := bool(entry.get("hidden", false))
		var location := str(entry.get("location", ""))
		var igloo := int(entry.get("igloo", 0))
		var sig := "%s|%s|%s" % [location, hidden, igloo]
		if str(_place_sig.get(id, "")) != sig:
			_place_sig[id] = sig
			_poses.erase(id)
			_despawn_puppet(id)
		if not _shares_room(location, hidden, igloo):
			_despawn_puppet(id)
			continue
		_ensure_puppet(entry)
	var stale: Array = []
	for id in _puppets.keys():
		if not live.has(int(id)):
			stale.append(int(id))
	for id in stale:
		_despawn_puppet(id)
		_place_sig.erase(id)
		_poses.erase(id)


func _ensure_puppet(entry: Dictionary) -> void:
	var id := int(entry.get("id", 0))
	var puppet: Node = _puppets.get(id)
	if puppet == null or not is_instance_valid(puppet):
		puppet = PENGUIN.instantiate()
		puppet.set_meta("remote_peer", id)
		_players.add_child(puppet)
		_puppets[id] = puppet
		puppet.visible = false
		print("Net avatar %s (%s) entered %s" % [str(entry.get("name", "")), id, str(entry.get("location", ""))])
	puppet.apply_identity(str(entry.get("name", "Penguin")), int(entry.get("color", 0)))
	if puppet.has_method("apply_fisher"):
		puppet.apply_fisher(str(entry.get("fisher", "")))
	if puppet.has_method("apply_act"):
		puppet.apply_act(str(entry.get("act", "")))
	if puppet.has_method("apply_anim"):
		puppet.apply_anim(str(entry.get("anim", "")), bool(entry.get("anim_loop", false)),
			float(entry.get("anim_age", 0.0)), int(entry.get("anim_n", 0)))
	if _poses.has(id):
		var pose: Dictionary = _poses[id]
		puppet.present_remote(pose["at"], float(pose["yaw"]), float(pose["speed"]), bool(pose["sitting"]))
		puppet.visible = true


func _despawn_puppet(id: int) -> void:
	if not _puppets.has(id):
		return
	var node: Node = _puppets[id]
	_puppets.erase(id)
	if is_instance_valid(node):
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.queue_free()


func _despawn_all() -> void:
	for id in _puppets.keys():
		_despawn_puppet(int(id))
	_puppets.clear()
	_poses.clear()
	_place_sig.clear()


func _shares_room(location: String, hidden: bool, igloo: int) -> bool:
	if hidden or location == "" or location != _current_id or location == "sled_hill":
		return false
	if location == "home" and igloo != _igloo_id:
		return false
	return true


func _refresh_presence() -> void:
	# No corner roster: players shouldn't see where everyone is. Invites live in Friends -> player card.
	if _rows != null:
		_clear_presence()


func _in_their_igloo(entry: Dictionary) -> bool:
	return str(entry.get("location", "")) == "home" and int(entry.get("igloo", 0)) == Net.local_id() and not bool(entry.get("hidden", false))


func _place_label(entry: Dictionary) -> String:
	return _describe_place(
		str(entry.get("location", "")),
		bool(entry.get("hidden", false)),
		int(entry.get("igloo", 0)),
		int(entry.get("id", 0))
	)


func _describe_place(location: String, hidden: bool, igloo: int, who: int) -> String:
	if location == "":
		return "Arriving"
	if hidden and location != "sled_hill":
		return "Traveling"
	if location == "home":
		if igloo == 0 or igloo == who:
			return "Home"
		return "%s's igloo" % _player_name(igloo)
	if LocationCatalog.has_location(location):
		return LocationCatalog.title_of(location)
	return location


func _player_name(peer_id: int) -> String:
	for entry in Net.roster():
		if int(entry.get("id", 0)) == peer_id:
			return str(entry.get("name", "Penguin"))
	if peer_id == Net.local_id():
		return str(Net.local_profile()["name"])
	return "Penguin"


func _presence_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.08, 0.16, 0.24))
	label.add_theme_color_override("font_outline_color", Color(0.98, 0.96, 0.92))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _clear_presence() -> void:
	if _rows == null:
		return
	while _rows.get_child_count() > 0:
		var child := _rows.get_child(0)
		_rows.remove_child(child)
		child.queue_free()


## Visitor setting and saved furniture go to the server so visits show the owner's home.
func _share_home() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://home_choice.cfg")
	Net.set_visitors(str(cfg.get_value("home", "visitors", "friends")))
	var path := DecorEditor.path_for("homes/snow_dome_interior")
	if FileAccess.file_exists(path):
		Net.publish_home(FileAccess.get_file_as_string(path))


func _on_invite(from_id: int, from_name: String, kind: String, ticket: String) -> void:
	if not _in_game or from_id == Net.local_id():
		return
	if is_instance_valid(_invite_card):
		_invite_card.close()  # the newest invite replaces an open one
	var color := 0
	for e in Net.roster():
		if int(e.get("id", 0)) == from_id:
			color = int(e.get("color", 0))
	_invite_card = InviteCard.make(from_name, Net.coat_color(color), kind,
		func() -> void: _accept_invite(from_id, kind, ticket)).open()


func _accept_invite(from_id: int, kind: String, ticket: String) -> void:
	while _traveling:
		await get_tree().process_frame
	if not _in_game:
		return
	UIRouter.close_all()
	if kind == "home":
		if not Net.roster().any(func(e): return int(e.get("id", 0)) == from_id):
			UIWidgets.toast(self, "They left before you could visit.", "home")
			return
		travel_to("home", "InsideSpawn", from_id)
		return
	if ticket != "" and not CinemaService.client.signed_in:
		# the inviter's single-use view ticket: watch their screen without the sign-in step
		var done := [false]
		CinemaService.client.redeem_ticket(ticket, func(ok: bool, _err: String) -> void:
			done[0] = true
			if ok:
				CinemaService.signed_in_changed.emit(true))
		var waited := 0.0
		while not done[0] and waited < 6.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
	travel_to("cinema", "InsideScreen")


func _on_visit_denied(owner_name: String) -> void:
	UIWidgets.toast(self, "%s's home is invite-only." % (owner_name if owner_name != "" else "That"), "home", 3.5)
	if _current_id == "home" and _igloo_id != Net.local_id():
		travel_to(LocationCatalog.MAIN, "BusArrival")


func _build_presence() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(18, 14)
	_rows.add_theme_constant_override("separation", 6)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_rows)


func _apply_launch_args() -> void:
	var host := false
	var join := false
	var solo := false
	var named := ""
	var seconds := 0
	for arg in OS.get_cmdline_user_args():
		if arg == "--net-host":
			host = true
		elif arg == "--net-join":
			join = true
		elif arg == "--net-solo":
			solo = true
		elif arg.begins_with("--net-name="):
			named = arg.trim_prefix("--net-name=")
		elif arg.begins_with("--net-seconds="):
			seconds = int(arg.trim_prefix("--net-seconds="))
	if named != "":
		_lobby.set_name_text(named)
	if seconds > 0:
		_quit_after(seconds)
	if host:
		call_deferred("_on_host_pressed")
	elif join:
		call_deferred("_on_join_pressed")
	elif solo:
		call_deferred("_on_solo_pressed")


func _quit_after(seconds: int) -> void:
	await get_tree().create_timer(seconds).timeout
	get_tree().quit()
