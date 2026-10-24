class_name WalkSurface
extends RefCounted

## Floor collision that matches what you see. Every upward-facing triangle of a model becomes the
## top of a solid slab extruded down to `base_y`, so tiers, steps, stages, decks and bridge
## arches are standable at their visible height (within mesh precision) and their risers are
## real steps for the movement code (floor_snap 0.25) and the navmesh (agent_max_climb 0.25).
## Taller things (seats, counters) come out as solid columns, which is the collision they need.

const UP := 0.6          # normal.y above this counts as standable (about 53 degrees)
const MAX_TOP := 1.6     # ignore up-faces above this: roofs, canopies, shelf tops


## Adds one StaticBody3D (layer 1) under `parent` covering `model`'s standable faces.
## `base_y` is the world height slabs extend down to (below the surrounding floor).
static func build(model: Node3D, parent: Node, base_y: float, name := "WalkSurface") -> StaticBody3D:
	var faces := PackedVector3Array()
	var top_limit := _world(model).origin.y + MAX_TOP
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for mi in meshes:
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null or not mi.visible:
			continue
		var xf := _world(mi)
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).is_empty():
				idx = null  # unindexed surface: vertices are already the triangle list
			var count: int = idx.size() if idx != null else v.size()
			for t in range(0, count, 3):
				var a := xf * v[idx[t] if idx != null else t]
				var b := xf * v[idx[t + 1] if idx != null else t + 1]
				var c := xf * v[idx[t + 2] if idx != null else t + 2]
				var n := (b - a).cross(c - a)
				if n.length_squared() < 1e-10:
					continue
				if n.y < 0.0:  # winding: make the top face point up
					var tmp := b
					b = c
					c = tmp
					n = -n
				if n.normalized().y < UP or maxf(a.y, maxf(b.y, c.y)) > top_limit:
					continue
				_prism(faces, a, b, c, base_y)
	if faces.is_empty():
		return null
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true  # tops face either way after the winding flip; collide both
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.transform = _world(parent).affine_inverse()  # faces are in world space
	return body


## World transform that also works while a room is still being built in _enter_tree (before
## its children are inside the tree): compose local transforms up the parent chain.
static func _world(n: Node) -> Transform3D:
	if n is Node3D and n.is_inside_tree():
		return (n as Node3D).global_transform
	var t := Transform3D.IDENTITY
	var cur := n
	while cur != null:
		if cur is Node3D:
			if cur.is_inside_tree():
				return (cur as Node3D).global_transform * t
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func _prism(out: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, base_y: float) -> void:
	out.append_array([a, c, b])  # top, in Godot's clockwise front-face order (else the bake sees it facing down)
	var ring := [a, b, c]
	for i in 3:  # sides, outward-facing for a counter-clockwise (from above) top
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % 3]
		var pb := Vector3(p.x, base_y, p.z)
		var qb := Vector3(q.x, base_y, q.z)
		out.append_array([p, qb, pb, p, q, qb])


## Joins a walkable placement to the ground around it: from points along its standable edge,
## look outward up to `max_gap` m for floor within STEP of the edge height; if a hole (water,
## a gap between stair modules) lies between, add a thin invisible span (layer 1).
## Returns the list of gaps it could NOT close (for reporting layout problems).
const STEP := 0.33


static func span_gaps(body: StaticBody3D, parent: Node, space: PhysicsDirectSpaceState3D, max_gap := 1.2) -> Array:
	var faces: PackedVector3Array = (body.get_child(0) as CollisionShape3D).shape.get_faces()
	var box := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		box = box.expand(v)
	var c := box.get_center()
	var open := []
	var n := 24
	for i in n:
		var ang := TAU * i / n
		var dir := Vector3(cos(ang), 0, sin(ang))
		# edge point: last spot along dir from the centre where this body is the floor
		var edge := Vector3.INF
		var t := 0.0
		while t < box.size.length():
			var p := c + dir * t
			var hit := _down(space, p, box.end.y + 1.0, box.position.y - 0.1)
			if hit and hit.collider == body:
				edge = hit.position
			elif edge != Vector3.INF:
				break
			t += 0.2
		if edge == Vector3.INF:
			continue
		var hole := false
		var landed := false
		var d := 0.2
		while d <= max_gap + 0.01:
			var hit := _down(space, edge + dir * d, edge.y + 1.0, edge.y - 3.0)
			if hit and hit.collider != body and absf(hit.position.y - edge.y) <= STEP:
				landed = true
				if hole:
					_span(parent, edge, hit.position, dir)
				break
			if not hit or hit.position.y < edge.y - STEP:
				hole = true
			d += 0.2
		if hole and not landed and not _guarded(space, edge, dir):
			open.append(edge)
	return open


## Penguin-sized probe, so a notch narrower than the capsule where two rails meet is not an exit.
static func _guarded(space: PhysicsDirectSpaceState3D, edge: Vector3, dir: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.25
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, edge - dir * 0.3 + Vector3.UP * 0.4)
	q.motion = dir * 0.9
	q.collision_mask = 2
	return space.cast_motion(q)[0] < 1.0


## Invisible rails along every side of a rectangular walkable (dock, stair flight) that drops
## more than a step into water or onto lower ground. Sides that meet a neighbouring module, the
## ground or a ramp stay open. room_nav carves them: on the deck side that costs nothing (the
## navmesh already stops short of the drop), and beside a flight it keeps paths off the rail ends.
## Returns the number of rails.
const GUARD_SAMPLE := 0.25


static func guard_edges(node: Node3D, body: StaticBody3D, parent: Node, space: PhysicsDirectSpaceState3D) -> int:
	var faces: PackedVector3Array = (body.get_child(0) as CollisionShape3D).shape.get_faces()
	var to_local := Transform3D(node.global_basis.orthonormalized(), node.global_position).affine_inverse()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in faces:
		var q := to_local * v
		lo = lo.min(q)
		hi = hi.max(q)
	var to_world := to_local.affine_inverse()
	var made := 0
	# side: fixed axis, value, outward sign; walk along the other axis
	for side in [["x", hi.x, 1.0], ["x", lo.x, -1.0], ["z", hi.z, 1.0], ["z", lo.z, -1.0]]:
		var along_x: bool = side[0] == "z"
		var a0: float = lo.x if along_x else lo.z
		var a1: float = hi.x if along_x else hi.z
		var steps := maxi(1, ceili((a1 - a0) / GUARD_SAMPLE))
		var run := []
		for i in steps + 1:
			var t := lerpf(a0 + 0.05, a1 - 0.05, float(i) / steps)
			var inset: float = side[1] - side[2] * 0.05
			var local := Vector3(t, 0, inset) if along_x else Vector3(inset, 0, t)
			var out_local := Vector3(0, 0, side[2]) if along_x else Vector3(side[2], 0, 0)
			var at := to_world * local
			var out := (to_world.basis * out_local).normalized()
			var top := _down(space, at, to_world.origin.y + hi.y + 1.0, to_world.origin.y + lo.y - 0.2)
			var drop := false
			if top and top.collider == body:
				drop = true
				for d in [0.25, 0.5]:
					var hit := _down(space, top.position + out * d, top.position.y + 1.0, top.position.y - 3.0)
					if hit and absf(hit.position.y - top.position.y) <= STEP:
						drop = false
						break
			if drop:
				run.append([top.position, i])
			if (not drop or i == steps) and not run.is_empty():
				# a run that reaches the corner ends at the module's edge, never past it: an
				# overhang there snags penguins walking onto the stairs or pier at an angle
				var first: int = run[0][1]
				var last: int = run[run.size() - 1][1]
				var t0 := a0 if first == 0 else lerpf(a0 + 0.05, a1 - 0.05, float(first) / steps) - GUARD_SAMPLE * 0.5
				var t1 := a1 if last == steps else lerpf(a0 + 0.05, a1 - 0.05, float(last) / steps) + GUARD_SAMPLE * 0.5
				_guard(parent, run, t0, t1, side[1] + side[2] * 0.06, side[2], along_x, to_local)
				made += 1
				run = []
	return made


static func _guard(parent: Node, run: Array, t0: float, t1: float, edge: float, outward: float, along_x: bool, to_local: Transform3D) -> void:
	var to_world := to_local.affine_inverse()
	var y0 := INF
	var y1 := -INF
	for p in run:
		var q := to_local * (p[0] as Vector3)
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var pts := PackedVector3Array()
	for t in [t0, t1]:
		for e in [edge, edge + outward * 0.08]:
			for y in [y0 - 0.3, y1 + 0.9]:
				pts.append(to_world * (Vector3(t, y, e) if along_x else Vector3(e, y, t)))
	var body := StaticBody3D.new()
	body.name = "EdgeGuard"
	body.collision_layer = 2
	body.collision_mask = 0
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	var col := CollisionShape3D.new()
	col.shape = hull
	body.add_child(col)
	parent.add_child(body)
	body.global_transform = Transform3D.IDENTITY


static func _down(space: PhysicsDirectSpaceState3D, at: Vector3, from_y: float, to_y: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y, at.z), Vector3(at.x, to_y, at.z), 1)
	return space.intersect_ray(q)


static func _span(parent: Node, a: Vector3, b: Vector3, dir: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "GapSpan"
	body.set_meta("gap_span", true)
	body.collision_layer = 1
	body.collision_mask = 0
	var len := Vector2(b.x - a.x, b.z - a.z).length() + 0.4
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 0.1, len)  # wide enough to survive the 0.3 m agent erosion each side
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	var mid := (a + b) * 0.5 - Vector3(0, 0.05, 0)
	body.global_transform = Transform3D(Basis.looking_at(Vector3(b.x - a.x, b.y - a.y, b.z - a.z).normalized(), Vector3.UP), mid)


## Invisible walk ramp (layer 1) from a to b, `width` wide, with its top surface on the line.
static func ramp(parent: Node, a: Vector3, b: Vector3, width := 1.2, name := "Ramp") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.2, a.distance_to(b))
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	var basis := Basis.looking_at((b - a).normalized(), Vector3.UP)
	body.global_transform = Transform3D(basis, (a + b) * 0.5 - basis.y * 0.1)  # top face on a-b
	return body


## Bridges: ramps from each socket_end_* down to the ground outside it when the deck end sits
## higher than a step. Stairs are handled per flight by stair_ramps.
static func add_ramps(node: Node3D, parent: Node, space: PhysicsDirectSpaceState3D) -> int:
	var made := 0
	for end in node.find_children("socket_end_*", "Node3D", true, false):
		var e := (end as Node3D).global_position
		var out := Vector3(e.x - node.global_position.x, 0, e.z - node.global_position.z).normalized()
		var far := e + out * 1.6
		var hit := _down(space, far, e.y + 1.0, e.y - 2.0)
		if hit and e.y - hit.position.y > 0.1:
			ramp(parent, e - out * 0.3, hit.position + out * 0.3, 1.2, node.name + "_endramp")
			made += 1
	return made


## One ramp under each flight of stair modules (a module's socket_top meeting the next one's
## socket_bottom). Per-module ramps left a lip at every joint: modules overlap, so the flight is
## steeper than each module's own bottom-to-top line. The low end runs on until its end face is
## buried 0.25 m; the high end barely overlaps the landing, or it pokes up out of it.
static func stair_ramps(nodes: Array, parent: Node) -> int:
	var mods := []  # [bottom, top]
	for n in nodes:
		var bottom := (n as Node3D).find_child("socket_bottom", true, false) as Node3D
		var top := (n as Node3D).find_child("socket_top", true, false) as Node3D
		if bottom and top:
			mods.append([bottom.global_position, top.global_position])
	var used := {}
	var made := 0
	for i in mods.size():
		if used.has(i) or _below(mods, i) != -1:
			continue  # not the foot of a flight
		var a: Vector3 = mods[i][0]
		var j := i
		used[i] = true
		while true:
			var nxt := _above(mods, j)
			if nxt == -1 or used.has(nxt):
				break
			used[nxt] = true
			j = nxt
		var b: Vector3 = mods[j][1]
		var along := (b - a).normalized()
		var low := clampf(0.25 / maxf(along.y, 0.05), 0.45, 1.5)
		ramp(parent, a - along * low, b + along * 0.15, 1.9, "FlightRamp")  # out to the edge rails: the treads' own collision is off
		made += 1
	return made


static func _above(mods: Array, i: int) -> int:
	for k in mods.size():
		if k != i and (mods[k][0] as Vector3).distance_to(mods[i][1]) < 0.6:
			return k
	return -1


static func _below(mods: Array, i: int) -> int:
	for k in mods.size():
		if k != i and (mods[k][1] as Vector3).distance_to(mods[i][0]) < 0.6:
			return k
	return -1
