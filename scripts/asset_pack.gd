class_name AssetPack
extends RefCounted

## Loads the Blender kit exports in Models/ and dresses the shared bird.

const ROOT := "res://Models"

static var _shared_sit: Animation
static var _shared_wave: Animation


static func spawn(kit: String, asset: String) -> Node3D:
	var path := "%s/%s/%s.glb" % [ROOT, kit, asset]
	if not ResourceLoader.exists(path):
		push_error("Missing pack model %s" % path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Pack model did not import %s" % path)
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	Tints.prepare(node)
	return node


static func place(parent: Node, kit: String, asset: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var node := spawn(kit, asset)
	if node == null:
		return null
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw
	return node


## Replaces the placeholder under visual with the rigged bird.
## cloth is a skinned torso asset. item is parented to a socket (head, neck, back, face).
static func mount_bird(visual: Node3D, body: Color, cloth: String = "", item: String = "", item_socket: String = "head", item_color: Color = Color(1, 1, 1, 0)) -> AnimationPlayer:
	if visual.get_node_or_null("PackAvatar") != null:
		return _player(visual.get_node("PackAvatar"))
	var bird := spawn("anim_locomotion", "avatar_base")
	if bird == null:
		return null
	bird.name = "PackAvatar"
	# The kit faces +Z. Movement treats -Z as forward, so turn the bird around.
	bird.rotation.y = PI
	for child in visual.get_children():
		child.visible = false
	visual.add_child(bird)
	Tints.apply(bird, {"body": body})
	if cloth != "":
		_wear_cloth(bird, cloth, item_color)
	if item != "":
		_wear_item(bird, item, item_socket, item_color)
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	var player := _player(bird)
	if player:
		_alias(player, "sit", _sit_animation())
		_alias(player, "wave", _wave_animation())
		for anim_name in ["idle", "walk", "sit", "wave"]:
			_loop(player, anim_name)
	return player


## Copies the anim_emotes clips (same skeleton, retargets by bone name) into a bird's player.
static func add_emotes(player: AnimationPlayer) -> void:
	var src := spawn("anim_emotes", "avatar_base")
	if src == null:
		return
	var from := _player(src)
	var lib := player.get_animation_library(&"")
	if from and lib:
		for anim_name in from.get_animation_list():
			if not lib.has_animation(anim_name):
				lib.add_animation(anim_name, from.get_animation(anim_name))
	src.free()


static func recolor_body(visual: Node3D, body: Color) -> bool:
	var bird := visual.get_node_or_null("PackAvatar")
	if bird == null:
		return false
	Tints.apply(bird, {"body": body})
	return true


static func dress_town(plaza: Node3D) -> void:
	var nav := plaza.get_node_or_null("NavigationRegion3D")
	if nav == null:
		return
	for shell_name in ["ClothesShell", "PetShell", "FurnitureShell", "BenchWest", "BenchEast", "CCounter"]:
		var shell := nav.get_node_or_null(shell_name)
		if shell:
			var mesh := shell.get_node_or_null("Mesh") as Node3D
			if mesh:
				mesh.visible = false
	var decor := plaza.get_node_or_null("Decor")
	if decor:
		for child in decor.get_children():
			var label := String(child.name)
			if label.begins_with("Fountain") or label.begins_with("Lamp") or label.begins_with("Awning") or label.begins_with("Win") or label.begins_with("Mouth") or label.begins_with("Board"):
				child.visible = false
	if plaza.get_node_or_null("PackProps") != null:
		return
	var props := Node3D.new()
	props.name = "PackProps"
	plaza.add_child(props)
	place(props, "cafe", "cafe_exterior", Vector3(-6.2, 0.0, -8.3))
	place(props, "activities", "sketch_pavilion", Vector3(6.2, 0.0, -8.6))
	place(props, "cottage", "cottage_exterior", Vector3(-6.2, 0.0, 7.5), PI)
	place(props, "plaza", "small_fountain", Vector3(0.0, 0.0, -0.5))
	place(props, "plaza", "bench", Vector3(-3.65, 0.0, 1.25))
	place(props, "plaza", "bench", Vector3(3.65, 0.0, 1.25), PI)
	place(props, "plaza", "lantern_post", Vector3(-4.4, 0.0, -3.4))
	place(props, "plaza", "lantern_post", Vector3(4.4, 0.0, -3.4))
	place(props, "plaza", "lantern_post", Vector3(-2.6, 0.0, 3.55))
	place(props, "plaza", "lantern_post", Vector3(2.6, 0.0, 3.55))
	place(props, "nature_dock", "small_tree_snow", Vector3(-10.2, 0.0, -9.0))
	place(props, "nature_dock", "small_tree_snow", Vector3(10.2, 0.0, -9.0))
	place(props, "nature_dock", "broad_tree_snow", Vector3(10.2, 0.0, 8.4))
	place(props, "plaza", "flower_pot", Vector3(-4.6, 0.0, -5.3))
	place(props, "plaza", "flower_pot", Vector3(4.6, 0.0, -5.3))
	place(props, "cafe", "cafe_counter", Vector3(120.0, 0.0, -2.15), PI)
	place(props, "cafe", "pastry_case", Vector3(119.2, 0.95, -2.05), PI)
	place(props, "room_kit", "sofa_2seat", Vector3(120.0, 0.0, 49.2), PI)
	place(props, "room_kit", "rug_round", Vector3(120.0, 0.02, 50.4))
	place(props, "room_kit", "plant_large", Vector3(122.2, 0.0, 98.6))
	place(props, "room_kit", "plush_penguin", Vector3(120.4, 0.35, 101.2))


## Snow dome is the player house. Front is Godot +Z. Floor of the interior sits 0.12 m above its origin.
const _DOME_FLOOR_Y := 0.12
const _YARD_MIN_Z := -5.15
const _YARD_MAX_X := 1.05


static func dress_home(home: Node3D) -> void:
	if home.get_node_or_null("PackProps") != null:
		return
	_retire_home_boxes(home)
	var props := Node3D.new()
	props.name = "PackProps"
	home.add_child(props)
	var nav := home.get_node("NavigationRegion3D") as Node3D
	_place_home_exterior(home, props, nav)
	_place_home_interior(home, props, nav)
	if nav.has_method("rebake"):
		nav.call("rebake")


static func _retire_home_boxes(home: Node) -> void:
	for path in [
		"NavigationRegion3D/Dome",
		"NavigationRegion3D/SnowCap",
		"NavigationRegion3D/Lintel",
		"NavigationRegion3D/Mouth",
		"NavigationRegion3D/InLintel",
		"NavigationRegion3D/Blanket",
		"NavigationRegion3D/Pillow",
		"NavigationRegion3D/Rug",
		"NavigationRegion3D/Window",
		"NavigationRegion3D/DoorMat",
		"NavigationRegion3D/ExitSnow",
		"NavigationRegion3D/InFloor/Mesh",
		"NavigationRegion3D/PathA",
		"NavigationRegion3D/PathB",
		"NavigationRegion3D/PathC",
		"NavigationRegion3D/PathD",
	]:
		var mesh := home.get_node_or_null(path) as Node3D
		if mesh:
			mesh.visible = false
	for path in [
		"NavigationRegion3D/IglooBlocker",
		"NavigationRegion3D/PillarL",
		"NavigationRegion3D/PillarR",
		"NavigationRegion3D/IceChunk",
		"NavigationRegion3D/InWallNorth",
		"NavigationRegion3D/InWallSouthL",
		"NavigationRegion3D/InWallSouthR",
		"NavigationRegion3D/InWallWest",
		"NavigationRegion3D/InWallEast",
		"NavigationRegion3D/Bed",
	]:
		var body := home.get_node_or_null(path) as CollisionObject3D
		if body:
			body.collision_layer = 0
			body.visible = false


static func _place_home_exterior(home: Node3D, props: Node3D, nav: Node3D) -> void:
	var house := spawn("homes", "snow_dome_exterior")
	if house == null:
		return
	props.add_child(house)
	house.rotation = Vector3.ZERO
	var bounds := _model_aabb(house)
	var door := Sockets.find(house, "door")
	var door_local := Vector3(0.0, 0.0, bounds.position.z + bounds.size.z)
	if door:
		door_local = house.to_local(door.global_position)
	house.position = Vector3(
		_YARD_MAX_X - (bounds.position.x + bounds.size.x),
		0.02,
		_YARD_MIN_Z - bounds.position.z
	)
	var door_world := house.global_transform * door_local
	var outward := Vector3(door_local.x, 0.0, door_local.z)
	if outward.length_squared() < 0.01:
		outward = Vector3(0.0, 0.0, 1.0)
	outward = outward.normalized()
	_wall_ring(nav, house.global_position, 2.2, Vector2(outward.x, outward.z), 0.4)
	_tunnel(nav, house.global_position, door_local, outward)
	_set_door(home.get_node("YardDoor") as Area3D, door_world + outward * 0.2, outward)
	_aim_marker(home.get_node("OutsideSpawn") as Node3D, door_world + outward * 1.35, door_world)
	var stop := nav.get_node_or_null("BusStop") as Node3D
	if stop:
		stop.position.x = 4.3
	var arrival := home.get_node_or_null("BusArrival") as Node3D
	if arrival:
		arrival.position.x = 4.3


static func _place_home_interior(home: Node3D, props: Node3D, nav: Node3D) -> void:
	var room := spawn("homes", "snow_dome_interior")
	if room == null:
		return
	props.add_child(room)
	room.position = Vector3(80.0, -_DOME_FLOOR_Y, 0.0)
	room.rotation = Vector3.ZERO
	var exit_socket := Sockets.find(room, "exit")
	var spawn_socket := Sockets.find(room, "spawn_inside")
	var exit_local := Vector3(-1.93, _DOME_FLOOR_Y, -0.7)
	if exit_socket:
		exit_local = room.to_local(exit_socket.global_position)
	var outward := Vector3(exit_local.x, 0.0, exit_local.z)
	if outward.length_squared() < 0.01:
		outward = Vector3(-1.0, 0.0, 0.0)
	outward = outward.normalized()
	_wall_ring(nav, room.global_position, 2.15, Vector2(outward.x, outward.z), 0.42)
	var exit_world := room.global_transform * exit_local
	_set_door(home.get_node("InsideDoor") as Area3D, exit_world + outward * 0.45, outward, 1.9)
	var spawn_world := room.global_position + Vector3(-1.32, 0.0, -0.48)
	if spawn_socket:
		spawn_world = spawn_socket.global_position
	_aim_marker(home.get_node("InsideReturn") as Node3D, spawn_world, room.global_position)
	_aim_marker(home.get_node("InsideSpawn") as Node3D, spawn_world, room.global_position)
	_furnish(room, "room_kit", "bed", Vector3(0.15, _DOME_FLOOR_Y, -1.05), 0.0)
	_furnish(room, "room_kit", "rug_round", Vector3(0.2, _DOME_FLOOR_Y + 0.02, 0.35), 0.0)
	_furnish(room, "room_kit", "floor_lamp", Vector3(1.15, _DOME_FLOOR_Y, 0.35), 0.0)


## Cinema exterior faces Godot +Z. Lobby and auditorium are separate rooms.
const _CINEMA_AT := Vector3(0.0, 0.0, -2.2)
const _CINEMA_LOBBY := Vector3(240.0, 0.0, 0.0)
const _CINEMA_HALL := Vector3(240.0, 0.0, 50.0)


static func dress_cinema(room: Node3D) -> void:
	if room.get_node_or_null("PackProps") != null:
		return
	var props := Node3D.new()
	props.name = "PackProps"
	room.add_child(props)
	var nav := room.get_node("NavigationRegion3D") as Node3D
	_place_cinema_exterior(room, props, nav)
	_place_cinema_lobby(room, props, nav)
	_place_cinema_hall(room, props, nav)
	room.set_meta("lobby_center", _CINEMA_LOBBY)
	room.set_meta("hall_center", _CINEMA_HALL)
	if nav.has_method("rebake"):
		nav.call("rebake")


static func _place_cinema_exterior(room: Node3D, props: Node3D, nav: Node3D) -> void:
	var house := spawn("cinema", "cinema_exterior")
	if house == null:
		return
	props.add_child(house)
	house.rotation = Vector3.ZERO
	house.position = _CINEMA_AT
	var bounds := _model_aabb(house)
	var center := bounds.position + bounds.size * 0.5
	_axis_box(nav, Vector3(bounds.size.x, maxf(bounds.size.y, 2.0), bounds.size.z), house.position + center, 2)
	var front := bounds.position.z + bounds.size.z
	var approach := Vector3(0.0, 0.0, front + 0.7)
	var door := Sockets.find(house, "door")
	if door:
		approach.x = house.to_local(door.global_position).x
	var approach_world := house.global_transform * approach
	_set_door(room.get_node("FrontDoor") as Area3D, approach_world, Vector3(0.0, 0.0, 1.0), 2.6)
	_aim_marker(room.get_node("OutsideSpawn") as Node3D, approach_world + Vector3(0.0, 0.0, 1.35), approach_world)
	var sparkle := Sockets.find(house, "fx_sparkle")
	var marquee := Vector3(0.0, 4.0, 3.3)
	if sparkle:
		marquee = house.to_local(sparkle.global_position)
	_glow(house, marquee, Color(1.0, 0.72, 0.45), 1.6, 6.0)


static func _place_cinema_lobby(room: Node3D, props: Node3D, nav: Node3D) -> void:
	var lobby := spawn("cinema_lobby", "cinema_lobby")
	if lobby == null:
		return
	props.add_child(lobby)
	lobby.position = _CINEMA_LOBBY
	lobby.rotation = Vector3.ZERO
	var bounds := _model_aabb(lobby)
	var min_p := bounds.position
	var max_p := bounds.position + bounds.size
	_floor_inside(nav, lobby.position, bounds, 0.35)
	_wall_along_x(nav, lobby.position, min_p.z - 0.22, min_p.x - 0.2, max_p.x + 0.2, 0.0, 0.0)
	_wall_along_x(nav, lobby.position, max_p.z + 0.22, min_p.x - 0.2, max_p.x + 0.2, 0.0, 1.25)
	_wall_along_z(nav, lobby.position, min_p.x - 0.22, min_p.z - 0.2, max_p.z + 0.2, 0.0, 0.0)
	var screen := Sockets.find(lobby, "screen_door")
	var screen_at := Vector3(max_p.x - 0.9, 0.0, -1.6)
	if screen:
		screen_at = lobby.to_local(screen.global_position)
	_wall_along_z(nav, lobby.position, max_p.x + 0.22, min_p.z - 0.2, max_p.z + 0.2, screen_at.z, 1.05)
	var entrance_at := Vector3(0.0, 0.0, max_p.z + 0.05)
	_set_door(room.get_node("LobbyStreetDoor") as Area3D, lobby.global_transform * entrance_at, Vector3(0.0, 0.0, 1.0), 2.7)
	_aim_marker(room.get_node("InsideLobby") as Node3D, lobby.global_transform * Vector3(0.0, 0.0, max_p.z - 1.7), lobby.global_position)
	var into_room := Vector3(max_p.x + 0.05, 0.0, screen_at.z)
	_set_door(room.get_node("LobbyScreenDoor") as Area3D, lobby.global_transform * into_room, Vector3(1.0, 0.0, 0.0), 2.2)
	_aim_marker(room.get_node("ScreenReturn") as Node3D, lobby.global_transform * Vector3(screen_at.x - 1.6, 0.0, screen_at.z), lobby.global_position)
	_blocker_at(nav, lobby, "counter", Vector3(-2.35, 0.55, -1.45), Vector3(2.6, 1.1, 1.2), Vector3(0.0, 0.5, -0.45))
	_blocker_at(nav, lobby, "kiosk", Vector3(1.0, 0.5, -0.95), Vector3(1.05, 1.0, 0.7), Vector3(0.0, 0.45, 0.0))
	_axis_box(nav, Vector3(2.3, 0.7, 0.9), lobby.position + Vector3(-1.9, 0.35, 1.75), 2)
	_axis_box(nav, Vector3(0.85, 0.7, 1.5), lobby.position + Vector3(-3.35, 0.35, -0.15), 2)
	_glow(lobby, Vector3(0.0, 2.35, 0.2), Color(1.0, 0.84, 0.68), 1.15, 9.0)


static func _place_cinema_hall(room: Node3D, props: Node3D, nav: Node3D) -> void:
	var hall := spawn("cinema_auditorium", "cinema_auditorium")
	if hall == null:
		return
	props.add_child(hall)
	hall.position = _CINEMA_HALL
	hall.rotation = Vector3.ZERO
	var bounds := _model_aabb(hall)
	var min_p := bounds.position
	var max_p := bounds.position + bounds.size
	_floor_inside(nav, hall.position, bounds, 0.4)
	_wall_along_x(nav, hall.position, min_p.z - 0.22, min_p.x - 0.2, max_p.x + 0.2, 0.0, 0.0)
	_wall_along_x(nav, hall.position, max_p.z + 0.22, min_p.x - 0.2, max_p.x + 0.2, 0.0, 0.0)
	_wall_along_z(nav, hall.position, max_p.x + 0.22, min_p.z - 0.2, max_p.z + 0.2, 0.0, 0.0)
	var exit := Sockets.find(hall, "exit")
	var exit_at := Vector3(min_p.x + 1.0, 0.0, max_p.z - 1.0)
	if exit:
		exit_at = hall.to_local(exit.global_position)
	_wall_along_z(nav, hall.position, min_p.x - 0.22, min_p.z - 0.2, max_p.z + 0.2, exit_at.z, 0.95)
	var into_aisle := Vector3(min_p.x + 0.15, 0.0, exit_at.z)
	_set_door(room.get_node("AuditoriumDoor") as Area3D, hall.global_transform * into_aisle, Vector3(-1.0, 0.0, 0.0), 2.0)
	var landing := Vector3(0.6, 0.0, exit_at.z)
	var screen := Sockets.find(hall, "screen")
	var screen_at := Vector3(0.0, 0.0, min_p.z + 0.8)
	if screen:
		screen_at = hall.to_local(screen.global_position)
	_aim_marker(room.get_node("InsideScreen") as Node3D, hall.global_transform * landing, hall.global_transform * screen_at)
	for seat_z in [-0.47, 0.73, 1.93]:
		_axis_box(nav, Vector3(3.15, 0.55, 0.72), hall.position + Vector3(-0.66, 0.28, seat_z), 2)
	_axis_box(nav, Vector3(4.8, 1.5, 1.05), hall.position + Vector3(0.0, 0.75, screen_at.z), 2)
	_glow(hall, Vector3(0.2, 2.5, 0.4), Color(0.55, 0.72, 0.78), 0.7, 8.0)
	_glow(hall, Vector3(screen_at.x, 2.1, screen_at.z + 0.8), Color(0.78, 0.88, 1.0), 1.5, 7.0)


static func _floor_inside(nav: Node3D, origin: Vector3, bounds: AABB, inset: float) -> void:
	var min_p := bounds.position + Vector3(inset, 0.0, inset)
	var max_p := bounds.position + bounds.size - Vector3(inset, 0.0, inset)
	var size := max_p - min_p
	var center := (min_p + max_p) * 0.5
	_axis_box(nav, Vector3(size.x, 0.4, size.z), origin + Vector3(center.x, -0.2, center.z), 1)


static func _blocker_at(nav: Node3D, room: Node3D, socket_name: String, fallback: Vector3, size: Vector3, nudge: Vector3) -> void:
	var at := fallback
	var socket := Sockets.find(room, socket_name)
	if socket:
		at = room.to_local(socket.global_position) + nudge
	_axis_box(nav, size, room.position + at, 2)


static func _wall_along_x(nav: Node3D, origin: Vector3, z: float, x0: float, x1: float, gap_center: float, gap_half: float) -> void:
	_split_span(nav, origin, true, z, x0, x1, gap_center, gap_half)


static func _wall_along_z(nav: Node3D, origin: Vector3, x: float, z0: float, z1: float, gap_center: float, gap_half: float) -> void:
	_split_span(nav, origin, false, x, z0, z1, gap_center, gap_half)


static func _split_span(nav: Node3D, origin: Vector3, along_x: bool, fixed: float, a0: float, a1: float, gap_center: float, gap_half: float) -> void:
	var spans: Array[Vector2] = []
	if gap_half <= 0.0:
		spans.append(Vector2(a0, a1))
	else:
		var gap0 := gap_center - gap_half
		var gap1 := gap_center + gap_half
		if gap0 - a0 > 0.25:
			spans.append(Vector2(a0, gap0))
		if a1 - gap1 > 0.25:
			spans.append(Vector2(gap1, a1))
	for span in spans:
		var length := span.y - span.x
		var mid := (span.x + span.y) * 0.5
		if along_x:
			_axis_box(nav, Vector3(length, 2.2, 0.42), origin + Vector3(mid, 1.1, fixed), 2)
		else:
			_axis_box(nav, Vector3(0.42, 2.2, length), origin + Vector3(fixed, 1.1, mid), 2)


static func _axis_box(nav: Node3D, size: Vector3, at: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	nav.add_child(body)
	body.position = at
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)


static func _glow(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	parent.add_child(light)
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false


static func _furnish(parent: Node3D, kit: String, asset: String, at: Vector3, yaw: float) -> void:
	var node := spawn(kit, asset)
	if node == null:
		return
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw


static func _wall_ring(nav: Node3D, center: Vector3, radius: float, door_dir: Vector2, half_gap: float) -> void:
	var count := 18
	var door_angle := door_dir.angle()
	var tangent_len := TAU * radius / float(count) + 0.14
	for i in count:
		var angle := TAU * float(i) / float(count)
		if absf(wrapf(angle - door_angle, -PI, PI)) < half_gap:
			continue
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-radial.z, 0.0, radial.x)
		_oriented_box(nav, Vector3(tangent_len, 2.2, 0.46), center + radial * radius + Vector3(0.0, 1.1, 0.0), side, radial)


static func _tunnel(nav: Node3D, origin: Vector3, door_local: Vector3, outward: Vector3) -> void:
	var reach := Vector3(door_local.x, 0.0, door_local.z).dot(outward)
	var start := 1.7
	var length := maxf(reach - start, 0.4)
	var mid := start + length * 0.5
	var side := Vector3(-outward.z, 0.0, outward.x)
	var gap := 1.35
	var thick := 0.42
	for sign: float in [-1.0, 1.0]:
		var at: Vector3 = origin + outward * mid + side * sign * (gap + thick) * 0.5
		at.y = 0.85
		_oriented_box(nav, Vector3(thick, 1.7, length), at, side, outward)


static func _oriented_box(nav: Node3D, size: Vector3, at: Vector3, x_axis: Vector3, z_axis: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	nav.add_child(body)
	body.transform = Transform3D(Basis(x_axis.normalized(), Vector3.UP, z_axis.normalized()), at)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)


static func _set_door(door: Area3D, center: Vector3, outward: Vector3, width: float = 1.35) -> void:
	var out := outward.normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	door.global_transform = Transform3D(Basis(side * width, Vector3.UP * 1.7, out * 0.9), center + Vector3(0.0, 0.85, 0.0))


static func _aim_marker(marker: Node3D, at: Vector3, look_target: Vector3) -> void:
	marker.global_position = Vector3(at.x, 0.2, at.z)
	var flat := look_target - at
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return
	marker.rotation.y = atan2(-flat.x, -flat.z)


static func _model_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var has_mesh := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local := root.global_transform.affine_inverse() * mesh.global_transform
		var piece := _transformed_aabb(local, mesh.get_aabb())
		merged = piece if not has_mesh else merged.merge(piece)
		has_mesh = true
	return merged


static func _transformed_aabb(xf: Transform3D, box: AABB) -> AABB:
	var out := AABB()
	var started := false
	for i in 8:
		var corner := box.position
		if i & 1:
			corner.x += box.size.x
		if i & 2:
			corner.y += box.size.y
		if i & 4:
			corner.z += box.size.z
		var point := xf * corner
		if not started:
			out = AABB(point, Vector3.ZERO)
			started = true
		else:
			out = out.expand(point)
	return out


static func _wear_cloth(bird: Node3D, asset: String, tint: Color) -> void:
	var skeleton := bird.find_child("Skeleton3D", true, false) as Skeleton3D
	var piece := spawn("avatar", asset)
	if skeleton == null or piece == null:
		return
	bird.add_child(piece)
	var meshes := piece.find_children("*", "MeshInstance3D", true, false)
	var mesh := meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	if mesh == null:
		piece.queue_free()
		return
	var local := mesh.transform
	mesh.owner = null
	mesh.get_parent().remove_child(mesh)
	skeleton.add_child(mesh)
	mesh.transform = local
	mesh.skeleton = mesh.get_path_to(skeleton)
	if tint.a > 0.0:
		Tints.apply(mesh, {"cloth_primary": tint, "cloth_secondary": tint.lightened(0.15)})
	piece.queue_free()


static func _wear_item(bird: Node3D, asset: String, socket_name: String, tint: Color) -> void:
	var slot := Sockets.find(bird, socket_name)
	var item := spawn("avatar", asset)
	if slot == null or item == null:
		if item:
			item.queue_free()
		return
	slot.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	item.scale = Vector3.ONE
	if tint.a > 0.0:
		Tints.apply(item, {"cloth_primary": tint, "cloth_secondary": tint.lightened(0.15)})


static func _player(bird: Node) -> AnimationPlayer:
	return bird.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func _alias(player: AnimationPlayer, target: String, anim: Animation) -> void:
	if anim == null or player.has_animation(target):
		return
	var lib := player.get_animation_library(&"")
	if lib:
		lib.add_animation(target, anim)


static func _loop(player: AnimationPlayer, anim_name: String) -> void:
	if not player.has_animation(anim_name):
		return
	player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


static func _sit_animation() -> Animation:
	if _shared_sit == null:
		_shared_sit = _take_anim("anim_social", "avatar_base", ["sit_idle", "sit_idle_loop"])
	return _shared_sit


static func _wave_animation() -> Animation:
	if _shared_wave == null:
		_shared_wave = _take_anim("anim_emotes", "avatar_base", ["emote_wave", "wave"])
	return _shared_wave


static func _take_anim(kit: String, asset: String, names: Array) -> Animation:
	var node := spawn(kit, asset)
	if node == null:
		return null
	var player := _player(node)
	var found: Animation = null
	if player:
		for anim_name in names:
			if player.has_animation(anim_name):
				found = player.get_animation(anim_name).duplicate()
				break
	node.free()
	return found
