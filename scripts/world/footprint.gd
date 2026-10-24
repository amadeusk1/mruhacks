class_name Footprint
extends RefCounted

## Blocker collision from the model's own feet, not its AABB box (a box across bunting posts,
## string lights or a scaled rock walled off paths). Geometry below FOOT_H m is rasterised to
## FOOT_CELL cells; each connected patch becomes a convex prism (rocks shrunk to 75%), or row
## boxes when the patch is concave (fence corners). Moving parts (tree crowns, flags, doors)
## never block. room_nav carves each prism's outline, so the navmesh routes around the same shapes.
## Heights are measured from the ground under the placement, not its origin: rocks sit sunk up to 1 m.
const FOOT_H := 0.9  # the penguin is 0.9 m tall: table tops and seat backs it would walk into count
const POSTS_ONLY := ["rope_posts", "bunting", "string_lights", "homes_arch", "checkpoint_posts"]  # ropes and garlands sag below FOOT_H
const POST_H := 0.25
const FOOT_CELL := 0.15
const BLOCK_TOP := 2.0  # well over the 1.25 m agent height, or the bake keeps the floor under the prism
static var _cache := {}  # key -> Array of [kind, data] in the asset's scaled local XZ


static func blocker(nav: Node, node: Node3D, id: String, scale: float, space: PhysicsDirectSpaceState3D) -> StaticBody3D:
	# Ground around the placement, in the asset's frame. Several rays: one at the origin can drop
	# through a fountain basin or onto the stream bed and leave the prism top at knee height.
	var at := node.global_position
	var lo := INF
	var hi := -INF
	var size := AssetRegistry.size(id) * scale
	var ring := maxf(size.x, size.z) * 0.5 + 0.3  # just outside the model
	for o in [Vector3.ZERO, Vector3(0.8, 0, 0), Vector3(-0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0, 0, -0.8),
			Vector3(ring, 0, 0), Vector3(-ring, 0, 0), Vector3(0, 0, ring), Vector3(0, 0, -ring)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + o + Vector3.UP * 4.0, at + o + Vector3.DOWN * 4.0, 1))
		if hit:
			lo = minf(lo, hit.position.y - at.y)
			hi = maxf(hi, hit.position.y - at.y)
	if lo == INF:
		lo = 0.0
		hi = 0.0
	lo = snappedf(lo, 0.1)
	var ground := snappedf(hi, 0.1)
	var key := "%s@%.2f@%.1f@%.1f" % [id, scale, lo, ground]
	if not _cache.has(key):
		_cache[key] = _footprint(node, id, scale, lo, ground)
	var body := StaticBody3D.new()
	body.name = node.name + "_block"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("blocker_of", id)
	body.set_meta("blocker_node", node)  # tools/walk_test drives into the visible model
	var xf := WalkSurface._world(nav).affine_inverse() * WalkSurface._world(node)  # node may sit under another parent
	body.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	for piece in _cache[key]:
		var col := CollisionShape3D.new()
		if piece[0] == "hull":
			var pts := PackedVector3Array()
			for q in piece[1]:
				pts.append(Vector3(q.x, lo - 0.3, q.y))
				pts.append(Vector3(q.x, ground + BLOCK_TOP, q.y))
			var hull := ConvexPolygonShape3D.new()
			hull.points = pts  # before assigning: an empty hull on a shape node logs a build error
			col.shape = hull
		else:  # [box, Rect2]
			var r: Rect2 = piece[1]
			col.shape = BoxShape3D.new()
			col.shape.size = Vector3(r.size.x, ground + BLOCK_TOP - lo + 0.3, r.size.y)
			col.position = Vector3(r.get_center().x, (ground + BLOCK_TOP + lo - 0.3) * 0.5, r.get_center().y)
		body.add_child(col)
	nav.add_child(body)
	return body


## Cross-section of everything between the lowest ground round the placement and FOOT_H above the
## highest (a cliff or a sunk rock is widest at its foot, not at the top of the slope).
static func _footprint(node: Node3D, id: String, scale: float, lo: float, ground: float, trunk_only := true) -> Array:
	var parts := AssetRegistry.parts(id)
	var foot := POST_H if POSTS_ONLY.any(func(k): return id.contains(k)) else FOOT_H
	var trunk := trunk_only and id.contains("tree") and not id.contains("treehouse")  # low branches and snow skirts never block
	var cells := {}
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or parts.has(String(mi.name)) or parts.has(String(mi.get_parent().name)):
			continue
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO) * _local_to(node, mi)
		for s in mi.mesh.get_surface_count():
			var f := (mi.mesh as Mesh).surface_get_arrays(s)
			var v: PackedVector3Array = f[Mesh.ARRAY_VERTEX]
			var idx = f[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).is_empty():
				idx = null
			var count: int = idx.size() if idx != null else v.size()
			for t in range(0, count, 3):
				var a := xf * v[idx[t] if idx != null else t]
				var b := xf * v[idx[t + 1] if idx != null else t + 1]
				var c := xf * v[idx[t + 2] if idx != null else t + 2]
				if minf(a.y, minf(b.y, c.y)) > ground + foot or maxf(a.y, maxf(b.y, c.y)) < lo - 0.05:
					continue
				var top := maxf(a.y, maxf(b.y, c.y))
				if top < lo + 0.1 or (top < ground + 0.5 and absf((b - a).cross(c - a).normalized().y) > 0.7):
					continue  # floors (tile bevels, grout), rugs, steps and plinth tops are walked on, not into
				var n := maxi(1, ceili(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) / (FOOT_CELL * 0.5)))
				for i in n + 1:
					for j in n + 1 - i:
						var q := a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n)
						if q.y < ground + foot and q.y > lo - 0.05 and (not trunk or Vector2(q.x, q.z).length() < 0.45):  # the cross-section a penguin meets
							cells[Vector2i(floori(q.x / FOOT_CELL), floori(q.z / FOOT_CELL))] = true
	if cells.is_empty() and trunk:  # the trunk is off the pivot: fall back to the whole cross-section
		return _footprint(node, id, scale, lo, ground, false)
	if id.ends_with("_exterior"):
		_fill_holes(cells)  # a building's wall ring becomes its whole floor plan, so it gets one smooth hull
	var out := []
	var rock := id.contains("rock")
	var room := str(AssetRegistry.entry(id).get("category", "")) == "room"  # walls and furniture, never one hull
	while not cells.is_empty():
		var seed: Vector2i = cells.keys()[0]
		var patch := [seed]
		cells.erase(seed)
		var k := 0
		while k < patch.size():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nb: Vector2i = patch[k] + d
				if cells.has(nb):
					cells.erase(nb)
					patch.append(nb)
			k += 1
		var corners := PackedVector2Array()
		for cell in patch:
			for o in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				corners.append((Vector2(cell) + o) * FOOT_CELL)
		var hull := Geometry2D.convex_hull(corners)
		var area := absf(_area(hull))
		if rock:  # players snag on the outer bumps otherwise
			var mid := Vector2.ZERO
			for q in hull:
				mid += q
			mid /= hull.size()
			for i in hull.size():
				hull[i] = mid + (hull[i] - mid) * 0.75
			out.append(["hull", hull])
		elif not room and (patch.size() * FOOT_CELL * FOOT_CELL >= 0.6 * area or patch.size() < 4):
			out.append(["hull", hull])
		else:  # concave patch: one box per run of cells along each row
			var rows := {}
			for cell in patch:
				rows[cell.y] = rows.get(cell.y, []) + [cell.x]
			for z in rows:
				var xs: Array = rows[z]
				xs.sort()
				var start: int = xs[0]
				for i in xs.size():
					if i == xs.size() - 1 or xs[i + 1] != xs[i] + 1:
						out.append(["box", Rect2(Vector2(start, z) * FOOT_CELL, Vector2(xs[i] - start + 1, 1) * FOOT_CELL)])
						if i < xs.size() - 1:
							start = xs[i + 1]
	return out


## Marks every empty cell that cannot be reached from outside the cells' bounding box.
static func _fill_holes(cells: Dictionary) -> void:
	if cells.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	lo -= Vector2i.ONE
	hi += Vector2i.ONE
	var outside := {lo: true}
	var todo := [lo]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if nb.x < lo.x or nb.y < lo.y or nb.x > hi.x or nb.y > hi.y or outside.has(nb) or cells.has(nb):
				continue
			outside[nb] = true
			todo.append(nb)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			var c := Vector2i(x, y)
			if not outside.has(c):
				cells[c] = true


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


static func _local_to(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		t = (cur as Node3D).transform * t if cur is Node3D else t
		cur = cur.get_parent()
	return t
