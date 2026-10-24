extends StaticBody3D

## Shelter the penguin stands in front of. Clicking it opens the bus list.

@onready var _prompt: Label3D = $Prompt
@onready var _stand: Area3D = $StandArea

var _occupied := false


func _ready() -> void:
	add_to_group("bus_stop")
	collision_layer = 2
	collision_mask = 0
	_stand.collision_layer = 0
	_stand.collision_mask = 4
	_stand.monitoring = true
	_stand.body_entered.connect(_on_stand_entered)
	_stand.body_exited.connect(_on_stand_exited)
	_prompt.visible = false


func is_occupied() -> bool:
	return _occupied


func refresh_occupancy() -> void:
	_occupied = false
	for body in _stand.get_overlapping_bodies():
		if body.is_in_group("player"):
			_occupied = true
			break
	_refresh_prompt()


func try_open() -> bool:
	if not _occupied:
		return false
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("open_bus_menu"):
		world.call("open_bus_menu")
		_refresh_prompt()
		return true
	return false


func _process(_delta: float) -> void:
	if not _occupied:
		return
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if moving.length_squared() > 0.0001:
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("close_bus_menu"):
			world.call("close_bus_menu")
	_refresh_prompt()


func _on_stand_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_occupied = true
	_refresh_prompt()


func _on_stand_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_occupied = false
	_refresh_prompt()
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("close_bus_menu"):
		world.call("close_bus_menu")


func _refresh_prompt() -> void:
	var world := get_tree().get_first_node_in_group("world")
	var menu_open := world != null and world.has_method("is_bus_menu_open") and bool(world.call("is_bus_menu_open"))
	_prompt.visible = _occupied and not menu_open
