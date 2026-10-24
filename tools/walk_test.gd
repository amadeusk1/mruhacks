extends Node

## Collision check for the town and every interior. Run after every layout or room change
## (one command, headless is fine):
##   Godot --headless --path . res://tools/walk_test.tscn -- --out=/abs/dir/ [--only=town,cafe,...]
## Rooms: town, cafe, arcade, casino, cinema (lobby), cinema_hall, home.
## Per room, from its arrival spawn:
##  - click-to-walk to every target, then the same route again with WASD-style direct input.
##    Town targets: every door, activity, queue and spawn marker, both ends of every walkable
##    placement (bridge and pier ends, stair tops and bottoms, courts, decks), a ring round the
##    plaza, 60 random reachable navmesh points, and the "paths" polylines in town_layout.json.
##    Interior targets: every seat's approach, every interactable, 15 random navmesh points.
##  - slide: hold a direction 45 degrees into fences, walls, rails and props. It must glide.
##  - pass-through: drive straight into every blocking prop (and, indoors, every wall from the
##    spawn; outdoors, off every pier end). The penguin must never end inside the inner half of a
##    prop's footprint, off the walkable navmesh, or in the water.
## Stuck: moved under 0.1 m in 1 s while input is held. Unreachable: no navmesh route.
## Prints "WALK_TEST <room> stuck=N passthrough=P unreachable=M" per room, a total line
## "WALK_TEST stuck=N passthrough=P unreachable=M", each failure with the nearest placement id,
## and draws the town's failure points on ui/map/town_map.png -> <out>/walk_test.png.
## Exits 1 unless all three totals are zero. Add --verbose to print passing routes too.

const STUCK_SPEED := 0.1
const STUCK_TIME := 1.0
const TIMEOUT := 30.0
const ARRIVE := 0.6
const OFF_NAV := 0.45  # standing this far from the navmesh means the penguin got through something
const ROOMS := [["town", "town", "BusArrival"], ["cafe", "cafe", "Inside"], ["arcade", "arcade", "Inside"],
	["casino", "casino", "Inside"], ["cinema", "cinema", "InsideLobby"], ["cinema_hall", "cinema", "InsideScreen"],
	["home", "home", "InsideSpawn"]]

var _w: Node
var _p: CharacterBody3D
var _room: Node
var _room_name := ""
var _spawn := ""
var _map: RID
var _fails := []  # [room, kind (stuck|passthrough|unreachable), label, position, nearest]
var _rows := 0


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://art/_wip/")
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	seed(7)
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	_map = _p.get_world_3d().navigation_map
	for r in ROOMS:
		if not only.is_empty() and not only.has(r[0]):
			continue
		_room_name = r[0]
		_spawn = r[2]
		await _w.travel_to(r[1], r[2])
		await get_tree().create_timer(2.0).timeout  # let the room build and bake at normal speed
		_room = _w.get_node("LocationHost").get_child(0)
		for area in _room.find_children("*", "Area3D", true, false):  # walk-in exits would end the test
			if area.get_script() and String(area.get_script().resource_path).ends_with("doorway.gd"):
				area.set_deferred("monitoring", false)
		Engine.physics_ticks_per_second = 240  # same 1/60 s step, four times the wall-clock speed
		Engine.time_scale = 4.0
		await _test_room()
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = 60
	var totals := {"stuck": 0, "passthrough": 0, "unreachable": 0}
	for r in ROOMS:
		if not only.is_empty() and not only.has(r[0]):
			continue
		var c := {"stuck": 0, "passthrough": 0, "unreachable": 0}
		for f in _fails:
			if f[0] == r[0]:
				c[f[1]] += 1
				totals[f[1]] += 1
		print("WALK_TEST %s stuck=%d passthrough=%d unreachable=%d" % [r[0], c.stuck, c.passthrough, c.unreachable])
	for f in _fails:
		print("WALK_TEST %s %s at (%.1f, %.1f, %.1f) near %s  [%s]" % [f[0], f[1], f[3].x, f[3].y, f[3].z, f[4], f[2]])
	if only.is_empty() or only.has("town"):
		_draw(out.path_join("walk_test.png"))
	print("WALK_TEST stuck=%d passthrough=%d unreachable=%d routes=%d" % [totals.stuck, totals.passthrough, totals.unreachable, _rows])
	get_tree().quit(0 if totals.values().all(func(v): return v == 0) else 1)


func _test_room() -> void:
	var targets := _town_targets() if _room_name == "town" else _interior_targets()
	for t in targets:
		await _click(t[0], t[1], t[2] if t.size() > 2 else 1.0)
	for l in _lines(targets):
		await _wasd(l[0], l[1])
	for probe in _slide_probes():
		await _slide(probe[0], probe[1], probe[2])
	for probe in _drive_probes():
		await _drive(probe[0], probe[1], probe[2], probe[3])


# ------------------------------------------------------------------ targets --

func _town_targets() -> Array:
	var list := []
	for m in _room.get("_layout").get("markers", []):
		if m["kind"] in ["door", "activity", "queue", "spawn"]:
			var p: Array = m["pos"]
			# doors and activities trigger within Interactable.reach (2.2 m) of the marker
			list.append([String(m["name"]), Vector3(p[0], p[1], p[2]), 1.9 if m["kind"] in ["door", "activity"] else 1.0])
	var plaza := _marker(_spawn)
	for node in _nav().get_children():
		if node.has_meta("walkable"):
			var tag := _tag(node)
			var ends := node.find_children("socket_end_*", "Node3D", true, false) + node.find_children("socket_top", "Node3D", true, false) \
					+ node.find_children("socket_bottom", "Node3D", true, false)
			for e in ends:
				list.append(["%s %s" % [tag, e.name], (e as Node3D).global_position])
			if ends.is_empty():
				list.append([tag + " far", _far_side(node, plaza)])
				list.append([tag + " near", _far_side(node, plaza + 2.0 * (node.global_position - plaza))])
	var zone: Dictionary = _room.get("_layout").get("zones", [{}])[0]
	var c: Array = zone.get("center", [0, 0, 0])
	var ring := float(zone.get("radius", 9.5)) - 1.0
	for i in 12:
		var a := TAU * i / 12.0
		list.append(["plaza ring %d" % i, Vector3(c[0] + cos(a) * ring, c[1], c[2] + sin(a) * ring)])
	return list + _random_points(60, plaza, 60.0)


func _interior_targets() -> Array:
	var at := _marker(_spawn)
	var list := []
	for s in _room.find_children("*", "", true, false):
		if s is SeatSpot and _flat(s.seat_point - at) < 14.0:
			var stand = s.get("stand_point")
			list.append(["seat " + String(s.name), stand if stand is Vector3 and stand != Vector3.INF and stand != Vector3.ZERO else s.seat_point, 1.3])
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is Node3D and _room.is_ancestor_of(n) and not (n is SeatSpot) and _flat((n as Node3D).global_position - at) < 14.0:
			list.append(["use " + String(n.name), (n as Node3D).global_position, 1.9])
	return list + _random_points(15, at, 14.0)


func _random_points(count: int, from: Vector3, radius: float) -> Array:
	var list := []
	var start := NavigationServer3D.map_get_closest_point(_map, from)
	var tries := 0
	while list.size() < count and tries < 600:
		tries += 1
		var q := NavigationServer3D.map_get_random_point(_map, 1, false)
		if _flat(q - from) > radius or not _reaches(start, q):
			continue
		list.append(["random %d" % list.size(), q])
	return list


## Decks and courts without end sockets: the far edge of the mesh from `from`, stepped in 0.6 m.
func _far_side(node: Node3D, from: Vector3) -> Vector3:
	var box := _visual_box(node)
	var c := box.get_center()
	var away := Vector3(c.x - from.x, 0, c.z - from.z).normalized()
	var half := Vector3(box.size.x, 0, box.size.z) * 0.5
	return c + away * maxf(0.0, minf(absf(half.x / maxf(absf(away.x), 0.01)), absf(half.z / maxf(absf(away.z), 0.01))) - 0.6)


## Path polylines from the layout, plus the navmesh route from the spawn to each target.
func _lines(targets: Array) -> Array:
	var lines := []
	if _room_name == "town":
		for path in _room.get("_layout").get("paths", []):
			var pts := PackedVector3Array()
			for q in path["points"]:
				pts.append(NavigationServer3D.map_get_closest_point(_map, Vector3(q[0], q[1], q[2])))
			lines.append(["path " + str(path.get("name", lines.size())), pts])
	var start := _start()
	for t in targets:
		var pts := NavigationServer3D.map_get_path(_map, start, NavigationServer3D.map_get_closest_point(_map, t[1]), true)
		if pts.size() > 1 and _reaches(start, pts[pts.size() - 1]):
			lines.append(["wasd " + t[0], pts])
	return lines


# ------------------------------------------------------------------- routes --

func _click(label: String, target: Vector3, reach: float) -> void:
	await _w.shift_to_marker(_spawn)
	await get_tree().create_timer(0.3).timeout
	var goal := NavigationServer3D.map_get_closest_point(_map, target)
	_rows += 1
	if _flat(goal - target) > reach:
		_fail("unreachable", label, target, "%.1fm off the navmesh" % _flat(goal - target))
		return
	if not _reaches(_start(), goal):
		_fail("unreachable", label, target, "no navmesh route")
		return
	_p.command_walk_to(goal)
	await _watch("click " + label, func(): return _p.get("_click_active"), goal)


## Direct input along a polyline, steering at the next corner like a player holding WASD.
func _wasd(label: String, pts: PackedVector3Array) -> void:
	_rows += 1
	_place(pts[0])
	await get_tree().create_timer(0.3).timeout
	var state := {"i": 1}
	var steer := func() -> bool:
		while state.i < pts.size() and _flat(pts[state.i] - _p.global_position) < 0.4:
			state.i += 1
		_press(Vector3.ZERO if state.i >= pts.size() else pts[state.i] - _p.global_position)
		return state.i < pts.size()
	await _watch(label, steer, pts[pts.size() - 1])


## Runs until `active` returns false or TIMEOUT; records a stuck event if the penguin stalls.
func _watch(label: String, active: Callable, goal: Vector3) -> void:
	var t := 0.0
	var stuck := false
	var trail := []  # [time, position]: real ground speed, not the commanded velocity
	while t < TIMEOUT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not active.call():
			break
		trail.append([t, _p.global_position])
		while trail[0][0] < t - STUCK_TIME:
			trail.pop_front()
		if t > STUCK_TIME + 0.3 and t - trail[0][0] >= STUCK_TIME - 0.05 and _flat(_p.global_position - trail[0][1]) < STUCK_SPEED * STUCK_TIME:
			_fail("stuck", label, _p.global_position, _contact())
			stuck = true
			break
	if _p.get("_click_active"):
		_p.call("_cancel_click")
	_press(Vector3.ZERO)
	if not stuck and t >= TIMEOUT and _flat(_p.global_position - goal) > ARRIVE:
		_fail("stuck", label, _p.global_position, "(timed out %.1fm short)" % _flat(_p.global_position - goal))
	_log(label)


# ------------------------------------------------------------ slide, drive --

## Things to glide along: fences, walls, rails, cliffs and buildings outdoors; every blocker indoors.
func _slide_probes() -> Array:
	var out := []
	var keys := ["fence", "wall", "rail", "cliff", "exterior", "edge"]
	var bodies := _blockers().filter(func(b): return _room_name != "town" or keys.any(func(k): return String(b.get_meta("blocker_of", "")).contains(k)))
	bodies.shuffle()
	for b in bodies:
		if out.size() >= 24:
			break
		var c := _shape_box(b).get_center()
		var at := NavigationServer3D.map_get_closest_point(_map, c)
		var into := Vector3(c.x - at.x, 0, c.z - at.z)
		if into.length() < 0.2 or into.length() > 6.0 or not _reaches(_start(), at):
			continue
		out.append(["slide %s" % _body_name(b, at), at, into.normalized()])
	return out


func _slide(label: String, at: Vector3, dir: Vector3) -> void:
	_rows += 1
	_place(at)
	await get_tree().create_timer(0.3).timeout
	var best := 0.0
	for turn in [PI / 4.0, -PI / 4.0]:  # either way along the face; one side may end in a corner
		_place(at)
		await get_tree().create_timer(0.2).timeout
		var start := _p.global_position
		await _hold(dir.rotated(Vector3.UP, turn), 1.5)
		best = maxf(best, _flat(_p.global_position - start))
		if best >= 0.6:
			break
	if best < 0.6:
		_fail("stuck", label, _p.global_position, "(no glide either way: %.2fm)" % best)
	_log(label)


## [label, start, direction, footprint AABB or null]: straight into every blocking prop; indoors
## also into the walls in eight directions from the spawn; outdoors off the end of every pier.
func _drive_probes() -> Array:
	var out := []
	for b in _blockers():
		var node: Node3D = b.get_meta("blocker_node") if b.has_meta("blocker_node") else null
		var box := _foot_box(node) if node else _shape_box(b)
		if box.size.y < 0.35 or box.size.x > 8.0 or box.size.z > 8.0:
			continue  # rugs, and whole buildings and walls (the slides and wall drives cover those)
		var c := box.get_center()
		var at := NavigationServer3D.map_get_closest_point(_map, Vector3(c.x, box.position.y, c.z))
		var into := Vector3(c.x - at.x, 0, c.z - at.z)
		if into.length() < 0.1 or into.length() > 4.0 or not _reaches(_start(), at):
			continue
		out.append(["into " + _body_name(b, at), at, into.normalized(), box])
	if _room_name == "town":
		for node in _nav().get_children():
			if node.has_meta("walkable") and String(node.get_meta("asset_id", "")).contains("dock"):
				var box := _visual_box(node)
				for e in node.find_children("socket_end_*", "Node3D", true, false):
					var p := (e as Node3D).global_position
					var away := Vector3(p.x - box.get_center().x, 0, p.z - box.get_center().z)
					if away.length() > 0.2:
						out.append(["off " + _tag(node) + " " + e.name, NavigationServer3D.map_get_closest_point(_map, p), away.normalized(), null])
	else:
		for i in 8:
			out.append(["wall dir %d" % i, _start(), Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0), null])
	return out


func _drive(label: String, at: Vector3, dir: Vector3, box) -> void:
	_rows += 1
	_place(at)
	await get_tree().create_timer(0.3).timeout
	await _hold(dir, 2.5 if box == null else 1.5)
	var p := _p.global_position
	var off := _flat(NavigationServer3D.map_get_closest_point(_map, p) - p)
	var water: float = _room.get("_layout").get("water_level", -INF) if _room_name == "town" else -INF
	if box is AABB and _inside_core(p, box):
		_fail("passthrough", label, p, "(inside the prop)")
	elif off > OFF_NAV:
		_fail("passthrough", label, p, "(%.2fm off the walkable floor)" % off)
	elif p.y < water - 0.1:
		_fail("passthrough", label, p, "(in the water)")
	_log(label)


func _inside_core(p: Vector3, box: AABB) -> bool:
	var c := box.get_center()
	return absf(p.x - c.x) < box.size.x * 0.25 and absf(p.z - c.z) < box.size.z * 0.25 and p.y < box.end.y


func _hold(dir: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_press(dir)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_press(Vector3.ZERO)


# ------------------------------------------------------------------ helpers --

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


func _place(at: Vector3) -> void:
	if _p.get("_click_active"):
		_p.call("_cancel_click")
	_p.global_position = at + Vector3.UP * 0.1
	_p.velocity = Vector3.ZERO


func _nav() -> Node:
	return _room.get_node("NavigationRegion3D") if _room.has_node("NavigationRegion3D") else _room


func _start() -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map, _marker(_spawn))


func _reaches(from: Vector3, to: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(_map, from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) <= 0.3


## Static bodies on the blocker layer that belong to this part of the room (bridge rails excluded).
func _blockers() -> Array:
	var at := _marker(_spawn)
	var radius := 70.0 if _room_name == "town" else 14.0
	return _room.find_children("*", "StaticBody3D", true, false).filter(
		func(b): return b.collision_layer & 2 and not b.has_meta("nav_keep") and _flat(_shape_box(b).get_center() - at) < radius)


func _shape_box(b: StaticBody3D) -> AABB:
	var box := AABB(b.global_position, Vector3.ZERO)
	var first := true
	for c in b.get_children():
		if c is CollisionShape3D and c.shape:
			var s: AABB = c.global_transform * c.shape.get_debug_mesh().get_aabb()
			box = s if first else box.merge(s)
			first = false
	return box


func _visual_box(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi.visible:
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


## The model's visible extent at foot height (up to 0.6 m over the ground at its origin):
## a tree's canopy or a sunk rock's buried bulk is not something the penguin walks into.
func _foot_box(node: Node3D) -> AABB:
	var at := node.global_position
	var hit := _p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 4.0, 1))
	var ground: float = hit.position.y if hit else at.y
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		for v in (mi.mesh as Mesh).get_faces():
			var w: Vector3 = mi.global_transform * v
			if w.y > ground - 0.05 and w.y < ground + 0.6:
				box = AABB(w, Vector3.ZERO) if first else box.expand(w)
				first = false
	if first:
		return AABB(at, Vector3.ZERO)
	box.size.y = maxf(box.size.y, 0.6)
	return box


func _body_name(b: Node, at: Vector3) -> String:
	return "%s@%.0f,%.0f" % [b.get_meta("blocker_of", String(b.get_parent().name) + "/" + String(b.name)), at.x, at.z]


func _tag(node: Node) -> String:
	var id := String(node.get_meta("asset_id", node.name))
	return "%s@%.0f,%.0f" % [id, (node as Node3D).global_position.x, (node as Node3D).global_position.z]


## Name of the blocker or walkable placement nearest the point (layer 1 or 2, within 1 m).
func _nearest(at: Vector3) -> String:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.5)
	q.collision_mask = 3
	q.exclude = [_p.get_rid()]
	var best := "floor"
	var best_d := INF
	for hit in _p.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var n: Node = hit.collider
		var name := String(n.get_meta("blocker_of", ""))
		if name == "":
			name = String(n.get_parent().name) + "/" + String(n.name)
		if name.contains("terrain") or name.contains("ShellWalk"):
			continue
		var d := (n as Node3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = name
	return best


## What the capsule is pressed against: collider and contact normal (y over 0.7 is floor).
func _contact() -> String:
	var parts := []
	for i in _p.get_slide_collision_count():
		var c := _p.get_slide_collision(i)
		var n := c.get_normal()
		var who: Node = c.get_collider()
		parts.append("%s n=(%.2f,%.2f,%.2f)" % [who.get_meta("blocker_of", who.name) if who else "?", n.x, n.y, n.z])
	return "[touching " + ", ".join(parts) + "]" if not parts.is_empty() else ""


func _fail(kind: String, label: String, at: Vector3, note: String) -> void:
	var near := _nearest(at)
	_fails.append([_room_name, kind, label + (" " + note if note != "" else ""), at, near])
	print("WALK_TEST | %-11s | %-11s | %s %s at (%.1f, %.1f, %.1f) near %s" % [_room_name, kind.to_upper(), label, note, at.x, at.y, at.z, near])


func _log(label: String) -> void:
	if OS.is_stdout_verbose():
		print("WALK_TEST | %-11s | ok          | %s" % [_room_name, label])


func _marker(name: String) -> Vector3:
	var m := _room.find_child(name, true, false) as Node3D
	return m.global_position if m else _p.global_position


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Town failures over the overhead town map: red stuck, blue pass-through, amber unreachable.
func _draw(out: String) -> void:
	var img := Image.load_from_file("res://ui/map/town_map.png")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ui/map/town_map.json"))
	var lo := Vector2(meta["min"][0], meta["min"][1])
	var hi := Vector2(meta["max"][0], meta["max"][1])
	var colours := {"stuck": Color(0.95, 0.15, 0.15), "passthrough": Color(0.2, 0.4, 0.95), "unreachable": Color(0.95, 0.65, 0.1)}
	for f in _fails:
		if f[0] == "town":
			var c := Vector2i(int((f[3].x - lo.x) / (hi.x - lo.x) * img.get_width()), int((f[3].z - lo.y) / (hi.y - lo.y) * img.get_height()))
			_dot(img, c, 14, colours[f[1]])
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
