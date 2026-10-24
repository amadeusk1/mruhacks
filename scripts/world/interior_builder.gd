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
		],
		# seats authored in the shell to the Interior Spacing Standard: socket_<anchor>_seat_<k> faces socket_<anchor>
		"shell_seats": ["plaza/stool", "stool"],
		"camera": {"limit_x": 3.0, "limit_z": 2.4, "height": 9.0, "distance": 7.4},
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
			["casino/lounge_chair", "socket_lounge_0", 30.0],
			["casino/lounge_chair", "socket_lounge_1", -30.0],
			["casino/side_table", [-4.6, 0.12, 2.6], 0.0],
			["casino/side_table", [4.6, 0.12, 2.6], 0.0],
			["casino/standing_lamp", [-4.7, 0.12, -3.6], 0.0],
			["casino/standing_lamp", [4.7, 0.12, -3.6], 0.0],
			["casino/casino_planter", [-4.7, 0.12, 0.3], 0.0],
			["casino/coat_stand", [3.6, 0.12, 2.7], 0.0],
		],
		# [table placement anchor, seat prop, game, seat height]; seats come from the table's socket_seat_*
		"games": [["socket_roulette", "casino/roulette_stool", "roulette", "casino"], ["socket_poker", "casino/casino_chair", "poker", "casino"],
			["socket_blackjack", "casino/casino_chair", "blackjack", "casino"],
			["socket_lounge_0", "", "", "armchair", "socket_seat"], ["socket_lounge_1", "", "", "armchair", "socket_seat"]],
		"slot_row": true,  # machines, stools and tints from the shell's slot_row meta
		"lights": [[-4.7, 1.6, -3.6], [4.7, 1.6, -3.6], [0.0, 2.6, 0.0]],
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
		],
		"games": [["socket_cabinet_solo_0", "", "pac", "arcade", "socket_player"], ["socket_cabinet_solo_1", "", "tetris", "arcade", "socket_player"],
			["socket_cabinet_solo_2", "", "dino", "arcade", "socket_player"], ["socket_cabinet_solo_3", "", "tetris", "arcade", "socket_player"],
			["socket_cabinet_solo_4", "", "pac", "arcade", "socket_player"], ["socket_cabinet_duo", "", "arcade", "arcade", "socket_player"]],
		"tints": {"socket_cabinet_solo_0": {"body": "#7B4FC4"}, "socket_cabinet_solo_1": {"body": "#3FB3B5"},
			"socket_cabinet_solo_2": {"body": "#D9473B"}, "socket_cabinet_solo_3": {"body": "#E3A92B"},
			"socket_cabinet_solo_4": {"body": "#3D7BD9"}},
		"lights": [[-3.2, 2.4, -2.6], [1.6, 2.4, -2.6], [0.0, 2.6, 1.6]],
		"camera": {"limit_x": 3.0, "limit_z": 2.2, "height": 9.0, "distance": 7.4},
	},
}

var _cfg: Dictionary


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
	WalkSurface.build(shell, nav, shell.position.y - 0.3, "ShellWalk")  # raised floors, steps
	if _cfg.has("cut_front"):
		_cut_front(shell, size.z * 0.5 - float(_cfg["cut_front"]))
	var inner = AssetRegistry.entry(shell_id).get("interior_m", null)  # floor size; the bbox includes plinth and awning
	var room := Vector3(float(inner[0]), size.y, float(inner[1])) if inner is Array else size
	var pad := 0.1 if inner is Array else 0.0  # interior_m walls sit just outside the floor
	var y: float = _cfg["floor_y"]
	_box(nav, Vector3(0, y - 0.05, 0), Vector3(room.x, 0.1, room.z), 1)
	var sockets: Dictionary = AssetRegistry.sockets(shell_id)
	var exit := _point(sockets, _cfg["exit"])
	for side in [-1, 1]:  # side and back walls (layer 2 carves the navmesh); the front stays open
		_box(nav, Vector3(side * (room.x * 0.5 + pad), 1.0, 0), Vector3(0.2, 2.0, room.z), 2)
	_box(nav, Vector3(0, 1.0, -(room.z * 0.5 + pad)), Vector3(room.x, 2.0, 0.2), 2)
	var placed := {}
	for p in _cfg["props"]:
		var at := _socket(sockets, p[1]) if p[1] is String else _v(p[1])
		var node := _place(nav, p[0], at, p[2])
		if p[1] is String:
			placed[p[1]] = [node, p[0], at, p[2]]
		var tints: Dictionary = _cfg.get("tints", {}).get(str(p[1]), {})
		if node and not tints.is_empty():
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
func _cut_front(shell: Node3D, z_cut: float) -> void:
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
					in_front = in_front and v.z >= z_cut
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


func _ready() -> void:
	AmbientFx.dress(self)  # steam on the coffee station and mugs; no snow indoors
	for ap in find_children("*", "AnimationPlayer", true, false):  # roulette rotor, slot reels
		for clip in (ap as AnimationPlayer).get_animation_list():
			if String(clip).ends_with("_spin") or String(clip).ends_with("_sway"):
				ap.play(clip)
				ap.seek(randf() * ap.get_animation(clip).length, true)
				break


func camera_for_spawn(_spawn_name: String) -> Dictionary:
	var c: Dictionary = _cfg["camera"]
	return {"center": Vector3(0, 0, 0.3), "limit_x": c["limit_x"], "limit_z": c["limit_z"],
		"height": c["height"], "distance": c["distance"]}


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
		var b := _box(nav, at + Vector3(0, s.y * 0.5, 0), s, 2)
		b.rotation.y = deg_to_rad(yaw_deg)
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
