extends Node3D

## A penguin who lives in town. Keepers greet you. Others may stroll a route.
## No collision, so a gathering in the square never blocks a door.

enum Accessory { SCARF, APRON, BAND }

@export var coat_color := Color(0.16, 0.2, 0.28)
@export var accent_color := Color(0.93, 0.45, 0.38)
@export var penguin_name := ""
@export var greeting := ""
@export var accessory: Accessory = Accessory.SCARF
@export var face_look_at := false
@export var look_at_point := Vector3.ZERO
@export var route: Array[NodePath] = []
@export var walk_speed := 1.4

@onready var _visual: Node3D = $Visual
@onready var _speech: Label3D = $Speech
@onready var _greet: Area3D = $Greet

var _phase := 0.0
var _near := false
var _moving := false
var _points: Array[Vector3] = []
var _index := 0
var _pause := 0.0
var _flipper_l: Node3D
var _flipper_r: Node3D
var _flipper_l_x := 0.0
var _flipper_r_x := 0.0


var _clips: AnimationPlayer


func _ready() -> void:
	_clips = _mount_pack()
	if _clips == null:
		_tint($Visual/Body, coat_color)
		_tint($Visual/FlipperL, coat_color)
		_tint($Visual/FlipperR, coat_color)
		_tint($Visual/Scarf, accent_color)
		_apply_accessory()
		_pose()
	$NameLabel.text = penguin_name
	$NameLabel.visible = penguin_name != ""
	_speech.text = greeting
	_speech.visible = false
	_greet.collision_layer = 0
	_greet.collision_mask = 4
	if greeting == "":
		_greet.monitoring = false
	else:
		_greet.monitoring = true
		_greet.body_entered.connect(_on_body_entered)
		_greet.body_exited.connect(_on_body_exited)
	if face_look_at:
		_face(look_at_point)
	for path in route:
		var mark := get_node_or_null(path) as Node3D
		if mark:
			_points.append(mark.global_position)
	if not _points.is_empty():
		global_position = Vector3(_points[0].x, 0.0, _points[0].z)


func _physics_process(delta: float) -> void:
	_step_route(delta)
	_animate(delta)


func _step_route(delta: float) -> void:
	_moving = false
	if _points.size() < 2:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var target := _points[_index]
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() < 0.18:
		var along_center := absf(target.x) < 0.45
		_index = (_index + 1) % _points.size()
		_pause = 2.3 if along_center else 0.35
		return
	var step := flat.normalized()
	global_position += step * walk_speed * delta
	global_position.y = 0.0
	rotation.y = atan2(-step.x, -step.z)
	_moving = true


func _mount_pack() -> AnimationPlayer:
	match accessory:
		Accessory.APRON:
			return AssetPack.mount_bird(_visual, coat_color, "cafe_apron", "", "head", accent_color)
		Accessory.BAND:
			return AssetPack.mount_bird(_visual, coat_color, "", "headphones", "head", accent_color)
		_:
			return AssetPack.mount_bird(_visual, coat_color, "", "scarf", "neck", accent_color)


func _animate(delta: float) -> void:
	if _clips:
		var clip := "walk" if _moving else ("wave" if _near and _clips.has_animation("wave") else "idle")
		if _clips.current_animation != clip:
			_clips.play(clip)
		_visual.rotation = Vector3.ZERO
		_visual.position.y = 0.0
		return
	if _moving:
		_phase += delta * 7.5
		_visual.rotation = Vector3(deg_to_rad(6.0), 0.0, sin(_phase) * 0.16)
		_visual.position.y = absf(sin(_phase * 2.0)) * 0.04
		if _flipper_r:
			_flipper_r.rotation.x = _flipper_r_x
		return
	_phase += delta * 1.7
	_visual.rotation = Vector3.ZERO
	_visual.position.y = sin(_phase) * 0.018
	if _flipper_r:
		if _near:
			_flipper_r.rotation.x = _flipper_r_x + sin(_phase * 3.0) * 0.75
		else:
			_flipper_r.rotation.x = _flipper_r_x


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length_squared() < 0.0001:
		return
	rotation.y = atan2(-flat.x, -flat.z)


func _apply_accessory() -> void:
	var scarf := $Visual/Scarf as Node3D
	match accessory:
		Accessory.SCARF:
			scarf.position = Vector3(0.0, 0.74, -0.08)
			scarf.scale = Vector3(0.46, 0.1, 0.32)
		Accessory.APRON:
			scarf.position = Vector3(0.0, 0.52, -0.34)
			scarf.scale = Vector3(0.38, 0.32, 0.08)
		Accessory.BAND:
			scarf.position = Vector3(0.0, 0.7, 0.0)
			scarf.scale = Vector3(0.48, 0.08, 0.42)


func _tint(mesh: MeshInstance3D, color: Color) -> void:
	var mat := mesh.get_surface_override_material(0)
	if mat == null:
		return
	mat = mat.duplicate()
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)


func _pose() -> void:
	var beak := $Visual/Beak as Node3D
	beak.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_flipper_l = $Visual/FlipperL
	_flipper_r = $Visual/FlipperR
	_flipper_l.rotation_degrees = Vector3(18.0, 0.0, 36.0)
	_flipper_r.rotation_degrees = Vector3(18.0, 0.0, -36.0)
	_flipper_l_x = _flipper_l.rotation.x
	_flipper_r_x = _flipper_r.rotation.x


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_near = true
	_speech.visible = true


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_near = false
	_speech.visible = false
