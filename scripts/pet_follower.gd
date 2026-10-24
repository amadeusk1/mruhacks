extends Node3D

## The owned pet that is currently out. No collision, so it never blocks a door.
## Penguins walk on the ground with no leash. Fish hover beside you on a leash.
## The mesh already sits at the right height, so this node stays on the ground.

var _kind := ""
var _body: Node
var _lead_a: MeshInstance3D
var _lead_b: MeshInstance3D


func _ready() -> void:
	visible = false
	_lead_a = _rope()
	_lead_b = _rope()
	add_child(_lead_a)
	add_child(_lead_b)


func _process(delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	var id := ""
	if world != null and world.has_method("active_pet_id"):
		id = str(world.call("active_pet_id"))
	if id == "" or player == null or not player.visible:
		visible = false
		_lead_a.visible = false
		_lead_b.visible = false
		return
	visible = true
	var fresh := id != _kind
	if fresh:
		_mount(id)
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var right := player.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3(1.0, 0.0, 0.0)
	else:
		right = right.normalized()
	var speed := 0.0
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	var moving := speed > 0.35
	var goal := player.global_position
	var on_court := world != null and world.has_method("current_location_id") and str(world.call("current_location_id")) == "court"
	var family := str(PetCatalog.find(_kind).get("family", "penguin"))
	if on_court:
		goal = Vector3(3.4, 0.0, 5.6)
	elif family == "fish":
		goal += right * 0.72 - forward * 0.15
	else:
		goal += -forward * 0.85 + right * 0.18
	goal.y = 0.0
	var dist := Vector2(global_position.x - goal.x, global_position.z - goal.z).length()
	if fresh or dist > 7.5 or global_position.y < -2.0:
		global_position = goal
	else:
		var rate := 3.4 + dist * 2.8
		if family == "fish":
			rate += 0.6
		global_position.x = move_toward(global_position.x, goal.x, rate * delta)
		global_position.z = move_toward(global_position.z, goal.z, rate * delta)
		global_position.y = 0.0
	var face := goal - global_position
	if not moving:
		face = player.global_position - global_position
	elif face.length_squared() < 0.002:
		face = forward
	face.y = 0.0
	if face.length_squared() > 0.0004:
		var yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 8.0))
	if _body != null and _body.has_method("set_follow_state"):
		_body.call("set_follow_state", moving, false)
	if family == "penguin" or on_court:
		_lead_a.visible = false
		_lead_b.visible = false
	else:
		_update_leash(player, right)


func _update_leash(player: Node3D, right: Vector3) -> void:
	var hip := player.global_position + Vector3.UP * 0.36 - right * 0.2
	var collar := hip
	var socket := _body.find_child("socket_collar", true, false) if _body else null
	if socket is Node3D:
		collar = (socket as Node3D).global_position
	var mid := (hip + collar) * 0.5
	mid.y -= 0.05
	_aim_rope(_lead_a, hip, mid)
	_aim_rope(_lead_b, mid, collar)


func _aim_rope(rope: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.02:
		rope.visible = false
		return
	rope.visible = true
	var cyl := rope.mesh as CylinderMesh
	cyl.height = length
	rope.global_position = (a + b) * 0.5
	var y := delta / length
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	rope.global_basis = Basis(x, y, x.cross(y).normalized())


func _rope() -> MeshInstance3D:
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.2
	cyl.radial_segments = 6
	rope.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.79, 0.66, 0.45)
	mat.roughness = 0.9
	rope.material_override = mat
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return rope


func _mount(id: String) -> void:
	_kind = id
	if _body != null:
		_body.free()
	_body = Node3D.new()
	_body.set_script(preload("res://scripts/pet_body.gd"))
	add_child(_body)
	_body.call("setup", id, false)
