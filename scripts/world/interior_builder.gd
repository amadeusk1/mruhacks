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
		"spawn": [0.2, 0.0, 1.35], "exit": [0.2, 0.0, 2.45],
		"props": [
			["cafe/cafe_counter", "socket_counter", 0.0],
			["cafe/coffee_station", "socket_coffee_station", 0.0],
			["cafe/menu_board", "socket_menu_board", 0.0],
			["cafe/wall_shelf", "socket_wall_shelf", 0.0],
			["plaza/round_table", "socket_table_0", 0.0],
			["plaza/round_table", "socket_table_1", 0.0],
			["cafe/pastry_case", [0.3, 1.05, -0.35], 0.0],
			["cafe/mug_set", [1.25, 1.03, -0.35], 0.0],
			["cafe/tray_breakfast_preset_preview", [-1.3, 0.7, -0.55], 15.0],
		],
		"seats": [["plaza/stool", "socket_table_0", [[0.55, 0], [-0.55, 0]]], ["plaza/stool", "socket_table_1", [[0.55, 0], [-0.55, 0]]]],
		"camera": {"limit_x": 1.4, "limit_z": 1.2, "height": 6.6, "distance": 5.4},
	},
	"arcade": {
		"shell": "arcade/arcade_shell",
		"town_spawn": "ArcadeDoorOut",
		"floor_y": 0.02,
		"spawn": [0.0, 0.0, 1.7], "exit": [0.0, 0.0, 3.2],
		"cut_front": 1.0,  # the shell has no *_cutaway child: trim its front wall at load
		"props": [
			["arcade/arcade_cabinet", "socket_cabinet_0", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_1", 0.0],
			["arcade/arcade_cabinet_duo", "socket_cabinet_3", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_5", 0.0],
			["arcade/arcade_cabinet", "socket_cabinet_6", 0.0],
			["arcade/token_machine", "socket_token_machine", -90.0],
			["arcade/arcade_rug", [0.0, 0.035, 0.4], 0.0],
			["arcade/arcade_bench", [-2.4, 0.0, 1.1], 90.0],
			["arcade/arcade_stool", [-1.6, 0.0, -0.9], 0.0],
		],
		"tints": {"socket_cabinet_0": {"body": "#7B4FC4"}, "socket_cabinet_1": {"body": "#207D85"},
			"socket_cabinet_5": {"body": "#D9473B"}, "socket_cabinet_6": {"body": "#F2C230"}},
		"camera": {"limit_x": 2.2, "limit_z": 1.6, "height": 8.0, "distance": 6.6},
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
	for n in shell.find_children("*_cutaway", "", true, false):  # camera looks in through the front
		(n as Node3D).visible = false
	var size := AssetRegistry.size(shell_id)
	if _cfg.has("cut_front"):
		_cut_front(shell, size.z * 0.5 - float(_cfg["cut_front"]))
	var y: float = _cfg["floor_y"]
	_box(nav, Vector3(0, y - 0.05, 0), Vector3(size.x, 0.1, size.z), 1)
	var exit := _v(_cfg["exit"])
	for side in [-1, 1]:  # side and back walls (layer 2 carves the navmesh); the front stays open
		_box(nav, Vector3(side * size.x * 0.5, 1.0, 0), Vector3(0.2, 2.0, size.z), 2)
	_box(nav, Vector3(0, 1.0, -size.z * 0.5), Vector3(size.x, 2.0, 0.2), 2)
	var sockets: Dictionary = AssetRegistry.sockets(shell_id)
	for p in _cfg["props"]:
		var at := _socket(sockets, p[1]) if p[1] is String else _v(p[1])
		var node := _place(nav, p[0], at, p[2])
		var tints: Dictionary = _cfg.get("tints", {}).get(str(p[1]), {})
		if node and not tints.is_empty():
			Tints.apply(node, {"body": Color(tints["body"])})
	for s in _cfg.get("seats", []):
		var base := _socket(sockets, s[1])
		for off in s[2]:
			_place(nav, s[0], base + Vector3(off[0], 0, off[1]), 0.0)
	var spawn := Marker3D.new()
	spawn.name = "Inside"
	spawn.position = _v(_cfg["spawn"])
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


func camera_for_spawn(_spawn_name: String) -> Dictionary:
	var c: Dictionary = _cfg["camera"]
	return {"center": Vector3(0, 0, 0.3), "limit_x": c["limit_x"], "limit_z": c["limit_z"],
		"height": c["height"], "distance": c["distance"]}


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
