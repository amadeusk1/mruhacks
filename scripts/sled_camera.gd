extends Node3D

## Chase camera for the hill. Sits behind the sled and looks a few meters
## down the course so the next tree or rock is on screen.
## Yaw stays locked. The plaza camera limits are not used here.

@export var target_path: NodePath
@export var follow_smooth := 7.0
@export var height := 9.0
@export var distance := 8.5
@export var look_height := 0.7
@export var fov := 42.0
@export var lead := 3.5

@onready var camera: Camera3D = $Camera3D

var _target: Node3D


func _ready() -> void:
	_target = get_node(target_path) as Node3D
	camera.fov = fov
	camera.current = true
	camera.position = Vector3(0.0, height, distance)
	global_position = _focus()
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _target == null:
		return
	var blend := 1.0 - exp(-follow_smooth * delta)
	var y := lerpf(global_position.y, _focus().y, 1.0 - exp(-follow_smooth * 0.5 * delta))  # bumps and jumps don't shake the shot
	global_position = global_position.lerp(_focus(), blend)
	global_position.y = y


func _focus() -> Vector3:
	var focus := _target.global_position
	focus.z -= lead  # the rider's own height: the run drops several metres, the frame goes down with it
	return focus
