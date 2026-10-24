extends CharacterBody3D

## Shared walk motor for camera-relative WASD and click-to-walk.
##
## WASD (and the arrow keys) moves up-screen when W is held. Holding any
## move key clears a click path. Releasing the keys stops in place and does
## not resume the old path. A new click retargets immediately.
##
## Model swap: replace the children of Visual with your imported GLB.
## Keep this body, CollisionShape3D, NavigationAgent3D, Shadow, and ClickMarker.
## Scale the model so its feet meet the shadow. If that import contains an
## AnimationPlayer with clips named "idle" and "walk", those play instead of
## the procedural waddle. This script never looks up a mesh by name.

@export var walk_speed := 4.5
@export var turn_speed := 10.0
@export var stop_distance := 0.2
@export var acceleration := 22.0

@onready var visual: Node3D = $Visual
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var shadow: MeshInstance3D = $Shadow
@onready var marker: MeshInstance3D = $ClickMarker

var _click_active := false
var _input_locked := false
var _phase := 0.0
var _clips: AnimationPlayer
var _foot_l: Node3D
var _foot_r: Node3D
var _flipper_l: Node3D
var _flipper_r: Node3D
var _foot_l_y := 0.0
var _foot_r_y := 0.0
var _flipper_l_x := 0.0
var _flipper_r_x := 0.0

const _GRAVITY := 28.0
const _CLICK_MASK := 3
const _FLOOR_LAYER := 1


func _ready() -> void:
	add_to_group("player")
	_ensure_actions()
	agent.target_desired_distance = stop_distance
	agent.path_desired_distance = 0.5
	agent.avoidance_enabled = false
	agent.debug_enabled = true
	agent.radius = 0.4
	agent.height = 1.2
	floor_snap_length = 0.25
	_pose_placeholder()
	_clips = _find_clips()
	marker.hide_marker()


func set_travel_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		halt()


func halt() -> void:
	_cancel_click()
	velocity = Vector3.ZERO


func face_point(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length_squared() < 0.0001:
		return
	rotation.y = atan2(-flat.x, -flat.z)


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event.is_action_pressed("click_walk"):
		_try_click()


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	var wish := Vector3.ZERO if _input_locked else _camera_wish()
	if wish != Vector3.ZERO:
		if _click_active:
			_cancel_click()
		direction = wish
	elif _click_active:
		direction = _follow_path()

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	planar = planar.move_toward(direction * walk_speed, acceleration * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	if not is_on_floor():
		velocity.y -= _GRAVITY * delta
	else:
		velocity.y = 0.0

	var facing := Vector3(velocity.x, 0.0, velocity.z)
	if facing.length() > 0.15:
		_turn_toward(facing, delta)

	move_and_slide()
	_plant_shadow()
	_animate(delta, facing.length())


## Starts a click-walk to a world point, snapped onto the snow mesh.
func command_walk_to(world_point: Vector3) -> void:
	_begin_click(_closest_nav_point(world_point))


func _try_click() -> void:
	if _camera_wish() != Vector3.ZERO:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var end := origin + camera.project_ray_normal(mouse) * 400.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, _CLICK_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var raw: Vector3 = hit.position
	var collider := hit.collider as Node
	if collider != null and collider.is_in_group("bus_stop") and collider.has_method("try_open"):
		if bool(collider.call("try_open")):
			return
	var point := _closest_nav_point(raw)
	var floor_body := hit.collider as CollisionObject3D
	var hit_floor := floor_body != null and (floor_body.collision_layer & _FLOOR_LAYER) != 0
	var snap := Vector2(point.x - raw.x, point.z - raw.z).length()
	if not hit_floor and snap > 4.0:
		return
	_begin_click(point)


func _begin_click(point: Vector3) -> void:
	_click_active = true
	agent.target_position = point
	marker.show_at(point)


func _cancel_click() -> void:
	_click_active = false
	marker.hide_marker()
	agent.target_position = global_position


func _follow_path() -> Vector3:
	var target := agent.target_position
	var offset := Vector2(global_position.x - target.x, global_position.z - target.z)
	if offset.length() <= stop_distance:
		_cancel_click()
		return Vector3.ZERO
	if agent.is_navigation_finished():
		if not agent.is_target_reachable():
			_cancel_click()
		return Vector3.ZERO
	var next := agent.get_next_path_position()
	var to_next := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if to_next.length() < 0.05:
		return Vector3.ZERO
	return to_next.normalized()


func _camera_wish() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.0001:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if forward.length_squared() < 0.0001 or right.length_squared() < 0.0001:
		return Vector3.ZERO
	forward = forward.normalized()
	right = right.normalized()
	# get_vector's y is -1 while move_forward is held, so up-screen is camera forward.
	var wish := right * input.x + forward * -input.y
	if wish.length_squared() < 0.0001:
		return Vector3.ZERO
	return wish.normalized()


func _closest_nav_point(world_pos: Vector3) -> Vector3:
	var map := agent.get_navigation_map()
	if not map.is_valid():
		return world_pos
	return NavigationServer3D.map_get_closest_point(map, world_pos)


func _turn_toward(direction: Vector3, delta: float) -> void:
	# Placeholder meshes face local -Z, Godot's forward axis.
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, turn_speed * delta)


func _plant_shadow() -> void:
	var planted := shadow.global_position
	planted.y = 0.03
	shadow.global_position = planted


func _animate(delta: float, speed: float) -> void:
	var moving := speed > 0.25
	if _clips:
		var clip := "walk" if moving else "idle"
		if _clips.current_animation != clip:
			_clips.play(clip)
		return
	if moving:
		_phase += speed * delta * 7.5
		visual.rotation = Vector3(deg_to_rad(6.0), 0.0, sin(_phase) * 0.16)
		visual.position.y = absf(sin(_phase * 2.0)) * 0.04
		_lift_foot(_foot_l, _foot_l_y, sin(_phase))
		_lift_foot(_foot_r, _foot_r_y, sin(_phase + PI))
		_swing_flipper(_flipper_l, _flipper_l_x, sin(_phase))
		_swing_flipper(_flipper_r, _flipper_r_x, sin(_phase + PI))
	else:
		_phase += delta * 1.7
		visual.rotation = Vector3.ZERO
		visual.position.y = sin(_phase) * 0.018
		_lift_foot(_foot_l, _foot_l_y, 0.0)
		_lift_foot(_foot_r, _foot_r_y, 0.0)
		_swing_flipper(_flipper_l, _flipper_l_x, 0.0)
		_swing_flipper(_flipper_r, _flipper_r_x, 0.0)


func _lift_foot(foot: Node3D, rest_y: float, wave: float) -> void:
	if foot == null:
		return
	foot.position.y = rest_y + maxf(wave, 0.0) * 0.09


func _swing_flipper(flipper: Node3D, rest_x: float, wave: float) -> void:
	if flipper == null:
		return
	flipper.rotation.x = rest_x + wave * 0.55


func _pose_placeholder() -> void:
	var beak := visual.get_node_or_null("Beak") as Node3D
	if beak:
		beak.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_flipper_l = visual.get_node_or_null("FlipperL") as Node3D
	_flipper_r = visual.get_node_or_null("FlipperR") as Node3D
	_foot_l = visual.get_node_or_null("FootL") as Node3D
	_foot_r = visual.get_node_or_null("FootR") as Node3D
	if _flipper_l:
		_flipper_l.rotation_degrees = Vector3(18.0, 0.0, 36.0)
		_flipper_l_x = _flipper_l.rotation.x
	if _flipper_r:
		_flipper_r.rotation_degrees = Vector3(18.0, 0.0, -36.0)
		_flipper_r_x = _flipper_r.rotation.x
	if _foot_l:
		_foot_l_y = _foot_l.position.y
	if _foot_r:
		_foot_r_y = _foot_r.position.y


func _find_clips() -> AnimationPlayer:
	for node in find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player.has_animation("idle") and player.has_animation("walk"):
			return player
	return null


func _ensure_actions() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	if not InputMap.has_action("click_walk"):
		InputMap.add_action("click_walk")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("click_walk", mouse)


func _add_keys(action: String, keycodes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keycodes:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event(action, key)
