extends Node3D

## Town square plus the three shop interiors.
## Interiors sit far east of the square so the square camera never sees them.
## Spawn names that start with "Inside" pick that shop's camera frame.

const _CLOTHES := Vector3(120.0, 0.0, 0.0)
const _FURNITURE := Vector3(120.0, 0.0, 50.0)
const _PETS := Vector3(120.0, 0.0, 100.0)


func _ready() -> void:
	AssetPack.dress_town(self)
	_dress_pet_shop()
	FishingDock.build(self)


func _dress_pet_shop() -> void:
	var decor := get_node_or_null("Decor")
	if decor:
		for nap_name in ["NapRed", "NapMint", "NapGold", "Zzz"]:
			var nap := decor.get_node_or_null(nap_name)
			if nap:
				nap.visible = false
				nap.queue_free()
	if get_node_or_null("PetStalls") != null:
		return
	var root := Node3D.new()
	root.name = "PetStalls"
	add_child(root)
	var ids: Array = PetCatalog.ORDER
	var start_x := 118.2
	var step := 0.68
	for i in ids.size():
		_stall(root, str(ids[i]), Vector3(start_x + step * i, 0.0, 98.25))
	_pen_post(root, start_x - 0.42)
	_pen_post(root, start_x + step * (ids.size() - 1) + 0.42)
	_shop_counter(root, Vector3(120.76, 0.0, 100.74))


func _stall(root: Node3D, id: String, at: Vector3) -> void:
	var stall := StaticBody3D.new()
	stall.set_script(preload("res://scripts/pet_stall.gd"))
	root.add_child(stall)
	stall.position = at
	stall.call("bind", id)


func _shop_counter(root: Node3D, at: Vector3) -> void:
	var counter := Node3D.new()
	counter.name = "PetCounter"
	counter.set_script(preload("res://scripts/shop_counter.gd"))
	root.add_child(counter)
	counter.position = at
	counter.call("bind", "pets", "Look at pets")


func _pen_post(root: Node3D, x: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.42, 1.28)
	var post := MeshInstance3D.new()
	post.mesh = mesh
	post.position = Vector3(x, 0.22, 98.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.36, 0.24)
	mat.roughness = 0.82
	post.set_surface_override_material(0, mat)
	root.add_child(post)


func camera_for_spawn(spawn_name: String) -> Dictionary:
	if spawn_name.begins_with("InsideClothes"):
		return {"center": _CLOTHES, "limit_x": 2.2, "limit_z": 2.3}
	if spawn_name.begins_with("InsideFurniture"):
		return {"center": _FURNITURE, "limit_x": 2.2, "limit_z": 2.3}
	if spawn_name.begins_with("InsidePet"):
		return {"center": _PETS, "limit_x": 2.2, "limit_z": 2.3}
	return {
		"center": Vector3.ZERO,
		"limit_x": 16.0,
		"limit_z": 8.5,
		"height": 14.2,
		"distance": 10.8,
	}
