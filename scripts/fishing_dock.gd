class_name FishingDock
extends RefCounted

## Pond, pier, and four fishing spots on the west side of the square.
## The walkable deck is a floor collider. The water is visual only.

const WATER_Y := -0.34


static func build(plaza: Node3D) -> void:
	if plaza.get_node_or_null("Fishing") != null:
		return
	var nav := plaza.get_node_or_null("NavigationRegion3D") as Node3D
	if nav == null:
		return
	_open_west_wall(nav)
	var deck := _deck(nav)
	var root := Node3D.new()
	root.name = "Fishing"
	plaza.add_child(root)
	_water(root)
	_bank(root)
	_pier_mesh(deck)
	_models(root)
	_spots(root)
	_sign(root)
	if nav.has_method("rebake"):
		nav.call("rebake")


static func _open_west_wall(nav: Node3D) -> void:
	var wall := nav.get_node_or_null("WallWest") as Node3D
	if wall == null:
		return
	# North of the gap. The south piece is a copy. The gap is the pond mouth.
	wall.scale = Vector3(0.45, 0.9, 9.55)
	wall.position = Vector3(-13.25, 0.45, 7.475)
	var south := wall.duplicate() as Node3D
	south.name = "WallWestSouth"
	nav.add_child(south)
	south.scale = Vector3(0.45, 0.9, 9.55)
	south.position = Vector3(-13.25, 0.45, -7.475)


static func _deck(nav: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "DockFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(-13.45, -0.16, 0.0)
	nav.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.5, 0.32, 4.7)
	shape.shape = box
	body.add_child(shape)
	_rail(nav, Vector3(-13.45, 0.45, 2.5), Vector3(4.7, 0.9, 0.28))
	_rail(nav, Vector3(-13.45, 0.45, -2.5), Vector3(4.7, 0.9, 0.28))
	return body


static func _rail(nav: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = at
	nav.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


static func _water(root: Node3D) -> void:
	_box(root, "PondBed", Vector3(-18.2, -0.95, 0.0), Vector3(11.2, 0.7, 16.4), Color(0.07, 0.24, 0.38), false)
	var skin := _box(root, "Pond", Vector3(-18.15, -0.58, 0.0), Vector3(10.6, 0.48, 15.6), Color(0.28, 0.68, 0.82, 0.9), true)
	var mat := skin.material_override as StandardMaterial3D
	mat.roughness = 0.06
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.42, 0.58)
	mat.emission_energy_multiplier = 0.4


static func _bank(root: Node3D) -> void:
	_box(root, "FarBank", Vector3(-24.5, -0.05, 0.0), Vector3(5.2, 0.55, 18.0), Color(0.93, 0.95, 0.98), false)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = Vector3(-24.5, 0.2, 0.0)
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.2, 0.9, 18.0)
	shape.shape = box
	body.add_child(shape)


static func _pier_mesh(deck: StaticBody3D) -> void:
	var mesh := _box(deck, "Planks", Vector3(1.15, 0.18, 0.0), Vector3(2.05, 0.06, 4.5), Color(0.62, 0.42, 0.22), false)
	var mat := mesh.material_override as StandardMaterial3D
	mat.roughness = 0.72


static func _models(root: Node3D) -> void:
	AssetPack.place(root, "fishing", "fishing_dock_spot", Vector3(-14.15, 0.0, -1.15), PI * 0.5)
	AssetPack.place(root, "fishing", "fishing_dock_spot", Vector3(-14.15, 0.0, 1.15), PI * 0.5)
	AssetPack.place(root, "fishing", "ice_floe_a", Vector3(-17.4, 0.17, -3.4))
	AssetPack.place(root, "fishing", "ice_floe_b", Vector3(-19.6, 0.17, 2.2))
	AssetPack.place(root, "fishing", "ice_floe_c", Vector3(-16.6, 0.17, 4.3))
	AssetPack.place(root, "fishing", "rowboat", Vector3(-16.9, 0.22, -4.6), 0.4)
	AssetPack.place(root, "fishing", "life_ring", Vector3(-13.35, 0.2, 2.15))
	AssetPack.place(root, "fishing", "bucket", Vector3(-13.55, 0.0, -1.85))
	AssetPack.place(root, "plaza", "lantern_post", Vector3(-12.85, 0.0, -2.15))
	AssetPack.place(root, "nature_dock", "small_tree_snow", Vector3(-23.4, 0.0, -4.5))
	AssetPack.place(root, "nature_dock", "broad_tree_snow", Vector3(-23.8, 0.0, 5.2))


static func _spots(root: Node3D) -> void:
	var along: Array[float] = [-1.65, -0.55, 0.55, 1.65]
	for i in along.size():
		var spot := StaticBody3D.new()
		spot.name = "Spot%s" % i
		spot.set_script(load("res://scripts/fishing_spot.gd"))
		spot.position = Vector3(-15.45, 0.58, along[i])
		root.add_child(spot)


static func _sign(root: Node3D) -> void:
	var sign := Label3D.new()
	sign.text = "Fishing"
	sign.position = Vector3(-12.35, 1.85, 0.0)
	sign.font_size = 72
	sign.outline_size = 16
	sign.pixel_size = 0.008
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(0.93, 0.97, 1.0)
	sign.outline_modulate = Color(0.08, 0.16, 0.24)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sign)


static func _box(parent: Node, node_name: String, at: Vector3, size: Vector3, color: Color, watery: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if watery:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh
