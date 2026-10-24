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
		if hole and not landed:
			open.append(edge)
	return open


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


## Stair modules: a ramp under the steps from socket_bottom to socket_top, overhanging both
## ends so a flight of modules joins up. Bridges: ramps from each socket_end_* down to the
## ground outside it when the deck end sits higher than a step.
static func add_ramps(node: Node3D, parent: Node, space: PhysicsDirectSpaceState3D) -> int:
	var made := 0
	var bottom := node.find_child("socket_bottom", true, false) as Node3D
	var top := node.find_child("socket_top", true, false) as Node3D
	if bottom and top:
		var a := bottom.global_position
		var b := top.global_position
		var along := b - a
		ramp(parent, a - along.normalized() * 0.45, b + along.normalized() * 0.45, 1.4, node.name + "_ramp")
		made += 1
	for end in node.find_children("socket_end_*", "Node3D", true, false):
		var e := (end as Node3D).global_position
		var out := Vector3(e.x - node.global_position.x, 0, e.z - node.global_position.z).normalized()
		var far := e + out * 1.6
		var hit := _down(space, far, e.y + 1.0, e.y - 2.0)
		if hit and e.y - hit.position.y > 0.1:
			ramp(parent, e - out * 0.3, hit.position + out * 0.3, 1.2, node.name + "_endramp")
			made += 1
	return made
