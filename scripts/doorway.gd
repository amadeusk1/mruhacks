extends Area3D

## Walk-in door between the igloo and the yard.
## The landing marker sits outside this volume so the trip cannot bounce.

@export var spawn_name := "OutsideSpawn"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = false
	body_entered.connect(_on_body_entered)
	await get_tree().physics_frame
	monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("local_player"):
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("shift_to_marker"):
		return
	if world.has_method("is_traveling") and bool(world.call("is_traveling")):
		return
	if world.has_method("is_bus_menu_open") and bool(world.call("is_bus_menu_open")):
		return
	world.call("shift_to_marker", spawn_name)
