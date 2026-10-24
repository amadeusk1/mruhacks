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
var _invite: PanelContainer
var _invite_text: Label
var _invite_from := 0


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
	Net.home_invite.connect(_on_home_invite)
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
	_host.add_child(room)
	_current_id = location_id
	_igloo_id = igloo
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
	_refresh_stop(room)
	_penguin.set_travel_locked(false)
	Net.arrive(location_id, spawn_name, false, _igloo_id)
	_traveling = false
	_sync_puppets()
	_refresh_presence()


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
	_penguin.global_position = Vector3(marker.global_position.x, 0.2, marker.global_position.z)
	_penguin.rotation.y = marker.rotation.y
	_penguin.velocity = Vector3.ZERO
	_penguin.halt()
	_apply_camera(room, marker_name)
	await get_tree().physics_frame
	if epoch != _epoch:
		_traveling = false
		return
	_refresh_stop(room)
	await get_tree().create_timer(0.35).timeout
	if epoch != _epoch:
		_traveling = false
		return
	if not _menu.visible:
		_penguin.set_travel_locked(false)
	_traveling = false
	_sync_puppets()


func _place_penguin(room: Node, spawn_name: String) -> void:
	var arrival := room.get_node(spawn_name) as Node3D
	var stop := room.get_node_or_null("NavigationRegion3D/BusStop") as Node3D  # interiors have no stop
	var extra := 0.0
	if spawn_name == "BusArrival" and Net.is_online():
		extra = float(posmod(Net.local_id(), 4)) * 0.65
	_penguin.global_position = Vector3(arrival.global_position.x + extra, 0.2, arrival.global_position.z)
	_penguin.velocity = Vector3.ZERO
	_penguin.process_mode = Node.PROCESS_MODE_INHERIT
	_penguin.visible = true
	_hud.set_play_visible(true)
	if spawn_name == "BusArrival" and stop != null:
		_penguin.face_point(stop.global_position)
	else:
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
	else:
		_camera_rig.call("set_frame", Vector3.ZERO, 7.5, 5.0)


func _refresh_stop(room: Node) -> void:
	var stop := room.get_node_or_null("NavigationRegion3D/BusStop")
	if stop != null and stop.has_method("refresh_occupancy"):
		stop.call("refresh_occupancy")


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
	_lobby.set_status("Connecting to 127.0.0.1:7777…")
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
	await travel_to(LocationCatalog.MAIN, "BusArrival")
	_refresh_presence()


func _on_host_lost() -> void:
	_end_session("The host left. Host a new game or join again.")


func _end_session(message: String) -> void:
	_epoch += 1
	_in_game = false
	_traveling = false
	Net.shutdown()
	_leave_activity()
	_menu.dismiss()
	_clear_room()
	_current_id = ""
	_igloo_id = 0
	_hide_invite()
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
	if _rows == null:
		return
	_clear_presence()
	if not _in_game or not Net.is_online():
		return
	var mine := Net.local_profile()
	var self_place := ""
	for entry in Net.roster():
		if int(entry.get("id", 0)) == Net.local_id():
			self_place = _place_label(entry)
			break
	var head := "You are %s" % str(mine["name"])
	if self_place != "":
		head += " — " + self_place
	_rows.add_child(_presence_label(head))
	for entry in Net.roster():
		var id := int(entry.get("id", 0))
		if id == Net.local_id():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := "%s — %s" % [str(entry.get("name", "Penguin")), _place_label(entry)]
		row.add_child(_presence_label(text))
		if not _in_their_igloo(entry):
			var button := Button.new()
			button.text = "Invite"
			button.custom_minimum_size = Vector2(72, 28)
			button.add_theme_font_size_override("font_size", 14)
			button.pressed.connect(_invite_player.bind(id, str(entry.get("name", "Penguin"))))
			row.add_child(button)
		_rows.add_child(row)


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


func _invite_player(peer_id: int, player_name: String) -> void:
	Net.invite_home(peer_id)
	_hud.add_line("You", "Invited %s to your igloo." % player_name)


func _on_home_invite(from_id: int, from_name: String) -> void:
	if not _in_game or from_id == Net.local_id():
		return
	_invite_from = from_id
	_invite_text.text = "%s invited you to their igloo." % from_name
	_invite.visible = true


func _accept_invite() -> void:
	var host_id := _invite_from
	_hide_invite()
	if host_id <= 0:
		return
	travel_to("home", "BusArrival", host_id)


func _hide_invite() -> void:
	_invite_from = 0
	if _invite != null:
		_invite.visible = false


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
	_invite = PanelContainer.new()
	_invite.visible = false
	_invite.mouse_filter = Control.MOUSE_FILTER_STOP
	_invite.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_invite.offset_left = -210
	_invite.offset_top = 16
	_invite.offset_right = 210
	_invite.offset_bottom = 92
	_invite.add_theme_stylebox_override("panel", _invite_style())
	root.add_child(_invite)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_invite.add_child(column)
	_invite_text = Label.new()
	_invite_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite_text.add_theme_color_override("font_color", Color(0.95, 0.97, 1))
	column.add_child(_invite_text)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var visit := Button.new()
	visit.text = "Visit"
	visit.pressed.connect(_accept_invite)
	actions.add_child(visit)
	var decline := Button.new()
	decline.text = "Not now"
	decline.pressed.connect(_hide_invite)
	actions.add_child(decline)


func _invite_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.22, 0.4, 0.96)
	box.border_color = Color(0.86, 0.93, 0.98)
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


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
