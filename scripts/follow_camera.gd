extends Node3D

## Fixed 3/4 follow. Pitch stays near 55 degrees, yaw stays locked.
## The rig eases toward the penguin and stops at the plaza limits so the
## snow edge stays in frame.

@export var target_path: NodePath
@export var follow_smooth := 6.0
@export var height := 8.0
@export var distance := 6.0
@export var look_height := 0.7
@export var limit_x := 7.5
@export var limit_z := 5.0

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
var _center := Vector3.ZERO


func set_frame(center: Vector3, next_limit_x: float, next_limit_z: float) -> void:
	_center = center
	limit_x = next_limit_x
	limit_z = next_limit_z
	if _target != null:
		global_position = _clamped_focus()


func _ready() -> void:
	_target = get_node(target_path) as Node3D
	camera.fov = 35.0
	camera.current = true
	camera.position = Vector3(0.0, height, distance)
	global_position = _clamped_focus()
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	var light := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)


func _process(delta: float) -> void:
	if _target == null:
		return
	var blend := 1.0 - exp(-follow_smooth * delta)
	global_position = global_position.lerp(_clamped_focus(), blend)


func _clamped_focus() -> Vector3:
	var focus := _target.global_position
	focus.x = clampf(focus.x, _center.x - limit_x, _center.x + limit_x)
	focus.y = 0.0
	focus.z = clampf(focus.z, _center.z - limit_z, _center.z + limit_z)
	return focus
