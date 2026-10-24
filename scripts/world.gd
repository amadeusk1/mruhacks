extends Node3D

## Owns the penguin and camera. Rooms are swapped under LocationHost.

@onready var _host: Node3D = $LocationHost
@onready var _penguin = $Penguin
@onready var _menu = $BusMenu
@onready var _camera_rig: Node3D = $CameraRig
@onready var _world_camera: Camera3D = $CameraRig/Camera3D

var _current_id := ""
var _traveling := false
var _activity := false
var _penguin_layer := 0
var _penguin_mask := 0


func _ready() -> void:
	add_to_group("world")
	_menu.destination_chosen.connect(_on_destination_chosen)
	_menu.dismissed.connect(_on_menu_dismissed)
	await travel_to("home", "InsideSpawn")


func current_location_id() -> String:
	return _current_id


func is_bus_menu_open() -> bool:
	return _menu.visible


func open_bus_menu() -> void:
	if _traveling or _current_id == "":
		return
	_menu.open_for(_current_id)
	_penguin.set_travel_locked(true)


func close_bus_menu() -> void:
	_menu.dismiss()
	if not _traveling:
		_penguin.set_travel_locked(false)


func is_traveling() -> bool:
	return _traveling


func travel_to(location_id: String, spawn_name: String = "BusArrival") -> void:
	if _traveling or location_id == _current_id:
		return
	if not LocationCatalog.has_location(location_id):
		return
	var path := LocationCatalog.scene_path(location_id)
	if not ResourceLoader.exists(path):
		push_error("Missing location scene: %s" % path)
		if location_id != "plaza":
			await travel_to("plaza")
		return
	_traveling = true
	_menu.dismiss()
	_penguin.set_travel_locked(true)
	_penguin.halt()
	_clear_room()
	var packed := load(path) as PackedScene
	var room := packed.instantiate()
	_host.add_child(room)
	_current_id = location_id
	if room.is_in_group("activity"):
		_enter_activity()
		_traveling = false
		return
	_leave_activity()
	# room_nav bakes during the room's _ready. The map syncs on the physics step.
	await get_tree().physics_frame
	_place_penguin(room, spawn_name)
	await get_tree().physics_frame
	_refresh_stop(room)
	_penguin.set_travel_locked(false)
	_traveling = false


## Door trip inside the current room. The landing marker is outside the door volume.
func shift_to_marker(marker_name: String) -> void:
	if _traveling or _activity or _host.get_child_count() == 0:
		return
	var room := _host.get_child(0)
	var marker := room.get_node_or_null(marker_name) as Node3D
	if marker == null:
		push_error("Missing spawn marker: %s" % marker_name)
		return
	_traveling = true
	_penguin.set_travel_locked(true)
	_penguin.halt()
	_penguin.global_position = Vector3(marker.global_position.x, 0.2, marker.global_position.z)
	_penguin.rotation.y = marker.rotation.y
	_penguin.velocity = Vector3.ZERO
	_penguin.halt()
	_apply_camera(room, marker_name)
	await get_tree().physics_frame
	_refresh_stop(room)
	await get_tree().create_timer(0.35).timeout
	if not _menu.visible:
		_penguin.set_travel_locked(false)
	_traveling = false


func _place_penguin(room: Node, spawn_name: String) -> void:
	var arrival := room.get_node(spawn_name) as Node3D
	var stop := room.get_node("NavigationRegion3D/BusStop") as Node3D
	_penguin.global_position = Vector3(arrival.global_position.x, 0.2, arrival.global_position.z)
	_penguin.velocity = Vector3.ZERO
	if spawn_name == "BusArrival":
		_penguin.face_point(stop.global_position)
	else:
		_penguin.rotation.y = arrival.rotation.y
	_penguin.halt()
	_apply_camera(room, spawn_name)


func _apply_camera(room: Node, spawn_name: String) -> void:
	if room.has_method("camera_for_spawn"):
		var frame: Dictionary = room.call("camera_for_spawn", spawn_name)
		_camera_rig.call("set_frame", frame["center"], float(frame["limit_x"]), float(frame["limit_z"]))
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
	_camera_rig.set_process(false)
	_world_camera.current = false


func _leave_activity() -> void:
	if not _activity:
		return
	_activity = false
	_penguin.collision_layer = _penguin_layer
	_penguin.collision_mask = _penguin_mask
	_penguin.visible = true
	_penguin.process_mode = Node.PROCESS_MODE_INHERIT
	_camera_rig.set_process(true)
	_world_camera.current = true


func _clear_room() -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		child.free()


func _on_destination_chosen(location_id: String) -> void:
	travel_to(location_id)


func _on_menu_dismissed() -> void:
	if _traveling:
		return
	_penguin.set_travel_locked(false)
