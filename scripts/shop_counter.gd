extends Node3D

## Stand in front of the keeper. F, or the Look pill, opens the shop panel.

var shop_id := ""
var prompt_text := "Look"

const _REACH := 1.65


func bind(id: String, prompt: String) -> void:
	shop_id = id
	prompt_text = prompt
	add_to_group("shop_counter")


func approach_point() -> Vector3:
	return global_position


func can_interact() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or shop_id == "":
		return false
	if world.has_method("is_shop_open") and bool(world.call("is_shop_open")):
		return false
	if world.has_method("is_traveling") and bool(world.call("is_traveling")):
		return false
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		return false
	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	return flat.length() <= _REACH


func try_open() -> bool:
	if not can_interact():
		return false
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("open_shop"):
		return bool(world.call("open_shop", shop_id))
	return false
