extends StaticBody3D

## One pet in the shop pen, with a price board that only shows the offer.
## Buying happens in the shop panel.

const _BOARD_Z := 1.08

var pet_id := ""

var _label: Label3D


func bind(id: String) -> void:
	pet_id = id
	add_to_group("pet_stall")
	collision_layer = 2
	collision_mask = 0
	_board()
	var body := Node3D.new()
	body.set_script(preload("res://scripts/pet_body.gd"))
	add_child(body)
	body.call("setup", id, true)


func can_interact() -> bool:
	return false


func _process(_delta: float) -> void:
	if _label == null:
		return
	_label.text = _offer_text()


func _offer_text() -> String:
	var info := PetCatalog.find(pet_id)
	var pet_name := str(info.get("name", "Pet"))
	var price := int(info.get("price", 0))
	var world := _world()
	if world == null:
		return "%s\n%d" % [pet_name, price]
	if bool(world.call("owns_pet", pet_id)):
		if str(world.call("active_pet_id")) == pet_id:
			return "%s\nWith you" % pet_name
		return "%s\nYours" % pet_name
	return "%s\n%d" % [pet_name, price]


func _board() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.34, 0.08)
	var board := MeshInstance3D.new()
	board.mesh = mesh
	board.position = Vector3(0.0, 0.58, _BOARD_Z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.93, 0.86)
	mat.roughness = 0.78
	board.set_surface_override_material(0, mat)
	add_child(board)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.34, 0.08)
	shape_node.shape = box
	shape_node.position = board.position
	add_child(shape_node)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 8
	_label.pixel_size = 0.0042
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.modulate = Color(0.12, 0.2, 0.28, 1)
	_label.outline_modulate = Color(0.98, 0.96, 0.9, 1)
	_label.position = Vector3(0.0, 0.6, _BOARD_Z + 0.06)
	add_child(_label)


func _world() -> Node:
	return get_tree().get_first_node_in_group("world")
