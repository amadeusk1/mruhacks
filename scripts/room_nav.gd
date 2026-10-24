extends NavigationRegion3D

## Bakes a walkable snow mesh when the plaza loads.
## Floor colliders (physics layer 1) are the only walkable surface.
## Blockers (physics layer 2) carve holes so paths go around the ice, not over it.

const AGENT_RADIUS := 0.5
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
	NavigationServer3D.map_set_cell_size(map, 0.25)
	NavigationServer3D.map_set_cell_height(map, 0.25)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 25.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	navigation_mesh = mesh
	bake_navigation_mesh(false)
	if navigation_mesh == null or navigation_mesh.get_polygon_count() == 0:
		push_error("Snow navmesh bake produced no walkable polygons.")
	else:
		print("Snow navmesh polygons: ", navigation_mesh.get_polygon_count())


func _carve_blockers() -> void:
	for node in find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.collision_layer & 2 == 0:
			continue
		for child in body.get_children():
			if not (child is CollisionShape3D):
				continue
			var shape_node := child as CollisionShape3D
			if not (shape_node.shape is BoxShape3D):
				continue
			_carve_box(shape_node)


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
