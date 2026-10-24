extends Node3D

## Chase camera for the hill: low behind the sled, swinging with its heading through the bends,
## looking a few metres down the course. Field of view widens with speed (and kicks on a boost);
## speed lines fade in past cruising speed. Height is smoothed so bumps and jumps don't shake it.

@export var target_path: NodePath
@export var follow_smooth := 6.0
@export var height := 2.9
@export var distance := 5.8
@export var look_height := -1.6
@export var fov := 58.0
@export var lead := 7.0

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
var _yaw := 0.0
var _kick := 0.0
var _lines: ColorRect


func _ready() -> void:
	_target = get_node(target_path) as Node3D
	camera.fov = fov
	camera.current = true
	camera.far = 260.0
	_yaw = _target.rotation.y
	snap()
	if _target.has_signal("boosted"):
		_target.connect("boosted", func() -> void: _kick = 1.0)
	var layer := CanvasLayer.new()
	layer.layer = -1  # under the HUD
	add_child(layer)
	_lines = ColorRect.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/activities/speed_lines.gdshader")
	_lines.material = m
	layer.add_child(_lines)


## Jump straight to the chase position (after a reset).
func snap() -> void:
	_yaw = _target.rotation.y
	global_position = _target.global_position
	_place(1.0)


func _process(delta: float) -> void:
	if _target == null:
		return
	_yaw = lerp_angle(_yaw, _target.rotation.y, 1.0 - exp(-3.2 * delta))
	var blend := 1.0 - exp(-follow_smooth * delta)
	var y := lerpf(global_position.y, _target.global_position.y, 1.0 - exp(-follow_smooth * 0.6 * delta))
	global_position = global_position.lerp(_target.global_position, blend)
	global_position.y = y
	_place(delta)


func _place(delta: float) -> void:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	camera.global_position = global_position + back * distance + Vector3.UP * height
	camera.look_at(global_position - back * lead + Vector3.UP * look_height, Vector3.UP)
	var speed := float(_target.get("speed")) if "speed" in _target else 0.0
	_kick = move_toward(_kick, 0.0, delta * 1.4)
	camera.fov = lerpf(camera.fov, fov + clampf(speed - 10.0, 0.0, 14.0) * 0.9 + _kick * 8.0, 1.0 - exp(-4.0 * delta))
	if _lines:
		(_lines.material as ShaderMaterial).set_shader_parameter("strength", clampf((speed - 13.0) / 9.0, 0.0, 1.0) * 0.7 + _kick * 0.3)
