extends Node

## Walkability test with the real click-to-walk (penguin.command_walk_to) and physics.
## Town: from the plaza spawn to the far side of every walkable placement (footbridges, docks,
## fishing spots, stairs, courts, sled start). Interiors: from the arrival spawn to every seat.
## Each route asserts: a navmesh path exists, the penguin arrives within 0.5 m, and it never
## drops more than 0.05 m below the floor under it. Prints a results table; exits 1 on failure.
## Run: Godot --path . res://tools/walk_check.tscn -- [--out=/abs/dir/] [--only=town|cinema|...]

const ARRIVE := 0.5
const SINK := 0.05
const TIMEOUT := 15.0

var _w: Node
var _p: CharacterBody3D
var _rows := []


func _ready() -> void:
	var only := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	if only in ["", "town"]:
		await _town()
	for r in [["cinema", "InsideLobby"], ["cinema", "InsideScreen"], ["cafe", "Inside"], ["arcade", "Inside"],
			["casino", "Inside"], ["home", "InsideSpawn"]]:
		if only != "" and only != r[0]:
			continue
		await _interior(r[0], r[1], out)
	var fails := _rows.filter(func(r): return not r[1])
	print("WALK ALL %s (%d routes, %d failed)" % ["PASS" if fails.is_empty() else "FAIL", _rows.size(), fails.size()])
	get_tree().quit(0 if fails.is_empty() else 1)


func _town() -> void:
	await _w.travel_to("town", "BusArrival")
	await get_tree().create_timer(2.0).timeout
	var town: Node = _w.get_node("LocationHost").get_child(0)
	var plaza := _p.global_position
	var nav := town.get_node("NavigationRegion3D")
	for node in nav.get_children():
		if not node.has_meta("walkable"):
			continue
		var target := _far_side(node as Node3D, plaza)
		await _route("town: " + String(node.name), "BusArrival", target)


## Point on the placement's standable top that is farthest from where we came from.
func _far_side(node: Node3D, from: Vector3) -> Vector3:
	var ends := node.find_children("socket_end_*", "Node3D", true, false)
	if not ends.is_empty():
		ends.sort_custom(func(a, b): return a.global_position.distance_to(from) > b.global_position.distance_to(from))
		return (ends[0] as Node3D).global_position
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var away := Vector3(c.x - from.x, 0, c.z - from.z).normalized()
	# step in from the far edge by 0.6 m so the target is on the deck, not past it
	var half := Vector3(box.size.x, 0, box.size.z) * 0.5
	return c + away * maxf(0.0, minf(absf(half.x / maxf(absf(away.x), 0.01)), absf(half.z / maxf(absf(away.z), 0.01))) - 0.6)


func _interior(loc: String, spawn: String, out: String) -> void:
	await _w.travel_to(loc, spawn)
	await get_tree().create_timer(2.0).timeout
	var room: Node = _w.get_node("LocationHost").get_child(0)
	var at := (room.get_node(spawn) as Node3D).global_position
	var seats := room.find_children("*", "", true, false).filter(
		func(n): return n is SeatSpot and Vector2(n.seat_point.x - at.x, n.seat_point.z - at.z).length() < 14.0)
	for s in seats:
		await _route("%s/%s: %s" % [loc, spawn, s.name], spawn, s.seat_point, true)
	if out != "" and loc == "cinema" and spawn == "InsideScreen":  # penguin standing on the tiers
		var tier := seats.filter(func(s): return s.seat_point.y > 0.6)
		if not tier.is_empty():
			var map := _p.get_world_3d().navigation_map
			_p.command_walk_to(NavigationServer3D.map_get_closest_point(map, tier[0].seat_point))
			await get_tree().create_timer(4.0).timeout
			for c in _w.find_children("*", "CanvasLayer", true, false):
				c.visible = false
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out + "walk_cinema_tiers.png")
			for c in _w.find_children("*", "CanvasLayer", true, false):
				c.visible = true


## Walk from `spawn` toward `target`; seats count as reached at the nearest walkable point.
func _route(label: String, spawn: String, target: Vector3, to_seat := false) -> void:
	await _w.shift_to_marker(spawn)
	await get_tree().create_timer(0.5).timeout
	var map := _p.get_world_3d().navigation_map
	var goal := NavigationServer3D.map_get_closest_point(map, target)
	var off := Vector2(goal.x - target.x, goal.z - target.z).length()
	if not to_seat and off > 1.0:
		_log([label, false, "target %.1fm off the navmesh" % off])
		return
	if to_seat and off > 1.3:
		_log([label, false, "no walkable floor within 1.3 m of the seat"])
		return
	var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, _p.global_position), goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > 0.3:
		_log([label, false, "no navmesh path"])
		return
	_p.command_walk_to(goal)
	var t := 0.0
	var worst := 0.0
	while t < TIMEOUT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var fy := _floor_y(_p.global_position)
		if not is_nan(fy):
			worst = maxf(worst, fy - _p.global_position.y)
		if Vector2(_p.global_position.x - goal.x, _p.global_position.z - goal.z).length() < ARRIVE and _p.velocity.length() < 0.2:
			break
	var dist := Vector2(_p.global_position.x - goal.x, _p.global_position.z - goal.z).length()
	var ok := dist < ARRIVE and worst <= SINK
	_log([label, ok, "arrived %.2fm in %.1fs, max sink %.2fm, y=%.2f" % [dist, t, worst, _p.global_position.y]])


func _log(row: Array) -> void:
	_rows.append(row)
	print("WALK | %-44s | %s | %s" % [row[0], "PASS" if row[1] else "FAIL", row[2]])


func _floor_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 3.0, 1)
	q.exclude = [_p.get_rid()]
	var hit := _p.get_world_3d().direct_space_state.intersect_ray(q)
	return NAN if hit.is_empty() else hit.position.y
