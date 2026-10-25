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
var _pin_on := false
var _pin := Vector3.ZERO
var _saved_height := 8.0
var _saved_distance := 6.0
var _saved_look := 0.7
var _saved_smooth := 6.0
var _ground_y := 0.0  # the penguin's height on the last floor it stood on: hills and decks lift the frame, a jump does not


func set_frame(center: Vector3, next_limit_x: float, next_limit_z: float, next_height: float = -1.0, next_distance: float = -1.0) -> void:
	_center = center
	limit_x = next_limit_x
	limit_z = next_limit_z
	height = 8.0 if next_height < 0.0 else next_height
	distance = 6.0 if next_distance < 0.0 else next_distance
	camera.position = Vector3(0.0, height, distance)
	if _target != null:
		global_position = _clamped_focus()
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)


## Hold the frame on a world point (the roulette wheel) instead of the penguin.
## A second call tightens the same shot; unpin_focus restores the room camera.
func pin_focus(point: Vector3, next_height: float, next_distance: float, look_y: float) -> void:
	if not _pin_on:
		_saved_height = height
		_saved_distance = distance
		_saved_look = look_height
		_saved_smooth = follow_smooth
	_pin_on = true
	_pin = point
	height = next_height
	distance = next_distance
	look_height = look_y
	follow_smooth = 2.4
	camera.position = Vector3(0.0, height, distance)


func unpin_focus() -> void:
	if not _pin_on:
		return
	_pin_on = false
	height = _saved_height
	distance = _saved_distance
	look_height = _saved_look
	follow_smooth = _saved_smooth
	camera.position = Vector3(0.0, height, distance)
	_aim()


func _ready() -> void:
	add_to_group("follow_camera")
	_target = get_node(target_path) as Node3D
	_ground_y = _target.global_position.y if _target else 0.0
	camera.fov = 35.0
	camera.current = true
	camera.position = Vector3(0.0, height, distance)
	global_position = _clamped_focus()
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	var light := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)


func add_yaw(delta: float) -> void:
	if _pin_on:
		return
	rotation.y = wrapf(rotation.y + delta, -PI, PI)


func _process(delta: float) -> void:
	if _target == null:
		return
	if not (_target is CharacterBody3D) or (_target as CharacterBody3D).is_on_floor():
		_ground_y = _target.global_position.y
	var blend := 1.0 - exp(-follow_smooth * delta)
	var focus := _clamped_focus()
	var y := lerpf(global_position.y, focus.y, 1.0 - exp(-follow_smooth * 0.6 * delta))  # a little softer on steps
	global_position = global_position.lerp(focus, blend)
	global_position.y = y
	if _pin_on:
		_aim()


func _aim() -> void:
	var at := global_position + Vector3(0.0, look_height, 0.0)
	if camera.global_position.distance_squared_to(at) < 0.01:
		return
	camera.look_at(at, Vector3.UP)


func _clamped_focus() -> Vector3:
	if _pin_on:
		return Vector3(_pin.x, 0.0, _pin.z)  # callers aim with look_y from the floor
	var focus := _target.global_position
	focus.x = clampf(focus.x, _center.x - limit_x, _center.x + limit_x)
	focus.y = _ground_y
	focus.z = clampf(focus.z, _center.z - limit_z, _center.z + limit_z)
	return focus
