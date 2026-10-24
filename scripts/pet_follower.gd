extends Node3D

## The owned pet that is currently out. No collision, so it never blocks a door.
## Pebble trails and sits. Slick stays beside you and splashes on the dock.
## Ember trots ahead and looks back when you stop.

var _kind := ""
var _body: Node


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	var id := ""
	if world != null and world.has_method("active_pet_id"):
		id = str(world.call("active_pet_id"))
	if id == "" or player == null or not player.visible:
		visible = false
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
	match _kind:
		"slick":
			goal += right * 0.72 - forward * 0.2
		"ember":
			goal += forward * 0.95
		_:
			goal += -forward * 0.88 + right * 0.15
	goal.y = 0.0
	var dist := Vector2(global_position.x - goal.x, global_position.z - goal.z).length()
	if fresh or dist > 7.5 or global_position.y < -2.0:
		global_position = goal
	else:
		var rate := 3.4 + dist * 2.8
		if _kind == "ember":
			rate += 1.5
		elif _kind == "slick":
			rate += 0.5
		global_position.x = move_toward(global_position.x, goal.x, rate * delta)
		global_position.z = move_toward(global_position.z, goal.z, rate * delta)
		global_position.y = 0.0
	var face := goal - global_position
	if _kind == "ember" and not moving:
		face = player.global_position - global_position
	elif _kind == "pebble" and not moving:
		face = player.global_position - global_position
	elif face.length_squared() < 0.002:
		face = forward
	face.y = 0.0
	if face.length_squared() > 0.0004:
		var yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 8.0))
	var on_dock := false
	if _kind == "slick" and world != null and world.has_method("current_location_id"):
		if str(world.call("current_location_id")) == "plaza":
			on_dock = player.global_position.x < -11.2 and absf(player.global_position.z) < 7.0
	if _body != null and _body.has_method("set_follow_state"):
		_body.call("set_follow_state", moving, on_dock)


func _mount(id: String) -> void:
	_kind = id
	if _body != null:
		_body.free()
	_body = Node3D.new()
	_body.set_script(preload("res://scripts/pet_body.gd"))
	add_child(_body)
	_body.call("setup", id, false)
