extends NavigationRegion3D

## Bakes a walkable snow mesh when the plaza loads.
## Floor colliders (physics layer 1) are the only walkable surface.
## Blockers (physics layer 2) carve holes so paths go around the ice, not over it.

const AGENT_RADIUS := 0.3  # the penguin capsule (0.28); 0.5 erased narrow bridges, docks and stairs
const AGENT_HEIGHT := 1.25


func _ready() -> void:
	_bake()


func rebake() -> void:
	for node in find_children("NavCarve", "NavigationObstacle3D", true, false):
		node.free()
	_bake()


func _bake() -> void:
	_carve_blockers()
	var map := get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, 0.15)  # 0.25 eroded 0.5 m per side: no bridges or docks
	NavigationServer3D.map_set_cell_height(map, 0.1)  # finer than the 0.2 m tier/stair steps
	var mesh := NavigationMesh.new()
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.agent_max_climb = 0.35  # matches penguin_movement STEP_HEIGHT
	mesh.agent_max_slope = 28.0  # bridge arch is about 27 degrees at the springing
	mesh.cell_size = 0.15
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	navigation_mesh = mesh
	bake_navigation_mesh(false)  # applied at once only with async map/region iterations off (project.godot)
	if navigation_mesh == null or navigation_mesh.get_polygon_count() == 0:
		push_error("Snow navmesh bake produced no walkable polygons.")
	else:
		print("Snow navmesh polygons: ", navigation_mesh.get_polygon_count())


func _carve_blockers() -> void:
	for node in find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.has_meta("nav_keep") or body.collision_layer & 2 == 0:
			continue
		for child in body.get_children():
			if not (child is CollisionShape3D):
				continue
			var shape_node := child as CollisionShape3D
			if shape_node.shape is BoxShape3D:
				_carve_box(shape_node)
			elif shape_node.shape is ConvexPolygonShape3D:
				_carve_hull(shape_node)


func _carve_box(shape_node: CollisionShape3D) -> void:
	var box := shape_node.shape as BoxShape3D
	var xf := shape_node.global_transform
	var half := box.size * 0.5
	var corners: Array[Vector3] = [
		xf * Vector3(-half.x, 0.0, -half.z),
		xf * Vector3(-half.x, 0.0, half.z),
		xf * Vector3(half.x, 0.0, half.z),
		xf * Vector3(half.x, 0.0, -half.z),
	]
	var origin := Vector3(xf.origin.x, 0.0, xf.origin.z)
	var verts := PackedVector3Array()
	for corner in corners:
		verts.append(Vector3(corner.x - origin.x, 0.0, corner.z - origin.z))
	var span := Vector2(verts[2].x - verts[0].x, verts[2].z - verts[0].z).length()
	if span < 0.2:
		return
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "NavCarve"
	add_child(obstacle)
	# Sit on the snow and rise through the prop so the floor inside the
	# footprint is discarded, including any ledge on top of a block.
	obstacle.global_position = origin
	obstacle.height = 4.0
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = true
	obstacle.vertices = verts


## Town blockers are prisms over the model's real footprint: carve their outline, from the
## bottom of the prism up, so it works on the sled hill as well as the plaza.
func _carve_hull(shape_node: CollisionShape3D) -> void:
	var xf := shape_node.global_transform
	var flat := PackedVector2Array()
	var low := INF
	var high := -INF
	for q in (shape_node.shape as ConvexPolygonShape3D).points:
		var p := xf * q
		flat.append(Vector2(p.x, p.z))
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 4:
		return
	var centre := Vector2(xf.origin.x, xf.origin.z)
	var verts := PackedVector3Array()
	for i in hull.size() - 1:  # convex_hull repeats the first point at the end
		verts.append(Vector3(hull[i].x - centre.x, 0.0, hull[i].y - centre.y))
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "NavCarve"
	add_child(obstacle)
	obstacle.global_position = Vector3(centre.x, low, centre.y)
	obstacle.height = high - low
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = true
	obstacle.vertices = verts
