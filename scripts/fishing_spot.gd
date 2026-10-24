extends StaticBody3D

## One rail on the west pier. Press F at the prompt, or click it, to fish facing the pond.

const _YAW := PI * 0.5

var _prompt: Label3D


func _ready() -> void:
	add_to_group("fish_spot")
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.62, 1.15, 0.72)
	shape.shape = box
	add_child(shape)
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 0.95, 0.16)
	post.mesh = post_mesh
	post.position = Vector3(0.0, 0.05, 0.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.2)
	wood.roughness = 0.7
	post.material_override = wood
	add_child(post)
	_prompt = Label3D.new()
	_prompt.text = "F to fish"
	_prompt.font_size = 42
	_prompt.outline_size = 8
	_prompt.pixel_size = 0.005
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.98, 0.98, 1, 1)
	_prompt.outline_modulate = Color(0.1, 0.16, 0.24, 1)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_prompt.top_level = true
	add_child(_prompt)
	_prompt.global_position = approach_point() + Vector3(0.0, 1.25, 0.0)


func approach_point() -> Vector3:
	return global_position + Vector3(1.2, -0.58, 0.0)


func stand_point() -> Vector3:
	var at := approach_point()
	return Vector3(at.x, 0.2, at.z)


func bench_key() -> String:
	var location := ""
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("current_location_id"):
		location = str(world.call("current_location_id"))
	var room: Node = self
	while room != null:
		var parent := room.get_parent()
		if parent != null and parent.name == "LocationHost":
			break
		room = parent
	var rel := name
	if room != null:
		rel = str(room.get_path_to(self))
	return "%s:%s" % [location, rel]


func try_fish(force := false) -> bool:
	var player := _local_player()
	if player == null or not player.has_method("plant_fish"):
		return false
	if player.has_method("is_fishing") and bool(player.call("is_fishing")) and player.call("current_bench") == self:
		return true
	var stand := approach_point()
	var flat := Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z)
	if not force and flat.length() > 1.35:
		return false
	if force and flat.length() > 2.4:
		return false
	if not Net.claim_bench(bench_key()):
		return false
	if not bool(player.call("plant_fish", self, stand_point(), _YAW)):
		Net.release_bench()
		return false
	return true


func can_interact() -> bool:
	return _prompt.visible and _prompt.text != "Taken"


func _process(_delta: float) -> void:
	var player := _local_player() as Node3D
	if player == null:
		_prompt.visible = false
		return
	var here := false
	if player.has_method("is_fishing") and bool(player.call("is_fishing")):
		here = player.call("current_bench") == self
	var stand := approach_point()
	var flat := Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z)
	var taken := Net.bench_held_by_other(bench_key())
	_prompt.text = "Taken" if taken else "F to fish"
	_prompt.visible = not here and flat.length() < 2.2


func _local_player() -> Node:
	return get_tree().get_first_node_in_group("local_player")
