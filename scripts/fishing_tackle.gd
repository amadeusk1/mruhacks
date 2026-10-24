extends Node3D

## Rod, line, and bobber for whoever is fishing. The catch bar stays local.

const WATER_Y := -0.34

var _phase := ""
var _model := ""
var _age := 0.0
var _rod: Node3D
var _bobber: Node3D
var _ripple: Node3D
var _line: MeshInstance3D
var _prize: Node3D
var _tip: Node3D


func set_phase(phase: String) -> void:
	var model := ""
	var kind := phase
	if phase.begins_with("catch:"):
		kind = "catch"
		model = phase.substr(6)
	if kind == _phase and model == _model:
		return
	_phase = kind
	_model = model
	_age = 0.0
	if _phase == "":
		_clear()
		return
	_ensure_rod()
	_ensure_bobber()
	if _phase == "catch":
		_show_prize()
	else:
		_drop_prize()
	if _bobber:
		_bobber.visible = _phase != "catch"


func _process(delta: float) -> void:
	if _phase == "":
		return
	_age += delta
	var penguin := get_parent() as Node3D
	if penguin == null:
		return
	var forward := -penguin.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3(-1.0, 0.0, 0.0)
	forward = forward.normalized()
	var target := penguin.global_position + forward * 1.8
	target.y = WATER_Y
	if _phase == "bite":
		target.y = WATER_Y - 0.16 - sin(_age * 18.0) * 0.04
	elif _phase == "reel":
		target.y = WATER_Y - 0.05
	var from := penguin.global_position + Vector3(0.0, 0.85, 0.0)
	var bob := target
	if _phase == "cast":
		bob = from.lerp(target, clampf(_age / 0.45, 0.0, 1.0))
		bob.y = lerpf(from.y, target.y, clampf(_age / 0.45, 0.0, 1.0))
	if _bobber:
		_bobber.visible = _phase != "catch"
		_bobber.global_position = bob
	if _ripple:
		_ripple.visible = _phase != "catch" and _phase != "cast"
		_ripple.global_position = Vector3(target.x, WATER_Y + 0.02, target.z)
		var pulse := 1.15 + sin(_age * 3.0) * 0.12
		_ripple.scale = Vector3(pulse, 1.0, pulse)
	_aim_line(bob)
	if _prize:
		_prize.global_position = penguin.global_position + forward * 0.55 + Vector3(0.0, 0.85, 0.0)
		_prize.rotate_y(delta * 1.4)


func _ensure_rod() -> void:
	if _rod != null and is_instance_valid(_rod):
		return
	var penguin := get_parent() as Node3D
	if penguin == null:
		return
	var visual := penguin.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var bird := visual.get_node_or_null("PackAvatar") as Node3D
	var hand: Node3D = null
	if bird:
		hand = Sockets.find(bird, "hand_R")
	if hand == null:
		hand = visual.get_node_or_null("FlipperR") as Node3D
	if hand == null:
		hand = visual
	_rod = AssetPack.spawn("avatar", "fishing_rod")
	if _rod == null:
		return
	hand.add_child(_rod)
	_rod.position = Vector3.ZERO
	_rod.rotation = Vector3.ZERO
	_tip = Sockets.find(_rod, "line_tip")


func _ensure_bobber() -> void:
	if _bobber != null and is_instance_valid(_bobber):
		return
	_bobber = AssetPack.spawn("fishing", "bobber")
	if _bobber == null:
		_bobber = MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.08
		ball.height = 0.16
		(_bobber as MeshInstance3D).mesh = ball
	_bobber.top_level = true
	add_child(_bobber)
	_ripple = AssetPack.spawn("fishing", "ripple")
	if _ripple:
		_ripple.top_level = true
		add_child(_ripple)
	_line = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.018, 0.018, 1.0)
	_line.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.96, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = mat
	_line.top_level = true
	add_child(_line)


func _show_prize() -> void:
	_drop_prize()
	var which := _model if _model != "" else "fish_round"
	_prize = AssetPack.spawn("fishing", which)
	if _prize == null:
		return
	_prize.top_level = true
	_prize.scale = Vector3.ONE * 1.35
	add_child(_prize)


func _aim_line(bob: Vector3) -> void:
	if _line == null:
		return
	var origin := bob
	if _tip != null and is_instance_valid(_tip):
		origin = _tip.global_position
	elif _rod != null and is_instance_valid(_rod):
		origin = _rod.global_position
	var span := bob - origin
	var length := span.length()
	if length < 0.05:
		_line.visible = false
		return
	_line.visible = _phase != "catch"
	_line.global_position = origin + span * 0.5
	_line.global_basis = Basis.looking_at(span / length, Vector3.UP)
	_line.scale = Vector3(1.0, 1.0, length)


func _drop_prize() -> void:
	if _prize != null and is_instance_valid(_prize):
		_prize.queue_free()
	_prize = null


func _clear() -> void:
	_drop_prize()
	if _rod != null and is_instance_valid(_rod):
		_rod.queue_free()
	_rod = null
	_tip = null
	if _bobber != null and is_instance_valid(_bobber):
		_bobber.queue_free()
	_bobber = null
	if _ripple != null and is_instance_valid(_ripple):
		_ripple.queue_free()
	_ripple = null
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
