extends Node3D

## A walk-in interior assembled from an art-pack shell and its sockets (cafe, arcade).
## Builds floor/wall colliders and props under NavigationRegion3D before room_nav.gd bakes,
## an "Inside" spawn, and a walk-out door back to the town door's "<Door>Out" marker.
## Socket positions in manifests are Blender (x, y, z); Godot is (x, z, -y).

@export var room := "cafe"

const ROOMS := {
	"cafe": {
		"shell": "cafe/cafe_interior_shell",
		"town_spawn": "CafeDoorOut",
		"floor_y": 0.1,
		"spawn": "socket_spawn_inside", "exit": "socket_exit",
		"props": [
			["cafe/cafe_counter", "socket_counter", 0.0],
			["cafe/coffee_station", "socket_coffee_station", 0.0],
			["cafe/menu_board", "socket_menu_board", 0.0],
			["cafe/wall_shelf", "socket_wall_shelf", 0.0],
			["plaza/round_table", "socket_table_0", 0.0],
			["plaza/round_table", "socket_table_1", 0.0],
			["plaza/round_table", "socket_table_2", 0.0],
			["cafe/pastry_case", "socket_pastry_case", 0.0],
			["cafe/mug_set", "socket_mug_set", 0.0],
			["cafe/tray_breakfast_preset_preview", "socket_table_0_top", 15.0],
			# 04 Cafe Interior: potted plants in the corners, flowers on the tables, a shelf of jars
			# and greenery by the back door, warm sconces on the walls, a mat at the door
			["room_kit/plant_large", [-4.3, 0.1, -3.3], 30.0],
			["room_kit/plant_large", [4.35, 0.1, 0.3], -60.0],
			["room_kit/plant_flowerpot", [-2.9, 0.7, 1.9], 0.0],
			["room_kit/plant_flowerpot", [2.6, 0.7, 1.9], 0.0],
			["room_kit/wall_shelf", [-2.4, 1.5, -3.95], 0.0],
			["room_kit/tabletop_plant", [-2.7, 1.53, -3.95], 0.0],
			["cafe/sugar_jar", [-2.35, 1.53, -3.95], 0.0],
			["cafe/teapot", [-2.05, 1.53, -3.95], 0.0],
			["room_kit/wall_shelf", [-4.0, 1.5, -3.95], 0.0],
			["room_kit/plant_hanging", [-4.0, 1.53, -3.95], 0.0],
			["interior_finishing/wall_sconce", [-4.95, 1.75, -1.9], 90.0],
			["interior_finishing/wall_sconce", [-4.95, 1.75, 1.9], 90.0],
			["plaza/wall_lantern", [-1.45, 1.9, -3.93], 0.0],
			["plaza/wall_lantern", [0.45, 1.9, -3.93], 0.0],
			["interior_finishing/ceiling_pendant", [-2.9, 2.45, -1.9], 0.0],
			["interior_finishing/ceiling_pendant", [-2.9, 2.45, 1.9], 0.0],
			["interior_finishing/ceiling_pendant", [2.6, 2.45, 1.9], 0.0],
			["interior_finishing/ceiling_pendant", [2.9, 2.45, -2.0], 0.0],
			["room_kit/plant_large", [-4.3, 0.1, 3.3], 0.0],
			["room_kit/entry_mat", [-0.2, 0.11, 3.2], 0.0],
		],
		"palette": {"paving": "#C98D58", "paving_b": "#B97C49", "stone": "#A86F43", "glow_window": "glow:#FFD58A"},  # warm wood floor, lit windows
		"lights": [[-2.9, 2.0, -1.9], [-2.9, 2.0, 1.9], [2.6, 2.0, 1.9], [2.9, 2.0, -2.0]],
		"cut_right": 0.6,
		"tints": {"shell": {"wall": "#F4E0C2"}},
		"mood": {"background": "#EAD9C2", "ambient": "#FFE2BE", "sun": "#FFDDB0"},
		# seats authored in the shell to the Interior Spacing Standard: socket_<anchor>_seat_<k> faces socket_<anchor>
		"shell_seats": ["plaza/stool", "stool"],
		"camera": {"limit_x": 2.6, "limit_z": 2.0, "height": 7.4, "distance": 8.6, "yaw_deg": 35.0},
	},
	"casino": {
		"shell": "casino/casino_interior_shell",
		"town_spawn": "CasinoDoorOut",
		"floor_y": 0.12,
		"spawn": "socket_spawn_inside", "exit": "socket_exit",
		"cut_front": 1.0,
		"props": [
			["casino/roulette_table", "socket_roulette", 0.0],
			["casino/poker_table", "socket_poker", 0.0],
			["casino/blackjack_table", "socket_blackjack", 0.0],
			# lounge chairs in the front corners turn to face the room, so you sit down from inside it
			["casino/lounge_chair", "socket_lounge_0", 125.0],
			["casino/lounge_chair", "socket_lounge_1", -125.0],
			# decor hugs the walls, clear of the 16 x 12 m shell's tables (they used to stand on them)
			["casino/standing_lamp", [-7.5, 0.12, -5.5], 0.0],
			["casino/standing_lamp", [7.5, 0.12, -5.5], 0.0],
			["casino/casino_planter", [-7.5, 0.12, -0.6], 0.0],
			["casino/coat_stand", [7.5, 0.12, -1.8], 0.0],
			# Casino - Building and Interior: warm sconces down both walls, framed suits by the back wall
			["interior_finishing/wall_sconce", [-8.05, 1.8, -3.0], 90.0],
			["interior_finishing/wall_sconce", [-8.05, 1.8, 1.5], 90.0],
			["interior_finishing/wall_sconce", [8.05, 1.8, -3.0], -90.0],
			["interior_finishing/wall_sconce", [8.05, 1.8, 1.5], -90.0],
			["room_kit/poster_frame_matted", [-6.0, 1.7, -6.1], 0.0],
			["room_kit/poster_frame_matted", [-3.0, 1.7, -6.1], 0.0],
			["room_kit/plant_large", [-7.5, 0.12, 4.9], 0.0],
			["room_kit/plant_large", [7.5, 0.12, 4.9], 0.0],
		],
		# deep green felt and upholstery, walnut rails, red slots: the casino sheets' palette
		"roles": {"upholstery": "#2F6B55", "cushion": "#2F6B55", "felt": "#1E6A4A", "rail": "#5B3A24", "trim": "#2A6A5C"},
		"palette": {"insert_felt": "#1E6A4A"},
		"mood": {"background": "#3A2A22", "ambient": "#FFD7A8", "sun": "#FFD2A0"},
		# [table placement anchor, seat prop, game, seat height]; seats come from the table's socket_seat_*
		"games": [["socket_roulette", "casino/roulette_stool", "roulette", "casino"], ["socket_poker", "casino/casino_chair", "poker", "casino"],
			["socket_blackjack", "casino/casino_chair", "blackjack", "casino"],
			["socket_lounge_0", "", "", "armchair", "socket_seat"], ["socket_lounge_1", "", "", "armchair", "socket_seat"]],
		"slot_row": true,  # machines, stools and tints from the shell's slot_row meta
		"lights": [[-7.5, 1.6, -5.5], [7.5, 1.6, -5.5], [0.0, 2.6, 0.0]],
		"camera": {"limit_x": 3.4, "limit_z": 2.4, "height": 9.5, "distance": 7.8},
	},
	"arcade": {
		"shell": "arcade/arcade_shell",  # 12 x 9 m floor; front wall is the hideable arcade_shell_cutaway
		"town_spawn": "ArcadeDoorOut",
		"floor_y": 0.02,
		"spawn": "socket_door_inside", "exit": [0.0, 0.0, 4.7],
		"props": [
			["arcade/arcade_cabinet", "socket_cabinet_solo_0", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_solo_1", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_solo_2", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_solo_3", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_solo_4", 0.0],
			["arcade/arcade_cabinet_duo", "socket_cabinet_duo", 0.0],
			["arcade/token_machine", "socket_token_machine", -90.0],
			["arcade/arcade_rug", [0.0, 0.07, 0.11], 0.0],
			["arcade/arcade_bench", "socket_bench_0", 90.0],
			# Arcade Social Scene: a little table with a plant on the rug, potted plants in the
			# corners, wall lanterns, a poster and a neon sign, a mat at the door
			["plaza/round_table", [0.0, 0.02, 0.9], 0.0],
			["room_kit/plant_flowerpot", [0.0, 0.74, 0.9], 0.0],
			["room_kit/plant_large", [-5.5, 0.02, -3.9], 20.0],
			["room_kit/plant_large", [5.5, 0.02, -3.9], -20.0],
			["room_kit/plant_broadleaf", [5.5, 0.02, 0.4], 0.0],
			["plaza/wall_lantern", [-5.93, 1.8, -1.2], 90.0],
			["plaza/wall_lantern", [-5.93, 1.8, 1.6], 90.0],
			["plaza/wall_lantern", [5.4, 1.9, -4.43], 0.0],
			["room_kit/poster_frame_bold", [-5.95, 1.6, 0.2], 90.0],
			["home_themes/neon_wall_sign", [3.6, 2.35, -4.45], 0.0],  # over the duo cabinet, like the concept's marquee
			["room_kit/entry_mat", [0.0, 0.03, 3.9], 0.0],
		],
		"palette": {"paving": "#E9D3AE", "paving_b": "#DEC197"},
		"mood": {"background": "#E6D3BC", "ambient": "#FFE0C0", "sun": "#FFD9AC"},
		"games": [["socket_cabinet_solo_0", "", "pac", "arcade", "socket_player"], ["socket_cabinet_solo_1", "", "tetris", "arcade", "socket_player"],
			["socket_cabinet_solo_2", "", "dino", "arcade", "socket_player"], ["socket_cabinet_solo_3", "", "tetris", "arcade", "socket_player"],
			["socket_cabinet_solo_4", "", "pac", "arcade", "socket_player"], ["socket_cabinet_duo", "", "arcade", "arcade", "socket_player"]],
		"tints": {"socket_cabinet_solo_0": {"body": "#7B4FC4"}, "socket_cabinet_solo_1": {"body": "#3FB3B5"},
			"socket_cabinet_solo_2": {"body": "#D9473B"}, "socket_cabinet_solo_3": {"body": "#E3A92B"},
			"socket_cabinet_solo_4": {"body": "#3D7BD9"}},
		"lights": [[-3.2, 2.4, -2.6], [1.6, 2.4, -2.6], [0.0, 2.6, 1.6]],
		"cut_right": 0.5,
		"camera": {"limit_x": 3.0, "limit_z": 2.2, "height": 7.6, "distance": 9.0, "yaw_deg": 30.0},
	},
}

var _cfg: Dictionary
var _solid := []  # [node, id]: collision from the model's footprint (Footprint) once the floor exists


func _enter_tree() -> void:
	_cfg = ROOMS[room]
	var nav := get_node("NavigationRegion3D")
	var shell_id: String = _cfg["shell"]
	var shell := AssetPack.spawn(shell_id.get_base_dir(), shell_id.get_file())
	shell.name = "Shell"
	nav.add_child(shell)
	for pat in ["*_cutaway", "*_ceiling"]:  # camera looks in through the front and the top
		for n in shell.find_children(pat, "", true, false):
			(n as Node3D).visible = false
	var size := AssetRegistry.size(shell_id)
	_paint(shell)
	WalkSurface.build(shell, nav, shell.position.y - 0.3, "ShellWalk")  # raised floors, steps
	if _cfg.has("cut_front"):
		_cut_front(shell, Vector3(0, 0, 1), size.z * 0.5 - float(_cfg["cut_front"]))
	if _cfg.has("cut_right"):  # the three-quarter camera looks in over the right-hand wall
		_cut_front(shell, Vector3(1, 0, 0), size.x * 0.5 - float(_cfg["cut_right"]))
	var inner = AssetRegistry.entry(shell_id).get("interior_m", null)  # floor size; the bbox includes plinth and awning
	var room := Vector3(float(inner[0]), size.y, float(inner[1])) if inner is Array else size
	var pad := 0.1 if inner is Array else 0.0  # interior_m walls sit just outside the floor
	var y: float = _cfg["floor_y"]
	var sockets: Dictionary = AssetRegistry.sockets(shell_id)
	var exit := _point(sockets, _cfg["exit"])
	# the floor runs on under the exit door to an invisible front wall: the camera looks in through
	# the open front, and walking past the door used to step off the floor into the void
	var front := maxf(room.z * 0.5 + pad, exit.z + 0.6)
	_box(nav, Vector3(0, y - 0.05, (front - room.z * 0.5) * 0.5), Vector3(room.x, 0.1, front + room.z * 0.5), 1)
	for side in [-1, 1]:  # side, back and front walls (layer 2 carves the navmesh)
		_box(nav, Vector3(side * (room.x * 0.5 + pad), 1.0, (front - room.z * 0.5) * 0.5), Vector3(0.2, 2.0, front + room.z * 0.5), 2)
	_box(nav, Vector3(0, 1.0, -(room.z * 0.5 + pad)), Vector3(room.x, 2.0, 0.2), 2)
	_box(nav, Vector3(0, 1.0, front + 0.1), Vector3(room.x, 2.0, 0.2), 2)
	var placed := {}
	for p in _cfg["props"]:
		var at := _socket(sockets, p[1]) if p[1] is String else _v(p[1])
		var node := _place(nav, p[0], at, p[2])
		if p[1] is String:
			placed[p[1]] = [node, p[0], at, p[2]]
		var tints: Dictionary = _cfg.get("tints", {}).get(str(p[1]), {})
		if node and tints.has("body"):
			Tints.apply(node, {"body": Color(tints["body"])})
	if _cfg.get("slot_row", false):
		_slot_row(nav, shell_id, sockets)
	for g in _cfg.get("games", []):
		if placed.has(g[0]):
			_seats(nav, placed[g[0]], g)
	if _cfg.has("shell_seats"):
		_shell_seats(nav, sockets, _cfg["shell_seats"])
	for l in _cfg.get("lights", []):
		var light := OmniLight3D.new()  # warm lamp pools
		light.light_color = Color("#FFC76B")
		light.light_energy = 1.4
		light.omni_range = 4.5
		light.position = _v(l)
		add_child(light)
	for child in nav.get_children():  # room-wide roles and palette over the props and seats
		if child is Node3D and child != shell:
			_paint(child, "room")
	var spawn := Marker3D.new()
	spawn.name = "Inside"
	spawn.position = _point(sockets, _cfg["spawn"])
	add_child(spawn)
	var door := Area3D.new()
	door.name = "ExitDoor"
	door.set_script(load("res://scripts/doorway.gd"))
	door.set("location", "town")
	door.set("spawn_name", _cfg["town_spawn"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.6, 0.5)
	shape.shape = box
	door.add_child(shape)
	door.position = exit + Vector3(0, 0.8, 0)
	add_child(door)


## shortcut: removes faces whose vertices all sit in front of `z_cut` above the base course;
## replace with an authored *_cutaway child in the art kit when it exists.
func _cut_front(shell: Node3D, axis: Vector3, z_cut: float) -> void:
	if axis.z > 0.0:
		for n in shell.find_children("part_door*", "", true, false):
			(n as Node3D).visible = false
	for mi in shell.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or String(mi.name).begins_with("part_"):
			continue
		var out := ArrayMesh.new()
		for si in mi.mesh.get_surface_count():
			var mdt := MeshDataTool.new()
			mdt.create_from_surface(mi.mesh, si)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for f in mdt.get_face_count():
				var in_front := true
				var low := true
				for k in 3:
					var v := mdt.get_vertex(mdt.get_face_vertex(f, k))
					in_front = in_front and v.dot(axis) >= z_cut
					low = low and v.y < 0.3
				if in_front and not low:  # keep the stone base course as a low front lip
					continue
				for k in 3:
					var vi := mdt.get_face_vertex(f, k)
					st.set_normal(mdt.get_vertex_normal(vi))
					st.set_color(mdt.get_vertex_color(vi))
					st.add_vertex(mdt.get_vertex(vi))
			st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, mi.get_active_material(si))
		mi.mesh = out
		for si in out.get_surface_count():
			mi.set_surface_override_material(si, null)


## Room palette from the concept sheet (InteriorMood): the shell gets its own tint roles; "roles"
## and "palette" then apply to everything placed in the room.
func _paint(node: Node3D, roles_key := "shell") -> void:
	var roles: Dictionary = _cfg.get("tints", {}).get("shell", {}) if roles_key == "shell" else _cfg.get("roles", {})
	InteriorMood.paint(node, roles, _cfg.get("palette", {}))


var _saved_mood := {}


func _exit_tree() -> void:
	InteriorMood.restore(get_tree(), _saved_mood)


func _ready() -> void:
	_saved_mood = InteriorMood.apply(get_tree(), _cfg.get("mood", {}))
	AmbientFx.dress(self)  # steam on the coffee station and mugs; no snow indoors
	_block_props.call_deferred()
	for ap in find_children("*", "AnimationPlayer", true, false):  # roulette rotor, slot reels
		for clip in (ap as AnimationPlayer).get_animation_list():
			if String(clip).ends_with("_spin") or String(clip).ends_with("_sway"):
				ap.play(clip)
				ap.seek(randf() * ap.get_animation(clip).length, true)
				break


func _block_props() -> void:
	await get_tree().physics_frame  # floor bodies registered for the ground rays
	var nav := get_node("NavigationRegion3D")
	var space := get_world_3d().direct_space_state
	for p in _solid:
		Footprint.blocker(nav, p[0], p[1], 1.0, space)
	nav.call("rebake")


func camera_for_spawn(_spawn_name: String) -> Dictionary:
	var c: Dictionary = _cfg["camera"]
	return {"center": Vector3(0, 0, 0.3), "limit_x": c["limit_x"], "limit_z": c["limit_z"],
		"height": c["height"], "distance": c["distance"], "yaw_deg": c.get("yaw_deg", 0.0)}


## A seat prop (optional) plus a SeatSpot at every `prefix*` socket of a placed table/cabinet,
## each facing the table centre. games entry: [anchor, seat prop or "", activity, kit, prefix].
func _seats(nav: Node, table: Array, g: Array) -> void:
	var t_node: Node3D = table[0]
	if t_node == null:
		return
	var seat_id: String = g[1]
	var prefix: String = g[4] if g.size() > 4 else "socket_seat"
	var at: Vector3 = table[2]
	var basis := Basis(Vector3.UP, deg_to_rad(table[3]))
	var seat_h := 0.0
	if seat_id != "":
		var ss: Dictionary = AssetRegistry.sockets(seat_id)
		seat_h = float((ss.get("socket_seat", ss.get("socket_seat_0", [0, 0, 0.43])) as Array)[2])
	for sname in AssetRegistry.sockets(table[1]):
		if not String(sname).begins_with(prefix):
			continue
		var floor_pos := at + basis * _socket(AssetRegistry.sockets(table[1]), sname)
		floor_pos.y = at.y
		var away := Vector2(floor_pos.x - at.x, floor_pos.z - at.z)
		var yaw := atan2(away.x, away.y) if away.length() > 0.05 else deg_to_rad(table[3])  # forward -Z faces the table
		if seat_id != "":
			AssetPack.place(nav, seat_id.get_base_dir(), seat_id.get_file(), floor_pos, yaw)
		var seat := _make_seat("%s_%s" % [t_node.name, String(sname).trim_prefix("socket_")], floor_pos, yaw, seat_h, g[3], g[2])
		seat.set_meta("table", t_node)
		var screen_sockets := AssetRegistry.sockets(table[1])
		if screen_sockets.has("socket_screen"):
			seat.set_meta("screen_local", _socket(screen_sockets, "socket_screen"))


## Seats authored in the shell: a seat prop plus a SeatSpot at every socket_<anchor>_seat_<k>,
## facing socket_<anchor>. spec: [seat prop, kit].
func _shell_seats(nav: Node, sockets: Dictionary, spec: Array) -> void:
	var seat_id: String = spec[0]
	var ss: Dictionary = AssetRegistry.sockets(seat_id)
	var seat_h := float((ss.get("socket_seat", [0, 0, 0.43]) as Array)[2])
	for sname in sockets:
		var n := String(sname)
		if not n.contains("_seat_"):
			continue
		var floor_pos := _socket(sockets, n)
		var anchor := n.get_slice("_seat_", 0)
		var at := _socket(sockets, anchor) if sockets.has(anchor) else floor_pos + Vector3(0, 0, -1)
		var away := Vector2(floor_pos.x - at.x, floor_pos.z - at.z)
		var yaw := atan2(away.x, away.y)  # forward -Z faces the anchor
		AssetPack.place(nav, seat_id.get_base_dir(), seat_id.get_file(), floor_pos, yaw)
		_make_seat(n.trim_prefix("socket_"), floor_pos, yaw, seat_h, spec[1], "")


func _make_seat(seat_name: String, floor_pos: Vector3, yaw: float, seat_h: float, kit: String, game: String) -> SeatSpot:
	var seat := SeatSpot.new()
	seat.name = seat_name
	seat.kit = kit
	seat.activity = game
	seat.title = {"pac": "Pac-Man", "tetris": "Tetris", "dino": "Dino Run", "arcade": "Puck Rally"}.get(game, game.capitalize() if game != "" else "")
	seat.verb = "Play" if game != "" else "Sit"
	seat.position = floor_pos
	add_child(seat)
	seat.seat_point = global_transform * (floor_pos + Vector3(0, seat_h, 0))
	seat.face_yaw = global_rotation.y + yaw
	return seat


func _slot_row(nav: Node, shell_id: String, sockets: Dictionary) -> void:
	var row: Dictionary = AssetRegistry.entry(shell_id).get("slot_row", {})
	var seat_h := float((AssetRegistry.sockets("casino/slot_stool").get("socket_seat", [0, 0, 0.43]) as Array)[2])
	for key in row:
		var spec: Dictionary = row[key]
		var machine := _place(nav, spec["asset"], _socket(sockets, "socket_" + key), 0.0)
		if machine and spec.has("tint"):
			var colors := {}
			for role in spec["tint"]:
				colors[role] = Color(spec["tint"][role])
			Tints.apply(machine, colors)
		var stool_at := _socket(sockets, "socket_" + str(spec["stool"]))
		AssetPack.place(nav, "casino", "slot_stool", stool_at, 0.0)
		_make_seat("Slot_%s" % key, stool_at, 0.0, seat_h, "casino", "slots")  # machines face +Z


func _point(sockets: Dictionary, p) -> Vector3:
	return _socket(sockets, p) if p is String else _v(p)


func _place(nav: Node, id: String, at: Vector3, yaw_deg: float) -> Node3D:
	var node := AssetPack.place(nav, id.get_base_dir(), id.get_file(), at, deg_to_rad(yaw_deg))
	if node == null:
		return null
	var s := AssetRegistry.size(id)
	if s.y > 0.3 and s.x * s.z > 0.08:  # anything you'd bump into blocks; rugs and mugs don't
		_solid.append([node, id])
	return node


func _socket(sockets: Dictionary, name: String) -> Vector3:
	var b: Array = sockets.get(name, [0, 0, 0])
	return Vector3(b[0], b[2], -b[1])


func _box(parent: Node, center: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


func _v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])
