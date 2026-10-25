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
var _fish_music := 0
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
var _overlay := ""  # emote/activity clip playing until the penguin moves
var _sent_anim := ""  # local: the clip last reported to Net.note_anim
var _sent_pos := 0.0
var _net_anim := ""  # puppet: the owner's current clip, played while it lasts
var _net_anim_n := -1
var _dance_beat := -1.0  # >= 0 while standing on the town dance floor (see set_dancing)
var _dance_beat_s := 0.5
var _seat_kit := ""  # "casino": seated clips come from that kit instead of the bench "sit"
var _hopping := false
var _left_ground := false
var _stall := 0.0
var _detour := Vector3.ZERO
var _detour_left := 0.0
var _detours := 0
var _safe_spots: Array[Vector3] = []
var _off_nav := 0.0
var _last_pos := Vector3.ZERO

const _GRAVITY := 28.0
const _JUMP_SPEED := 7.6   # about a metre; the jump clip's tuck sits on top
const _HOP_TUCK := 0.42    # anim_locomotion hop, used when the jump clip is missing
const _HOP_LAND := 0.57
const _JUMP_TUCK := 0.36   # anim_locomotion jump: airborne pose between takeoff and land
const _JUMP_LAND := 0.53
const _CLICK_MASK := 3
const _FLOOR_LAYER := 1


func _ready() -> void:
	_remote_peer = int(get_meta("remote_peer", 0))
	if _remote_peer != 0:
		add_to_group("remote_penguins")  # Voice: proximity gain + speaking icon
		add_to_group("remote_player")  # court, dance floor and snowball arena find puppets by this
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
	PenguinAnims.attach(_clips)
	marker.hide_marker()


func set_travel_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		_clear_seat(false)
		halt()


## Something really is taking keys right now: a focused text field or a screen that blocks the world.
func _typing_now() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return true
	var router := get_node_or_null("/root/UIRouter")
	return router != null and router.has_method("blocks_world") and bool(router.call("blocks_world"))


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
	if _remote_peer == 0:
		if _fish_music != 0:
			Music.resume(_fish_music)
		_fish_music = Music.play_activity("fishing")
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
	_hopping = false
	_left_ground = false
	velocity = Vector3.ZERO


func face_point(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length_squared() < 0.0001:
		return
	rotation.y = atan2(-flat.x, -flat.z)


func _unhandled_input(event: InputEvent) -> void:
	if _remote_peer != 0 or _blocks_play() or _reel_focus:
		return
	if event.is_action_pressed("unstuck"):
		rescue()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if _try_interact():
			get_viewport().set_input_as_handled()
		elif _court_press("pass") or _court_press("steal"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("click_walk"):
		var arena := get_tree().get_first_node_in_group("snow_arena")
		if arena != null and bool(arena.call("try_throw", self, event)):
			get_viewport().set_input_as_handled()
			return
		_try_click(event)


func _physics_process(delta: float) -> void:
	if _remote_peer != 0:
		_step_remote(delta)
		return
	_report_anim()
	_stack_label()
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
		if _detour_left > 0.0 and direction != Vector3.ZERO:
			_detour_left -= delta
			direction = _detour
	if _sitting:
		global_position = _seat_point
		velocity = Vector3.ZERO
		_plant_shadow()
		_animate(delta, 0.0)
		_publish_pose()
		return

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var speed := 3.2 if Net.court_carrying() else walk_speed
	planar = planar.move_toward(direction * speed, acceleration * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	if Input.is_action_just_pressed("jump"):
		_try_jump()
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= _GRAVITY * delta

	var facing := Vector3(velocity.x, 0.0, velocity.z)
	if facing.length() > 0.15:
		_turn_toward(facing, delta)

	var before := global_position
	var intended := Vector3(velocity.x, 0.0, velocity.z)  # move_and_slide zeroes it against the step
	var rising := velocity.y > 1.0
	floor_snap_length = 0.0 if rising else 0.25
	move_and_slide()
	if not rising:
		_step_up(before, intended, delta)
	if _click_active and direction != Vector3.ZERO:
		_watch_stall(before, direction, speed, delta)
	_watch_footing(delta)
	_plant_shadow()
	_animate(delta, facing.length())
	_publish_pose()


## Starts a click-walk to a world point, snapped onto the snow mesh.
func command_walk_to(world_point: Vector3) -> void:
	_begin_click(_closest_nav_point(world_point))


## Uses the nearest bench, fishing spot, or town action whose prompt is showing.
func _try_interact() -> bool:
	if _sitting:
		return false
	var best: Node = null
	var best_dist := INF
	for group in ["bench", "fish_spot", "interactables"]:
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
	if best.has_method("interact"):  # town activity anchors and doors (scripts/world/interactable.gd)
		return bool(best.call("interact", self))
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


## Step onto stairs, tier risers, bridge lips and kerbs up to STEP_HEIGHT: when the slide was
## blocked by a wall, retry the horizontal move from STEP_HEIGHT higher and settle down onto
## the step. (CharacterBody3D only snaps down; without this any vertical edge stops the bird.)
const STEP_HEIGHT := 0.35


func _step_up(before: Vector3, wish: Vector3, delta: float) -> void:
	if not is_on_wall() or wish.length() < 0.1:
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var want := wish.length() * delta
	if moved > want * 0.6:
		return
	var start := Transform3D(global_basis, before)
	var up := Vector3.UP * STEP_HEIGHT
	if test_move(start, up):
		return
	var raised := start.translated(up)
	var ahead := wish * delta
	if test_move(raised, ahead):
		return
	var over := raised.translated(ahead)
	var col := KinematicCollision3D.new()
	if not test_move(over, -up, col):
		return  # nothing to stand on: it's a drop, not a step
	if col.get_normal().y < 0.7:
		return
	global_position = over.origin + col.get_travel()  # settled onto the step
	velocity = Vector3(wish.x, 0.0, wish.z)


## Recovery. Walking on the navmesh leaves a trail of firm spots every SAFE_STEP m. The unstuck
## key (G) jumps back to the newest one not under the penguin; so does sinking below the trail
## or hanging in the air away from the navmesh for OFF_NAV_TIME s (the water, off a ledge).
## Off-navmesh floor at trail height (a dock end the bake missed) is left alone.
const _SAFE_STEP := 0.75
const _SAFE_KEEP := 16
const _OFF_NAV_TIME := 1.5


func rescue() -> void:
	if _sitting:
		_clear_seat(false)
	var to := _closest_nav_point(global_position)
	for i in range(_safe_spots.size() - 1, -1, -1):
		if _safe_spots[i].distance_to(global_position) > 1.5:
			to = _safe_spots[i]
			break
	halt()
	global_position = to + Vector3.UP * 0.05
	_off_nav = 0.0
	_last_pos = global_position


func _watch_footing(delta: float) -> void:
	if global_position.distance_to(_last_pos) > 5.0:  # travel or a marker shift: the trail is another room's
		_safe_spots.clear()
		_off_nav = 0.0
	_last_pos = global_position
	var map := agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var near := NavigationServer3D.map_get_closest_point(map, global_position)
	var off := Vector2(near.x - global_position.x, near.z - global_position.z).length()
	var rise := absf(near.y - global_position.y)
	if off < 0.5 and rise < 0.6 and is_on_floor():
		_off_nav = 0.0
		if _safe_spots.is_empty() or _safe_spots[-1].distance_to(global_position) > _SAFE_STEP:
			_safe_spots.append(global_position)
			if _safe_spots.size() > _SAFE_KEEP:
				_safe_spots.pop_front()
		return
	var lost := off > 1.0 or rise > 1.0
	var sunk := not _safe_spots.is_empty() and global_position.y < _safe_spots[-1].y - 0.8
	if lost and (sunk or not is_on_floor()):
		_off_nav += delta
	else:
		_off_nav = 0.0
	if _off_nav > _OFF_NAV_TIME and not _safe_spots.is_empty():
		rescue()


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
	var seat := SeatSpot.pick(get_tree(), raw, 0.7)  # benches, stools, chairs: walk over, then sit
	if seat != null and not (_sitting and _seat_bench == seat):
		if _sitting:
			stand_up()
		if Vector2(global_position.x - seat.seat_point.x, global_position.z - seat.seat_point.z).length() < 0.8 and seat.try_sit():
			return
		_pending_bench = seat
		_begin_click(_closest_nav_point(seat.seat_point))
		return
	if not _sitting and _court_press("shoot"):
		_cancel_click()
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


## Click-walk pressed against a prop the navmesh squeezes past (sign posts, cottage corners):
## after STALL_TIME s of barely moving, sidestep along the contact for DETOUR_TIME s, the side
## nearest the path first, then the other. Gives up after MAX_DETOURS rather than walk in place.
const _STALL_TIME := 0.4
const _DETOUR_TIME := 0.5
const _MAX_DETOURS := 3


func _watch_stall(before: Vector3, direction: Vector3, speed: float, delta: float) -> void:
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved > speed * delta * 0.25:
		_stall = maxf(0.0, _stall - delta)
		return
	_stall += delta
	if _stall < _STALL_TIME or _detour_left > 0.0:
		return
	_stall = 0.0
	_detours += 1
	if _detours > _MAX_DETOURS:
		_pending_bench = null
		_cancel_click()
		return
	var push := Vector3.ZERO
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		push += Vector3(n.x, 0.0, n.z)
	if push.length_squared() < 0.0001:
		push = -direction
	push = push.normalized()
	var along := push.cross(Vector3.UP).normalized()
	if along.dot(direction) < 0.0:
		along = -along
	if _detours == 2:
		along = -along
	_detour = (along + push * 0.35).normalized()
	_detour_left = _DETOUR_TIME


func _begin_click(point: Vector3) -> void:
	_detours = 0
	_detour_left = 0.0
	_stall = 0.0
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
	var seat := _pending_bench as SeatSpot  # the seat's furniture is solid: arriving beside it is enough
	var at_seat := seat != null and Vector2(global_position.x - seat.seat_point.x, global_position.z - seat.seat_point.z).length() < 1.1
	if offset.length() <= stop_distance or at_seat:
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


func _try_jump() -> void:
	if _sitting or _fishing or _reel_focus or _blocks_play() or not is_on_floor():
		return
	if UIRouter.is_open():
		return
	velocity.y = _JUMP_SPEED
	_hopping = true
	_left_ground = false
	_cancel_emote()
	_overlay = ""
	_play_jump()


func _jump_clip() -> String:
	if _clips != null and _clips.has_animation("jump"):
		return "jump"
	if _clips != null and _clips.has_animation("hop"):
		return "hop"
	return ""


func _jump_tuck() -> float:
	return _JUMP_TUCK if _jump_clip() == "jump" else _HOP_TUCK


func _jump_land() -> float:
	return _JUMP_LAND if _jump_clip() == "jump" else _HOP_LAND


func _play_jump() -> void:
	var clip := _jump_clip()
	if clip == "":
		return
	_clips.speed_scale = 1.0
	_clips.play(clip, 0.06)


## Keeps the jump tucked in the air, then plays the landing once the body is back on the ground.
func _animate_hop() -> bool:
	var clip := _jump_clip()
	if not _hopping or clip == "":
		_hopping = false
		return false
	if _clips.current_animation != clip:
		_play_jump()
	var anim := _clips.get_animation(clip)
	var pos := _clips.current_animation_position
	if not is_on_floor():
		_left_ground = true
		if pos >= _jump_land():
			_clips.seek(_jump_tuck(), true)
			_clips.pause()
		return true
	if not _left_ground:
		if pos >= anim.length - 0.05:
			_hopping = false
			return false
		return true
	if pos >= anim.length - 0.05:
		_hopping = false
		_left_ground = false
		return false
	if pos < _jump_land() or not _clips.is_playing():
		_clips.play(clip)
		_clips.seek(_jump_land(), true)
	return true


func _blocks_play() -> bool:
	if _typing_locked and not _typing_now():
		_typing_locked = false  # self-heal: the lock outlived its text field or screen (no focus_exited)
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
	if _seat_kit != "":
		var leave: String = PenguinAnims.SEATS.get(_seat_kit, ["", "", ""])[2]
		_seat_kit = ""
		if _remote_peer == 0:
			Net.note_act("")
		if leave != "":
			_play_overlay(leave, "")
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
	PenguinAnims.attach(_clips)


## Two penguins side by side (one bench, a queue) would print their names on top of each other:
## each tag rises one row per nearby penguin that ranks before it.
func _stack_label() -> void:
	if _name_label == null:
		return
	var rank := 0
	for group in ["local_player", "remote_player"]:
		for other in get_tree().get_nodes_in_group(group):
			if other != self and other is Node3D and other.get_instance_id() < get_instance_id() and (other as Node3D).visible \
					and Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z).length() < 0.9:
				rank += 1
	_name_label.position.y = 1.4 + 0.22 * rank


func _step_remote(delta: float) -> void:
	_stack_label()
	if _has_net_pose:
		var blend := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(_net_target, blend)
		rotation.y = lerp_angle(rotation.y, _net_yaw, blend)
	if _sitting and not _net_sitting:
		_restore_feet()
	_sitting = _net_sitting
	if not _sitting and _seat_kit != "" and _remote_peer != 0:
		_seat_kit = ""
	if _sitting:
		_seat_point = global_position
	_plant_shadow()
	_animate(delta, 0.0 if _net_sitting else _net_speed)


func _publish_pose() -> void:
	if _remote_peer != 0:
		return
	Net.note_pose(global_position, rotation.y, court_speed(), _sitting)


func _face_near_hoop() -> void:
	var best: Node3D = null
	var best_dist := 9999.0
	for node in get_tree().get_nodes_in_group("town_hoop"):
		var hoop := node as Node3D
		if hoop == null:
			continue
		var flat := Vector2(hoop.global_position.x - global_position.x, hoop.global_position.z - global_position.z)
		if flat.length() < best_dist:
			best_dist = flat.length()
			best = hoop
	if best != null:
		face_point(best.global_position)


func court_speed() -> float:
	if _remote_peer != 0:
		return _net_speed
	return Vector2(velocity.x, velocity.z).length()


func _court_press(action: String) -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("current_location_id"):
		return false
	if not Net.court_here(global_position):
		return false
	if action == "shoot":
		_face_near_hoop()
		Net.court_witness(Net.local_id(), global_position, rotation.y, court_speed())
	if action == "shoot" or action == "pass":
		if not Net.court_carrying():
			return false
	elif action == "steal":
		if Net.court_carrying():
			return false
	else:
		return false
	Net.court_action(action)
	return true


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


## Seated/station clip sets: [enter, loop, leave] from the anim kits (PenguinAnims.SEATS).
## "" keeps the bench "sit". Replicated so other players see it (Net.note_act).
func set_seat_clip(kit: String) -> void:
	_seat_kit = kit
	if _remote_peer == 0:
		Net.note_act(kit)
	_start_seat_clip()


## Local: tell the room which kit clip is playing. Base clips (idle/walk/run/jump) are derived from
## the pose stream and emotes have their own rate-limited event, so neither is reported.
func _report_anim() -> void:
	if _clips == null:
		return
	var cur := String(_clips.current_animation)
	if cur.begins_with("emotes/"):
		return
	var want := cur if cur.contains("/") else ""
	var pos := _clips.current_animation_position if want != "" else 0.0
	var anim := _clips.get_animation(want) if want != "" else null
	var loop := anim != null and anim.loop_mode != Animation.LOOP_NONE
	var restarted := want != "" and want == _sent_anim and not loop and pos < _sent_pos - 0.05
	_sent_pos = pos
	if want == _sent_anim and not restarted:
		return
	_sent_anim = want
	Net.note_anim(want, loop)


## Puppet: play the owner's current clip from where the owner is in it (late joiners included).
func apply_anim(clip: String, loop: bool, age: float, n: int) -> void:
	if _remote_peer == 0 or n <= _net_anim_n:  # an older roster snapshot must not replay a past clip
		return
	_net_anim_n = n
	_net_anim = ""
	if clip == "" or _clips == null or not _clips.has_animation(clip):
		return
	var anim := _clips.get_animation(clip)
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	elif age >= anim.length:
		return  # a one-shot that already finished
	_net_anim = clip
	_overlay = ""
	_clips.speed_scale = 1.0
	_clips.play(clip, 0.12)
	_clips.seek(fposmod(age, anim.length) if loop else age, true)


## Local: moving (or jumping) out of an emote tells the room to stop it on this penguin's puppet
## right away, instead of waiting for the pose stream's speed to cross the threshold.
func _cancel_emote() -> void:
	if _remote_peer == 0 and _overlay.begins_with("emotes/") and _clips != null and _clips.current_animation == _overlay:
		Net.note_emote("")


## Puppet: the owner moved out of its emote.
func stop_emote() -> void:
	if _overlay.begins_with("emotes/"):
		_overlay = ""
		if _clips != null and _clips.has_animation("idle"):
			_clips.play("idle", 0.15)


## Remote puppets: the seat style the owner chose.
func apply_act(kit: String) -> void:
	if _remote_peer == 0 or kit == _seat_kit:
		return
	_seat_kit = kit
	if kit != "":
		_start_seat_clip()


func _start_seat_clip() -> void:
	var clips: Array = PenguinAnims.SEATS.get(_seat_kit, [])
	if _clips == null or clips.is_empty():
		return
	var enter := PenguinAnims.resolve(_clips, clips[0], "")
	var idle := PenguinAnims.resolve(_clips, clips[1], "")
	if idle == "":
		idle = PenguinAnims.resolve(_clips, clips[1] + "_loop", "")  # some kits keep the glTF suffix
	if idle != "":
		_clips.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
	_clips.speed_scale = 1.0
	if enter != "":
		_clips.play(enter, 0.1)
		if idle != "":
			_clips.queue(idle)
	elif idle != "":
		_clips.play(idle, 0.15)


## Plays an emote ("wave", "dance", "emote_cheer"...) from anim_emotes. Moving cancels it.
func play_emote(emote_name: String) -> bool:
	var ok := _play_overlay(emote_name, "emotes")
	if ok and _remote_peer == 0:
		Net.note_emote(emote_name)
	return ok


## Plays any activity clip ("fishing/fish_cast", "snow_throw", "arcade_play"...). Moving cancels it.
func play_activity(clip_name: String) -> bool:
	return _play_overlay(clip_name, "social")


func _play_overlay(clip_name: String, kit: String) -> bool:
	if _clips == null:
		return false
	var clip := PenguinAnims.resolve(_clips, clip_name, kit)
	if clip == "":
		return false
	_overlay = clip
	_clips.speed_scale = 1.0
	_clips.play(clip, 0.15)
	return true


## The town dance floor calls this every frame while this penguin stands on it: `beat` is the
## shared beat counter (same on every client), `beat_s` the seconds per beat. A negative beat
## ends the dance. The clip is kept locked to the beat so everyone moves together.
func set_dancing(beat: float, beat_s: float) -> void:
	_dance_beat = beat
	_dance_beat_s = beat_s


func is_dancing() -> bool:
	return _dance_beat >= 0.0


func _animate_dance() -> bool:
	if _dance_beat < 0.0 or _clips == null or _sitting or _fisher_phase != "":
		return false
	var clip := PenguinAnims.resolve(_clips, "emote_dance", "emotes")
	if clip == "":
		return false
	var anim := _clips.get_animation(clip)
	var bars := 4.0  # the dance clip is four beats long
	var want := fposmod(_dance_beat, bars) / bars * anim.length
	_clips.speed_scale = anim.length / (bars * _dance_beat_s)
	if _clips.current_animation != clip:
		_clips.play(clip, 0.12)
		_clips.seek(want, true)
	else:
		var off := wrapf(_clips.current_animation_position - want, -anim.length * 0.5, anim.length * 0.5)
		if absf(off) > 0.12:
			_clips.seek(want, true)
	visual.rotation = Vector3.ZERO
	return true


func _animate(delta: float, speed: float) -> void:
	if _net_anim != "" and _clips != null:
		if _clips.current_animation == _net_anim:
			visual.rotation = Vector3.ZERO
			return
		_net_anim = ""  # the one-shot ended, or another clip took over
	if _dance_beat >= 0.0 and speed <= 0.25 and _animate_dance():
		_overlay = ""
		return
	if _overlay != "" and _clips and speed <= 0.25 and not _sitting and _clips.current_animation == _overlay:
		return
	if speed > 0.25:
		_cancel_emote()
	_overlay = ""
	if _fisher_phase != "":
		var fish_clip := PenguinAnims.fishing_clip(_fisher_phase)
		if _clips and fish_clip != "" and _clips.has_animation(fish_clip):
			if _clips.current_animation != fish_clip:
				_clips.speed_scale = 1.0
				_clips.play(fish_clip, 0.15)
			visual.rotation = Vector3.ZERO
			return
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
	if _sitting and _seat_kit != "":
		visual.rotation = Vector3.ZERO
		visual.position.y = 0.0
		return  # set_seat_clip queued the seated loop
	if _sitting:
		if _clips and _clips.has_animation("sit"):
			_clips.speed_scale = 1.0
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
	if _animate_hop():
		return
	var moving := speed > 0.25
	if _clips:
		var loco := PenguinAnims.locomotion(speed)
		var clip: String = loco[0] if _clips.has_animation(loco[0]) else ("walk" if moving else "idle")
		_clips.speed_scale = loco[1]
		if _clips.current_animation != clip:
			_clips.play(clip, 0.15)
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
	if _remote_peer == 0 and _fish_music != 0:
		Music.resume(_fish_music)
		_fish_music = 0
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
	_add_keys("jump", [KEY_SPACE])
	_add_keys("unstuck", [KEY_G])
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
