extends Node

## Town collision check. Run after every layout change (one command, headless is fine):
##   Godot --headless --path . res://tools/walk_test.tscn -- --out=/abs/dir/
## From the plaza it click-walks to every door, activity, queue and spawn marker, both ends of
## every walkable placement (bridge and pier ends, stair tops and bottoms, courts, decks), a ring
## round the plaza and 60 random reachable navmesh points; then repeats each route with WASD-style
## direct input (or follows the "paths" polylines in town_layout.json when present); then walks
## diagonally into fences, walls and buildings, which must glide, not stick.
## Stuck: moved under 0.1 m in 1 s while input is held. Unreachable: no navmesh route.
## Prints "WALK_TEST stuck=N unreachable=M", then each stuck point with the nearest placement id,
## and draws them on ui/map/town_map.png -> <out>/walk_test.png. Exits 1 unless both are zero.

const STUCK_SPEED := 0.1
const STUCK_TIME := 1.0
const TIMEOUT := 30.0
const RANDOM_POINTS := 60
const SLIDE_PROBES := 24
const ARRIVE := 0.6

var _w: Node
var _p: CharacterBody3D
var _town: Node
var _map: RID
var _stuck := []  # [label, position, nearest asset]
var _rows := []   # [label, ok, note]


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://art/_wip/")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	out = out.path_join("walk_test.png")
	seed(7)
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	await _w.travel_to("town", "BusArrival")
	await get_tree().create_timer(2.0).timeout
	_town = _w.get_node("LocationHost").get_child(0)
	_map = _p.get_world_3d().navigation_map
	Engine.physics_ticks_per_second = 240  # same 1/60 s step, four times the wall-clock speed
	Engine.time_scale = 4.0
	var targets := _targets()
	for t in targets:
		await _click(t[0], t[1])
	var lines := _paths(targets)
	for l in lines:
		await _wasd(l[0], l[1])
	for probe in _slide_probes():
		await _slide(probe[0], probe[1], probe[2])
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	var unreachable := _rows.filter(func(r): return not r[1] and String(r[2]).begins_with("UNREACHABLE"))
	var by_asset := {}
	for s in _stuck:
		by_asset[s[2]] = by_asset.get(s[2], 0) + 1
	_draw(out)
	print("WALK_TEST stuck=%d unreachable=%d routes=%d image=%s" % [_stuck.size(), unreachable.size(), _rows.size(), out])
	for s in _stuck:
		print("WALK_TEST stuck at (%.1f, %.1f, %.1f) near %s  [%s]" % [s[1].x, s[1].y, s[1].z, s[2], s[0]])
	for r in unreachable:
		print("WALK_TEST unreachable %s  %s" % [r[0], r[2]])
	print("WALK_TEST stuck by placement: ", by_asset)
	get_tree().quit(0 if unreachable.is_empty() and _stuck.is_empty() else 1)


func _targets() -> Array:
	var list := []
	for m in _town.get("_layout").get("markers", []):
		if m["kind"] in ["door", "activity", "queue", "spawn"]:
			var p: Array = m["pos"]
			list.append([String(m["name"]), Vector3(p[0], p[1], p[2])])
	var plaza := _p.global_position
	for node in _town.get_node("NavigationRegion3D").get_children():
		if node.has_meta("walkable"):
			var tag := "%s@%.0f,%.0f" % [node.name if not String(node.name).begins_with("@") else "walkable", node.global_position.x, node.global_position.z]
			var ends := node.find_children("socket_end_*", "Node3D", true, false) + node.find_children("socket_top", "Node3D", true, false) \
					+ node.find_children("socket_bottom", "Node3D", true, false)
			for e in ends:
				list.append(["%s %s" % [tag, e.name], (e as Node3D).global_position])
			if ends.is_empty():
				list.append([tag + " far", _far_side(node, plaza)])
				list.append([tag + " near", _far_side(node, plaza + 2.0 * (node.global_position - plaza))])
	var zone: Dictionary = _town.get("_layout").get("zones", [{}])[0]
	var c: Array = zone.get("center", [0, 0, 0])
	var ring := float(zone.get("radius", 9.5)) - 1.0
	for i in 12:
		var a := TAU * i / 12.0
		list.append(["plaza ring %d" % i, Vector3(c[0] + cos(a) * ring, c[1], c[2] + sin(a) * ring)])
	var start := NavigationServer3D.map_get_closest_point(_map, plaza)
	var tries := 0
	var n := 0
	while n < RANDOM_POINTS and tries < 400:
		tries += 1
		var q := NavigationServer3D.map_get_random_point(_map, 1, false)
		var path := NavigationServer3D.map_get_path(_map, start, q, true)
		if path.is_empty() or path[path.size() - 1].distance_to(q) > 0.3 or q.distance_to(plaza) > 60.0:
			continue
		list.append(["random %d" % n, q])
		n += 1
	return list


## Bridges, piers and stairs: the end socket farthest from the plaza, else the far edge of the mesh.
func _far_side(node: Node3D, from: Vector3) -> Vector3:
	var ends := node.find_children("socket_end_*", "Node3D", true, false) + node.find_children("socket_top", "Node3D", true, false)
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
	var half := Vector3(box.size.x, 0, box.size.z) * 0.5
	return c + away * maxf(0.0, minf(absf(half.x / maxf(absf(away.x), 0.01)), absf(half.z / maxf(absf(away.z), 0.01))) - 0.6)


## Path polylines from the layout, else the navmesh route from the plaza to each target.
func _paths(targets: Array) -> Array:
	var lines := []
	for path in _town.get("_layout").get("paths", []):
		var pts := PackedVector3Array()
		for q in path["points"]:
			pts.append(NavigationServer3D.map_get_closest_point(_map, Vector3(q[0], q[1], q[2])))
		lines.append(["path " + str(path.get("name", lines.size())), pts])
	if lines.is_empty():
		var start := NavigationServer3D.map_get_closest_point(_map, _marker("BusArrival"))
		for t in targets:
			var pts := NavigationServer3D.map_get_path(_map, start, NavigationServer3D.map_get_closest_point(_map, t[1]), true)
			if pts.size() > 1:
				lines.append(["wasd " + t[0], pts])
	return lines


func _click(label: String, target: Vector3) -> void:
	await _w.shift_to_marker("BusArrival")
	await get_tree().create_timer(0.3).timeout
	var goal := NavigationServer3D.map_get_closest_point(_map, target)
	if Vector2(goal.x - target.x, goal.z - target.z).length() > 1.5:
		_rows.append([label, false, "UNREACHABLE: (%.1f, %.1f, %.1f) is %.1fm off the navmesh" % [target.x, target.y, target.z, Vector2(goal.x - target.x, goal.z - target.z).length()]])
		_log(_rows.back())
		return
	var path := NavigationServer3D.map_get_path(_map, NavigationServer3D.map_get_closest_point(_map, _p.global_position), goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > 0.3:
		_rows.append([label, false, "UNREACHABLE: no navmesh route to (%.1f, %.1f, %.1f)" % [goal.x, goal.y, goal.z]])
		_log(_rows.back())
		return
	_p.command_walk_to(goal)
	await _watch("click " + label, func(): return _p.get("_click_active"), goal)


## Direct input along a polyline, steering at the next corner like a player holding WASD.
func _wasd(label: String, pts: PackedVector3Array) -> void:
	_p.global_position = pts[0] + Vector3.UP * 0.1
	_p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	var state := {"i": 1}
	var steer := func() -> bool:
		while state.i < pts.size() and Vector2(pts[state.i].x - _p.global_position.x, pts[state.i].z - _p.global_position.z).length() < 0.4:
			state.i += 1
		_press(Vector3.ZERO if state.i >= pts.size() else pts[state.i] - _p.global_position)
		return state.i < pts.size()
	await _watch("wasd " + label.trim_prefix("wasd "), steer, pts[pts.size() - 1])
	_press(Vector3.ZERO)


## Runs until `active` returns false or TIMEOUT; logs the route and any stuck event.
func _watch(label: String, active: Callable, goal: Vector3) -> void:
	var t := 0.0
	var stuck_at := Vector3.INF
	var trail := []  # [time, position]: real ground speed, not the commanded velocity
	while t < TIMEOUT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not active.call():
			break
		trail.append([t, _p.global_position])
		while trail[0][0] < t - STUCK_TIME:
			trail.pop_front()
		var moved := Vector2(_p.global_position.x - trail[0][1].x, _p.global_position.z - trail[0][1].z).length()
		if t > STUCK_TIME + 0.3 and t - trail[0][0] >= STUCK_TIME - 0.05 and moved < STUCK_SPEED * STUCK_TIME:
			stuck_at = _p.global_position
			break
	var dist := Vector2(_p.global_position.x - goal.x, _p.global_position.z - goal.z).length()
	if stuck_at != Vector3.INF:
		var asset := _nearest_asset(stuck_at)
		_stuck.append([label, stuck_at, asset])
		_rows.append([label, false, "STUCK at (%.1f, %.1f, %.1f) by %s" % [stuck_at.x, stuck_at.y, stuck_at.z, asset]])
	else:
		_rows.append([label, dist < ARRIVE, "ended %.2fm from goal in %.1fs" % [dist, t]])
	_log(_rows.back())
	if _p.get("_click_active"):
		_p.call("_cancel_click")


## Fences, walls, rails, cliffs and buildings: stand next to one and hold a direction 45 degrees
## into it. The capsule must glide along (at least 0.6 m in 1.5 s), not stop dead.
func _slide_probes() -> Array:
	var out := []
	var nav := _town.get_node("NavigationRegion3D")
	var bodies := nav.get_children().filter(func(n): return n.has_meta("blocker_of") and (["fence", "wall", "rail", "cliff", "exterior", "edge"] as Array).any(func(k): return String(n.get_meta("blocker_of")).contains(k)))
	bodies.shuffle()
	for b in bodies:
		if out.size() >= SLIDE_PROBES:
			break
		var at := NavigationServer3D.map_get_closest_point(_map, (b as Node3D).global_position)
		var into := Vector3((b as Node3D).global_position.x - at.x, 0, (b as Node3D).global_position.z - at.z)
		if into.length() < 0.2 or into.length() > 6.0:
			continue
		var path := NavigationServer3D.map_get_path(_map, NavigationServer3D.map_get_closest_point(_map, _marker("BusArrival")), at, true)
		if path.is_empty() or path[path.size() - 1].distance_to(at) > 0.3:
			continue
		out.append(["slide %s@%.0f,%.0f" % [b.get_meta("blocker_of"), at.x, at.z], at, into.normalized().rotated(Vector3.UP, PI / 4.0)])
	return out


func _slide(label: String, at: Vector3, dir: Vector3) -> void:
	_p.global_position = at + Vector3.UP * 0.1
	_p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	var start := _p.global_position
	var t := 0.0
	while t < 1.5:
		_press(dir)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_press(Vector3.ZERO)
	var moved := Vector2(_p.global_position.x - start.x, _p.global_position.z - start.z).length()
	if moved < 0.6:
		var asset := _nearest_asset(_p.global_position)
		_stuck.append([label, _p.global_position, asset])
		_rows.append([label, false, "STUCK sliding: moved %.2fm along %s" % [moved, asset]])
	else:
		_rows.append([label, true, "glided %.2fm" % moved])
	_log(_rows.back())


func _press(dir: Vector3) -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var cam := get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	var right := cam.global_transform.basis.x
	right.y = 0.0
	dir = dir.normalized()
	var x := dir.dot(right.normalized())
	var y := dir.dot(fwd.normalized())
	var m := maxf(absf(x), absf(y))  # full stick deflection along the dominant axis
	x /= m
	y /= m
	if x > 0.0: Input.action_press("move_right", x)
	if x < 0.0: Input.action_press("move_left", -x)
	if y > 0.0: Input.action_press("move_forward", y)
	if y < 0.0: Input.action_press("move_back", -y)


## Name of the blocker or walkable placement nearest the stuck point (layer 1 or 2, within 1 m).
func _nearest_asset(at: Vector3) -> String:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.5)
	q.collision_mask = 3
	q.exclude = [_p.get_rid()]
	var best := "terrain"
	var best_d := INF
	for hit in _p.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var n: Node = hit.collider
		var name := String(n.get_meta("blocker_of", ""))
		if name == "":
			name = String(n.get_parent().name) + "/" + String(n.name)
		if name.contains("terrain"):
			continue
		var d := (n as Node3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = name
	return best


func _marker(name: String) -> Vector3:
	return (_town.get_node(name) as Node3D).global_position


func _log(row: Array) -> void:
	print("WALK_TEST | %-40s | %s | %s" % [row[0], "PASS" if row[1] else "FAIL", row[2]])


## Stuck points (red) and failed-route goals (amber) over the overhead town map.
func _draw(out: String) -> void:
	var img := Image.load_from_file("res://ui/map/town_map.png")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ui/map/town_map.json"))
	var lo := Vector2(meta["min"][0], meta["min"][1])
	var hi := Vector2(meta["max"][0], meta["max"][1])
	var px := func(p: Vector3) -> Vector2i:
		return Vector2i(int((p.x - lo.x) / (hi.x - lo.x) * img.get_width()), int((p.z - lo.y) / (hi.y - lo.y) * img.get_height()))
	for s in _stuck:
		_dot(img, px.call(s[1]), 14, Color(0.95, 0.15, 0.15))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)


func _dot(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x, y).length()
			if d <= r and d >= r - 4 or d <= 4:
				var q := c + Vector2i(x, y)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, col)
