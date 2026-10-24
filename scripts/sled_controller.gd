extends CharacterBody3D

## Downhill sled. Holds a steady pace and steers with A and D.
## Trees and rocks overlap HazardProbe and end the run.
## The plaza walk script is not attached here.

signal crashed
signal finished

@export var forward_speed := 10.0
@export var steer_speed := 12.0
@export var turn_speed := 7.0
@export var finish_z := -180.0

var distance := 0.0
var running := false

var _origin_z := 0.0
var _ended := false
var _crashed := false
var _steer := 0.0
var _tip := 0.0
var _remote := false
var _net_target := Vector3.ZERO
var _net_yaw := 0.0
var _net_steer := 0.0
var _net_crashed := false
var _has_net := false
var _name_label: Label3D
var _tint_applied := -1

@onready var visual: Node3D = $Visual
@onready var probe: Area3D = $HazardProbe

const _GRAVITY := 28.0


func _ready() -> void:
	_drop("NavigationAgent3D")
	_drop("ClickMarker")
	if int(get_meta("remote_peer", 0)) != 0:
		_remote = true
		_name_label = null
		_tint_applied = -1
		var copied := get_node_or_null("NameLabel")
		if copied:
			copied.free()
		collision_layer = 0
		collision_mask = 0
		probe.monitoring = false
		probe.monitorable = false
		_pose()
		return
	_pose()
	probe.monitoring = true
	probe.area_entered.connect(_on_hazard)
	floor_snap_length = 0.4


func begin() -> void:
	if _ended:
		return
	_origin_z = global_position.z
	running = true
	for area in probe.get_overlapping_areas():
		_end_crash()
		return


func reset_run(point: Vector3) -> void:
	_ended = false
	_crashed = false
	running = false
	distance = 0.0
	_steer = 0.0
	_tip = 0.0
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	if visual:
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
	global_position = point


func present_remote(at: Vector3, yaw: float, steer: float, crashed: bool) -> void:
	if not _has_net or global_position.distance_to(at) > 4.0:
		global_position = at
		rotation.y = yaw
	_net_target = at
	_net_yaw = yaw
	_net_steer = steer
	_net_crashed = crashed
	_has_net = true


func apply_identity(player_name: String, color_index: int) -> void:
	if _name_label == null or not is_instance_valid(_name_label):
		_name_label = Label3D.new()
		_name_label.name = "NameLabel"
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.font_size = 42
		_name_label.outline_size = 8
		_name_label.pixel_size = 0.005
		_name_label.position = Vector3(0.0, 1.55, 0.0)
		_name_label.modulate = Color(0.97, 0.98, 1.0)
		_name_label.outline_modulate = Color(0.08, 0.14, 0.22)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_name_label)
	_name_label.text = player_name
	if _tint_applied == color_index:
		return
	_tint_applied = color_index
	var coat := Net.coat_color(color_index)
	if not AssetPack.recolor_body(visual, coat):
		_tint(visual.get_node_or_null("Body") as MeshInstance3D, coat)
		_tint(visual.get_node_or_null("FlipperL") as MeshInstance3D, coat)
		_tint(visual.get_node_or_null("FlipperR") as MeshInstance3D, coat)
	_tint(get_node_or_null("Deck") as MeshInstance3D, coat)
	_tint(get_node_or_null("Nose") as MeshInstance3D, coat)


func _physics_process(delta: float) -> void:
	if _remote:
		return
	if running:
		_steer = Input.get_axis("move_left", "move_right")
		velocity.x = _steer * steer_speed
		velocity.z = -forward_speed
	else:
		_steer = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 45.0 * delta)

	if not is_on_floor():
		velocity.y -= _GRAVITY * delta
	else:
		velocity.y = 0.0

	var facing := Vector3(velocity.x, 0.0, velocity.z)
	if running and facing.length() > 0.2:
		var target_yaw := atan2(-facing.x, -facing.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, turn_speed * delta)

	move_and_slide()
	if running:
		distance = maxf(distance, _origin_z - global_position.z)
		if global_position.z <= finish_z:
			_end_finish()
	if Net.is_online():
		Net.note_sled(global_position, rotation.y, _steer, _crashed)


func _process(delta: float) -> void:
	if _remote and _has_net:
		var blend := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(_net_target, blend)
		rotation.y = lerp_angle(rotation.y, _net_yaw, blend)
		_steer = _net_steer
		_crashed = _net_crashed
	if visual == null:
		return
	if _crashed:
		_tip = move_toward(_tip, 1.0, delta * 2.4)
		visual.rotation.x = _tip * deg_to_rad(74.0)
		visual.rotation.z = _tip * 0.4
		return
	var blend := 1.0 - exp(-8.0 * delta)
	visual.rotation.z = lerp(visual.rotation.z, -_steer * 0.22, blend)
	visual.rotation.x = lerp(visual.rotation.x, 0.0, blend)


func _on_hazard(_area: Area3D) -> void:
	if not running:
		return
	_end_crash()


func _end_crash() -> void:
	if _ended:
		return
	_ended = true
	_crashed = true
	running = false
	crashed.emit()


func _end_finish() -> void:
	if _ended:
		return
	_ended = true
	running = false
	velocity = Vector3.ZERO
	finished.emit()


func _pose() -> void:
	var beak := visual.get_node_or_null("Beak") as Node3D
	if beak:
		beak.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var flipper_l := visual.get_node_or_null("FlipperL") as Node3D
	var flipper_r := visual.get_node_or_null("FlipperR") as Node3D
	if flipper_l:
		flipper_l.rotation_degrees = Vector3(18.0, 0.0, 36.0)
	if flipper_r:
		flipper_r.rotation_degrees = Vector3(18.0, 0.0, -36.0)


func _tint(mesh: MeshInstance3D, color: Color) -> void:
	if mesh == null:
		return
	var source := mesh.get_surface_override_material(0) as StandardMaterial3D
	if source == null:
		return
	var mat := source.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)


func _drop(node_name: String) -> void:
	var node := get_node_or_null(node_name)
	if node:
		node.queue_free()
