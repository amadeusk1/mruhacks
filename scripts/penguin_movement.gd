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
var _typing_locked := false
var _phase := 0.0
var _clips: AnimationPlayer
var _foot_l: Node3D
var _foot_r: Node3D
var _flipper_l: Node3D
var _flipper_r: Node3D
var _foot_l_y := 0.0
var _foot_r_y := 0.0
var _foot_l_z := 0.0
var _foot_r_z := 0.0
var _flipper_l_x := 0.0
var _flipper_r_x := 0.0
var _sitting := false
var _fishing := false
var _reel_focus := false
var _fisher_phase := ""
var _fish_hud: Node
var _tackle: Node3D
var _seat_bench: Node
var _seat_point := Vector3.ZERO
var _stand_point := Vector3.ZERO
var _pending_bench: Node
var _remote_peer := 0
var _net_target := Vector3.ZERO
var _net_yaw := 0.0
var _net_speed := 0.0
var _net_sitting := false
var _has_net_pose := false
var _name_label: Label3D
var _tint_applied := -1

const _GRAVITY := 28.0
const _CLICK_MASK := 3
const _FLOOR_LAYER := 1


func _ready() -> void:
	_remote_peer = int(get_meta("remote_peer", 0))
	if _remote_peer != 0:
		_setup_remote()
		return
	add_to_group("player")
	add_to_group("local_player")
	_ensure_actions()
	agent.target_desired_distance = stop_distance
	agent.path_desired_distance = 0.5
	agent.avoidance_enabled = false
	agent.debug_enabled = true
	agent.radius = 0.4
	agent.height = 1.2
	floor_snap_length = 0.25
	_mount_pack(Color(0.24, 0.49, 0.84))
	_pose_placeholder()
	_clips = _find_clips()
	marker.hide_marker()


func set_travel_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		_clear_seat(false)
		halt()


## Chat focus. Stops walking without pulling the penguin out of a seat.
func set_typing_locked(locked: bool) -> void:
	_typing_locked = locked
	if locked:
		_pending_bench = null
		_cancel_click()
		if not _sitting:
			velocity = Vector3(0.0, velocity.y, 0.0)


func is_sitting() -> bool:
	return _sitting


func is_fishing() -> bool:
	return _fishing


func current_bench() -> Node:
	return _seat_bench


func plant_fish(spot: Node, stand: Vector3, yaw: float) -> bool:
	if _blocks_play():
		return false
	if _fishing and _seat_bench == spot:
		return true
	halt()
	_sitting = true
	_fishing = true
	_seat_bench = spot
	_seat_point = stand
	_stand_point = stand
	global_position = stand
	velocity = Vector3.ZERO
	rotation.y = yaw
	if _fish_hud == null:
		_fish_hud = load("res://scripts/fishing_hud.gd").new()
		add_child(_fish_hud)
		_fish_hud.call("open", self)
	return true


func set_fish_phase(phase: String) -> void:
	_fisher_phase = phase
	_tackle_node().set_phase(phase)
	if _remote_peer == 0:
		Net.note_fisher(phase)


func set_reel_focus(locked: bool) -> void:
	_reel_focus = locked


func apply_fisher(phase: String) -> void:
	if _remote_peer == 0 or phase == _fisher_phase:
		return
	_fisher_phase = phase
	if phase == "" and visual:
		visual.rotation.x = 0.0
	_tackle_node().set_phase(phase)


func sit_down(bench: Node, seat: Vector3, yaw: float, stand: Vector3) -> void:
	if _blocks_play():
		return
	halt()
	_sitting = true
	_seat_bench = bench
	_seat_point = seat
	_stand_point = stand
	global_position = seat
	velocity = Vector3.ZERO
	rotation.y = yaw


func stand_up() -> void:
	_clear_seat(true)


func halt() -> void:
	_pending_bench = null
	_cancel_click()
	velocity = Vector3.ZERO


func face_point(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length_squared() < 0.0001:
		return
	rotation.y = atan2(-flat.x, -flat.z)


func _unhandled_input(event: InputEvent) -> void:
	if _remote_peer != 0 or _blocks_play() or _reel_focus:
		return
	if event.is_action_pressed("interact"):
		if _try_interact():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("click_walk"):
		_try_click(event)


func _physics_process(delta: float) -> void:
	if _remote_peer != 0:
		_step_remote(delta)
		return
	var direction := Vector3.ZERO
	var wish := Vector3.ZERO if _blocks_play() else _camera_wish()
	if _sitting and wish != Vector3.ZERO:
		stand_up()
	if _sitting:
		global_position = _seat_point
		velocity = Vector3.ZERO
		_plant_shadow()
		_animate(delta, 0.0)
		_publish_pose()
		return
	if wish != Vector3.ZERO:
		if _click_active:
			_pending_bench = null
			_cancel_click()
		direction = wish
	elif _click_active:
		direction = _follow_path()
	if _sitting:
		global_position = _seat_point
		velocity = Vector3.ZERO
		_plant_shadow()
		_animate(delta, 0.0)
		_publish_pose()
		return

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
	_publish_pose()


## Starts a click-walk to a world point, snapped onto the snow mesh.
func command_walk_to(world_point: Vector3) -> void:
	_begin_click(_closest_nav_point(world_point))


## Uses the nearest bench, fishing spot, or bus stop whose prompt is showing.
func _try_interact() -> bool:
	if _sitting:
		return false
	var best: Node = null
	var best_dist := INF
	for group in ["bench", "fish_spot", "bus_stop"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node.has_method("can_interact") or not bool(node.call("can_interact")):
				continue
			var at := _interact_point(node)
			var dist := Vector2(global_position.x - at.x, global_position.z - at.z).length()
			if dist < best_dist:
				best = node
				best_dist = dist
	if best == null:
		return false
	if best.has_method("try_fish"):
		return bool(best.call("try_fish", true))
	if best.has_method("try_sit"):
		return bool(best.call("try_sit", true))
	if best.has_method("try_open"):
		return bool(best.call("try_open"))
	return false


func _interact_point(node: Node) -> Vector3:
	if node.has_method("approach_point"):
		return node.call("approach_point") as Vector3
	var stand := node.get_node_or_null("StandArea/Collision") as Node3D
	if stand != null:
		return stand.global_position
	var body := node as Node3D
	if body != null:
		return body.global_position
	return global_position


func _try_click(event: InputEvent = null) -> void:
	if _camera_wish() != Vector3.ZERO:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	if event is InputEventMouse:
		mouse = (event as InputEventMouse).position
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
	if collider != null and collider.is_in_group("fish_spot") and collider.has_method("try_fish"):
		if _fishing and _seat_bench == collider:
			return
		if collider.has_method("bench_key") and Net.bench_held_by_other(str(collider.call("bench_key"))):
			return
		if _sitting:
			stand_up()
		if bool(collider.call("try_fish")):
			return
		_pending_bench = collider
		_begin_click(_closest_nav_point(collider.call("approach_point")))
		return
	if collider != null and collider.is_in_group("bench") and collider.has_method("try_sit"):
		if _sitting and _seat_bench == collider:
			return
		if collider.has_method("bench_key") and Net.bench_held_by_other(str(collider.call("bench_key"))):
			return
		if _sitting:
			stand_up()
		if bool(collider.call("try_sit")):
			return
		_pending_bench = collider
		_begin_click(_closest_nav_point(collider.call("approach_point")))
		return
	if _sitting:
		stand_up()
	_pending_bench = null
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
		var bench := _pending_bench
		_pending_bench = null
		_cancel_click()
		if bench != null and bench.has_method("try_fish"):
			bench.call("try_fish", true)
		elif bench != null and bench.has_method("try_sit"):
			bench.call("try_sit", true)
		return Vector3.ZERO
	if agent.is_navigation_finished():
		if not agent.is_target_reachable():
			_pending_bench = null
			_cancel_click()
		return Vector3.ZERO
	var next := agent.get_next_path_position()
	var to_next := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if to_next.length() < 0.05:
		return Vector3.ZERO
	return to_next.normalized()


func _blocks_play() -> bool:
	if _input_locked or _typing_locked:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit


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
	planted.y = _seat_point.y + 0.03 if _sitting else 0.03
	shadow.global_position = planted


func _clear_seat(relocate: bool) -> void:
	if not _sitting:
		return
	_sitting = false
	_end_fishing()
	_seat_bench = null
	_restore_feet()
	if relocate:
		global_position = Vector3(_stand_point.x, 0.2, _stand_point.z)
		velocity = Vector3.ZERO
	if _remote_peer == 0:
		Net.release_bench()


func present_remote(target: Vector3, yaw: float, speed: float, sitting: bool) -> void:
	if not _has_net_pose or global_position.distance_to(target) > 2.0:
		global_position = target
		rotation.y = yaw
	_net_target = target
	_net_yaw = yaw
	_net_speed = speed
	_net_sitting = sitting
	_has_net_pose = true


func apply_identity(player_name: String, color_index: int) -> void:
	if _name_label == null:
		_name_label = Label3D.new()
		_name_label.name = "NameLabel"
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.font_size = 42
		_name_label.outline_size = 8
		_name_label.pixel_size = 0.005
		_name_label.position = Vector3(0.0, 1.4, 0.0)
		_name_label.modulate = Color(0.97, 0.98, 1.0)
		_name_label.outline_modulate = Color(0.08, 0.14, 0.22)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_name_label)
	_name_label.text = player_name
	if _tint_applied == color_index:
		return
	_tint_applied = color_index
	var coat := Net.coat_color(color_index) if _remote_peer != 0 else Outfit.coat(Outfit.load_look())
	if AssetPack.recolor_body(visual, coat):
		return
	_tint(visual.get_node("Body") as MeshInstance3D, coat)
	_tint(visual.get_node("FlipperL") as MeshInstance3D, coat)
	_tint(visual.get_node("FlipperR") as MeshInstance3D, coat)


func _setup_remote() -> void:
	collision_layer = 0
	collision_mask = 0
	agent.debug_enabled = false
	agent.avoidance_enabled = false
	marker.hide_marker()
	_mount_pack(Color(0.24, 0.49, 0.84))
	_pose_placeholder()
	_clips = _find_clips()


func _step_remote(delta: float) -> void:
	if _has_net_pose:
		var blend := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(_net_target, blend)
		rotation.y = lerp_angle(rotation.y, _net_yaw, blend)
	if _sitting and not _net_sitting:
		_restore_feet()
	_sitting = _net_sitting
	if _sitting:
		_seat_point = global_position
	_plant_shadow()
	_animate(delta, 0.0 if _net_sitting else _net_speed)


func _publish_pose() -> void:
	if _remote_peer != 0:
		return
	Net.note_pose(global_position, rotation.y, Vector2(velocity.x, velocity.z).length(), _sitting)


func _tint(mesh: MeshInstance3D, color: Color) -> void:
	if mesh == null:
		return
	var source := mesh.get_surface_override_material(0) as StandardMaterial3D
	if source == null:
		return
	var mat := source.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)


func _restore_feet() -> void:
	visual.rotation = Vector3.ZERO
	visual.position.y = 0.0
	if _foot_l:
		_foot_l.position.y = _foot_l_y
		_foot_l.position.z = _foot_l_z
	if _foot_r:
		_foot_r.position.y = _foot_r_y
		_foot_r.position.z = _foot_r_z


func _animate(delta: float, speed: float) -> void:
	if _fisher_phase != "":
		if _clips and _clips.has_animation("idle") and _clips.current_animation != "idle":
			_clips.play("idle")
		var lean := 12.0
		if _fisher_phase == "cast" or _fisher_phase == "bite":
			lean = 20.0
		elif _fisher_phase.begins_with("catch"):
			lean = 4.0
		visual.rotation.x = deg_to_rad(lean)
		visual.position.y = 0.0
		return
	if _sitting:
		if _clips and _clips.has_animation("sit"):
			if _clips.current_animation != "sit":
				_clips.play("sit")
			visual.rotation = Vector3.ZERO
			visual.position.y = 0.0
			return
		_phase += delta * 1.4
		visual.rotation = Vector3(deg_to_rad(12.0), 0.0, 0.0)
		visual.position.y = -0.08 + sin(_phase) * 0.008
		_plant_feet_forward()
		_swing_flipper(_flipper_l, _flipper_l_x, 0.0)
		_swing_flipper(_flipper_r, _flipper_r_x, 0.0)
		return
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


func _plant_feet_forward() -> void:
	if _foot_l:
		_foot_l.position.y = _foot_l_y + 0.04
		_foot_l.position.z = _foot_l_z - 0.16
	if _foot_r:
		_foot_r.position.y = _foot_r_y + 0.04
		_foot_r.position.z = _foot_r_z - 0.16


func _lift_foot(foot: Node3D, rest_y: float, wave: float) -> void:
	if foot == null:
		return
	foot.position.y = rest_y + maxf(wave, 0.0) * 0.09


func _swing_flipper(flipper: Node3D, rest_x: float, wave: float) -> void:
	if flipper == null:
		return
	flipper.rotation.x = rest_x + wave * 0.55


func _end_fishing() -> void:
	_fishing = false
	_reel_focus = false
	if visual:
		visual.rotation.x = 0.0
	if _fisher_phase != "":
		_fisher_phase = ""
		if _tackle != null and is_instance_valid(_tackle):
			_tackle.set_phase("")
		if _remote_peer == 0:
			Net.note_fisher("")
	if _fish_hud != null and is_instance_valid(_fish_hud):
		_fish_hud.queue_free()
	_fish_hud = null


func _tackle_node() -> Node:
	if _tackle == null or not is_instance_valid(_tackle):
		_tackle = load("res://scripts/fishing_tackle.gd").new()
		add_child(_tackle)
	return _tackle


func _mount_pack(body: Color) -> void:
	if _remote_peer != 0:
		AssetPack.mount_bird(visual, body, "hoodie", "red_beanie", "head")
		return
	# Local look comes from the wardrobe (ui/activities/outfit.gd).
	AssetPack.mount_bird(visual, body)
	Outfit.dress(visual.get_node_or_null("PackAvatar") as Node3D, Outfit.load_look())


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
		_foot_l_z = _foot_l.position.z
	if _foot_r:
		_foot_r_y = _foot_r.position.y
		_foot_r_z = _foot_r.position.z


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
	_add_keys("interact", [KEY_F])
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
