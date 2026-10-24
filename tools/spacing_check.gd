extends Node

## Interior Spacing Standard checks (vault: Art Docs/Interior Spacing Standard.md).
## For every interior: no two seats closer than 1.15 m (centre to centre, ground plane), and a
## navmesh route (agent radius 0.5 m, room_nav.gd) from the arrival spawn to a walkable spot
## within reach of every seat. Saves a top-down shot with a 0.98 m penguin footprint at each
## seat to --out=<dir>/spacing_<room>.png.
## Run: Godot --path . res://tools/spacing_check.tscn -- --out=/abs/dir/
## Prints "SPACING <room> PASS|FAIL ..." per room and "SPACING ALL PASS|FAIL"; exits 1 on failure.

const ROOMS := [["cafe", "Inside"], ["arcade", "Inside"], ["casino", "Inside"],
	["cinema", "InsideLobby"], ["cinema", "InsideScreen"], ["home", "InsideSpawn"]]
const MIN_PITCH := 1.15
const REACH := 1.3  # a seat counts as reachable if walkable floor lies within this of it
const FOOTPRINT := 0.49  # half of the 0.98 m penguin


func _ready() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	var all_ok := true
	for r in ROOMS:
		await w.travel_to(r[0], r[1])
		await get_tree().create_timer(2.0).timeout
		var room: Node3D = w.get_node("LocationHost").get_child(0)
		var tag: String = r[0] + ("_hall" if r[1] == "InsideScreen" else "")
		var seats := _seats_near(room, (room.get_node(r[1]) as Node3D).global_position)
		var problems := []
		for i in seats.size():
			for j in range(i + 1, seats.size()):
				var d := _flat(seats[i].seat_point).distance_to(_flat(seats[j].seat_point))
				if d < MIN_PITCH:
					problems.append("%s~%s %.2fm" % [seats[i].name, seats[j].name, d])
		var map := (w.get_node("Penguin") as Node3D).get_world_3d().navigation_map
		var start := NavigationServer3D.map_get_closest_point(map, (room.get_node(r[1]) as Node3D).global_position)
		for s in seats:
			var goal := NavigationServer3D.map_get_closest_point(map, s.seat_point)
			var path := NavigationServer3D.map_get_path(map, start, goal, true)
			if _flat(goal).distance_to(_flat(s.seat_point)) > REACH:
				problems.append("%s no floor within %.1fm" % [s.name, REACH])
			elif path.is_empty() or path[path.size() - 1].distance_to(goal) > 0.3:
				problems.append("%s unreachable from %s" % [s.name, r[1]])
		print("SPACING %s %s seats=%d %s" % [tag, "PASS" if problems.is_empty() else "FAIL", seats.size(), problems.slice(0, 12)])
		all_ok = all_ok and problems.is_empty()
		await _shot(w, room, seats, r[1], out + "spacing_%s.png" % tag)
	print("SPACING ALL ", "PASS" if all_ok else "FAIL")
	get_tree().quit(0 if all_ok else 1)


## Seats of the part of the room around this spawn (the cinema scene holds lobby and hall).
func _seats_near(room: Node, at: Vector3) -> Array:
	return room.find_children("*", "", true, false).filter(
		func(n): return n is SeatSpot and _flat(n.seat_point).distance_to(_flat(at)) < 14.0)


func _shot(w: Node, room: Node3D, seats: Array, spawn: String, path: String) -> void:
	var marks := Node3D.new()
	room.add_child(marks)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.3, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var centre := (room.get_node(spawn) as Node3D).global_position
	for s in seats:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = FOOTPRINT
		cyl.bottom_radius = FOOTPRINT
		cyl.height = 0.02
		cyl.material = mat
		disc.mesh = cyl
		marks.add_child(disc)
		disc.global_position = s.seat_point + Vector3(0, 0.05, 0)
		centre += (s.seat_point - centre) / 2.0
	for c in w.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	w.get_node("Penguin").visible = false
	var rig: Node3D = w.get_node("CameraRig")
	rig.set_process(false)
	var cam: Camera3D = rig.get_node("Camera3D")
	cam.global_position = centre + Vector3(0, 16, 0.01)
	cam.look_at(centre, Vector3.FORWARD)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	marks.queue_free()
	rig.set_process(true)
	w.get_node("Penguin").visible = true
	for c in w.find_children("*", "CanvasLayer", true, false):
		c.visible = true


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
