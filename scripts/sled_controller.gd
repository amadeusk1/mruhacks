extends CharacterBody3D

## Downhill sled on the SledCourse. Speed builds toward a cruising top speed, A/D steer the
## heading (a gentle assist keeps it pointing down the course), banks are walls that scrub speed,
## boost pads push past top speed, ramps launch, and trees/rocks cause a short spin-out instead of
## ending the run. Other racers (remote copies) are pushed apart on contact. Finish once.
## Remote copies (meta remote_peer) only mirror the network pose.

signal crashed          ## spin-out (hazard)
signal finished
signal checkpoint(index: int)
signal boosted

const TOP := 16.0
const BOOST_TOP := 24.0
const ACCEL := 5.5
const TURN := 1.9          ## rad/s at full steer
const ASSIST := 0.8        ## rad/s toward the course direction when not steering
const MAX_OFF := 1.2       ## rad the heading may differ from the course direction
const GRAVITY := 24.0
const BUMP_R := 1.15

var distance := 0.0      ## metres down the course (SledCourse s) since the start line
var running := false
var course_s := 0.0
var speed := 0.0

var _heading := 0.0
var _ended := false
var _crashed := false     ## spin-out in progress (also mirrored for remotes)
var _stun := 0.0
var _boost := 0.0
var _air := false
var _steer := 0.0
var _next_cp := 0
var _push := Vector3.ZERO
var _bump_cd := 0.0
var _remote := false
var _net_target := Vector3.ZERO
var _net_yaw := 0.0
var _net_steer := 0.0
var _net_crashed := false
var _has_net := false
var _name_label: Label3D
var _tint_applied := -1
var _outfit_sig := ""
var _anim: AnimationPlayer
var _clip := ""
var _spin := 0.0
var _spray: CPUParticles3D
var _hiss: AudioStreamPlayer

@onready var visual: Node3D = $Visual
@onready var probe: Area3D = $HazardProbe


func _ready() -> void:
	_drop("NavigationAgent3D")
	_drop("ClickMarker")
	_mount()
	if int(get_meta("remote_peer", 0)) != 0:
		_remote = true
		_name_label = null
		_tint_applied = -1
		_outfit_sig = ""
		var copied := get_node_or_null("NameLabel")
		if copied:
			copied.free()
		collision_layer = 0
		collision_mask = 0
		probe.monitoring = false
		probe.monitorable = false
		return
	probe.monitoring = true
	probe.area_entered.connect(_on_area)
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(40.0)
	_hiss = Sfx.loop(self, "slide_loop")


func begin() -> void:
	if _ended:
		return
	running = true
	_next_cp = 0
	speed = maxf(speed, 4.0)
	Sfx.play(self, "whoosh", -4.0)


func reset_run(point: Vector3, yaw := INF) -> void:
	_ended = false
	_crashed = false
	running = false
	distance = 0.0
	speed = 0.0
	_stun = 0.0
	_boost = 0.0
	_air = false
	_steer = 0.0
	_next_cp = 0
	_push = Vector3.ZERO
	_spin = 0.0
	velocity = Vector3.ZERO
	global_position = point
	course_s = SledCourse.locate(point).x
	_heading = SledCourse.yaw(course_s) if yaw == INF else yaw
	rotation = Vector3(0, _heading, 0)
	if visual:
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
	_play("sledding/sled_ready")


func present_remote(at: Vector3, yaw: float, steer: float, crashed_now: bool) -> void:
	if not _has_net or global_position.distance_to(at) > 6.0:
		global_position = at
		rotation.y = yaw
	_net_target = at
	_net_yaw = yaw
	_net_steer = steer
	_net_crashed = crashed_now
	_has_net = true


func apply_identity(player_name: String, color_index: int, outfit: Dictionary = {}) -> void:
	if _name_label == null or not is_instance_valid(_name_label):
		_name_label = Label3D.new()
		_name_label.name = "NameLabel"
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.font_size = 42
		_name_label.outline_size = 8
		_name_label.pixel_size = 0.005
		_name_label.position = Vector3(0.0, 1.45, 0.0)
		_name_label.modulate = Color(0.97, 0.98, 1.0)
		_name_label.outline_modulate = Color(0.08, 0.14, 0.22)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.no_depth_test = true
		add_child(_name_label)
	_name_label.text = player_name
	_name_label.visible = _remote  # your own name over your own head is noise
	var look := Outfit.load_look() if not _remote else Outfit.sanitize(outfit)
	if _remote:
		look["color"] = posmod(color_index, maxi(Net.COATS.size(), 1))
	if _tint_applied == int(look["color"]) and _outfit_sig == Outfit.signature(look):
		return
	_tint_applied = int(look["color"])
	_outfit_sig = Outfit.signature(look)
	var bird := visual.get_node_or_null("PackAvatar") as Node3D
	if bird != null:
		Outfit.dress(bird, look)
	else:
		AssetPack.recolor_body(visual, Outfit.coat(look))


func _physics_process(delta: float) -> void:
	if _remote:
		return
	_bump_cd = maxf(0.0, _bump_cd - delta)
	_stun = maxf(0.0, _stun - delta)
	_boost = maxf(0.0, _boost - delta)
	if _crashed and _stun <= 0.0:
		_crashed = false
	var on_floor := is_on_floor()
	if running:
		_steer = 0.0 if _stun > 0.0 else Input.get_axis("move_right", "move_left")
		var top := BOOST_TOP if _boost > 0.0 else TOP
		if _stun > 0.0:
			speed = move_toward(speed, 3.0, 30.0 * delta)
		elif speed < top:
			speed = minf(top, speed + ACCEL * delta * (1.0 if on_floor else 0.3))
		else:
			speed = move_toward(speed, top, 6.0 * delta)
		var course_yaw := SledCourse.yaw(course_s)
		var authority := 0.35 if _air else 1.0
		if absf(_steer) > 0.05:
			_heading += _steer * TURN * authority * delta
		else:
			_heading = rotate_toward(_heading, course_yaw, ASSIST * delta)
		var off := wrapf(_heading - course_yaw, -PI, PI)
		_heading = course_yaw + clampf(off, -MAX_OFF, MAX_OFF)
	else:
		_steer = 0.0
		speed = move_toward(speed, 0.0, (9.0 if _ended else 30.0) * delta)
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var v := fwd * speed + _push
	_push = _push.move_toward(Vector3.ZERO, 14.0 * delta)
	if on_floor and not _air:
		velocity = Vector3(v.x, minf(velocity.y, 0.0) - 2.0, v.z)
	else:
		velocity = Vector3(v.x, velocity.y - GRAVITY * delta, v.z)
	if _air:
		floor_snap_length = 0.0
	move_and_slide()
	if _air and is_on_floor() and velocity.y <= 0.0:
		_air = false
		floor_snap_length = 0.8
		Sfx.play(self, "land", -2.0)
		_burst(18)
	_scrub_walls()
	_bump_racers()
	rotation.y = lerp_angle(rotation.y, _heading, 1.0 - exp(-14.0 * delta))
	course_s = SledCourse.locate(global_position, course_s).x
	if running:
		distance = maxf(distance, course_s - SledCourse.START_S)
		while _next_cp < SledCourse.CHECKPOINTS.size() and course_s >= float(SledCourse.CHECKPOINTS[_next_cp]):
			checkpoint.emit(_next_cp)
			Sfx.play(self, "checkpoint", -3.0)
			_next_cp += 1
		if course_s >= SledCourse.finish_s() and _next_cp >= SledCourse.CHECKPOINTS.size():
			_end_finish()
	if Net.is_online():
		Net.note_sled(global_position, rotation.y, _steer, _crashed)


func _process(delta: float) -> void:
	if _remote and _has_net:
		var blend := 1.0 - exp(-14.0 * delta)
		var was := global_position
		global_position = global_position.lerp(_net_target, blend)
		speed = lerpf(speed, (global_position - was).length() / maxf(delta, 0.001), 0.2)
		rotation.y = lerp_angle(rotation.y, _net_yaw, blend)
		_steer = _net_steer
		_crashed = _net_crashed
	if visual == null:
		return
	# spin-out: one quick turn of the whole rig; leaning follows the steer
	if _crashed:
		_spin = minf(_spin + delta * TAU * 1.6, TAU)
	else:
		_spin = 0.0
	visual.rotation.y = _spin
	var blend := 1.0 - exp(-8.0 * delta)
	visual.rotation.z = lerp(visual.rotation.z, _steer * 0.16, blend)
	var clip := "sledding/sled_ride"
	if _crashed:
		clip = "sledding/sled_brake"
	elif _ended:
		clip = "sledding/sled_finish"
	elif speed < 0.5:
		clip = "sledding/sled_ready"
	elif _steer > 0.35:
		clip = "sledding/sled_lean_left"
	elif _steer < -0.35:
		clip = "sledding/sled_lean_right"
	_play(clip)
	if _spray:
		_spray.emitting = speed > 6.0 and not _air
		_spray.initial_velocity_max = 2.5 + speed * 0.15 + absf(_steer) * 2.0
	if _hiss:
		var want := speed > 1.0 and not _air
		if want and not _hiss.playing:
			_hiss.play()
		elif not want and _hiss.playing:
			_hiss.stop()
		_hiss.volume_db = linear_to_db(clampf(speed / 20.0, 0.05, 1.0)) - 8.0
		_hiss.pitch_scale = 0.8 + speed / 40.0


## Ramp launch, boost or hazard (the probe sees hazards on layer 8, pads/ramps on 16).
func _on_area(area: Area3D) -> void:
	if not running:
		return
	if area.is_in_group("boost"):
		_boost = 1.4
		speed = maxf(speed, BOOST_TOP - 2.0)
		boosted.emit()
		Sfx.play(self, "boost", -2.0)
		_burst(24)
	elif area.is_in_group("ramp"):
		if not _air:
			_air = true
			velocity.y = 6.8
			Sfx.play(self, "jump", -3.0)
	elif _stun <= 0.0:
		_stun = 0.9
		_crashed = true
		var away := global_position - area.global_position
		away.y = 0.0
		_push = away.normalized() * 5.0
		Sfx.play(self, "crash", -2.0)
		_burst(30)
		crashed.emit()


## Banks are walls: hitting one scrubs speed and turns the heading along it.
func _scrub_walls() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.6:
			continue
		var flat := Vector3(n.x, 0.0, n.z).normalized()
		var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
		var into := -fwd.dot(flat)
		if into <= 0.05:
			continue
		speed *= 1.0 - 0.35 * into
		var along := (fwd + flat * into).normalized()
		_heading = atan2(-along.x, -along.z)
		if _bump_cd <= 0.0 and into > 0.3:
			_bump_cd = 0.4
			Sfx.play(self, "bump", -6.0)


## Sled-to-sled contact against the other racers' copies: both sides push themselves apart.
func _bump_racers() -> void:
	for other in get_parent().get_children():
		if other == self or not (other is CharacterBody3D) or int(other.get_meta("remote_peer", 0)) == 0:
			continue
		var d := global_position - (other as Node3D).global_position
		d.y = 0.0
		var dist := d.length()
		if dist < 0.01 or dist > BUMP_R:
			continue
		var n := d / dist
		global_position += n * (BUMP_R - dist) * 0.5
		_push += n * 3.5
		if _bump_cd <= 0.0:
			_bump_cd = 0.35
			Sfx.play(self, "bump", -4.0)


func _end_finish() -> void:
	if _ended:
		return
	_ended = true
	running = false
	Sfx.play(self, "finish", -2.0)
	finished.emit()


## The rigged bird riding the winter/sled prop (avatar origin = sled socket_rider), plus spray.
func _mount() -> void:
	for n in ["Deck", "Nose", "RunnerL", "RunnerR"]:
		_drop(n)
	for stale in [visual.get_node_or_null("PackAvatar"), visual.get_node_or_null("SledProp")]:
		if stale:  # a racer copy duplicated from the local sled: mount its own
			stale.free()
	for c in get_children():
		if c is CPUParticles3D or c is AudioStreamPlayer:
			c.free()
	_anim = AssetPack.mount_bird(visual, Net.coat_color(0))
	if _anim:
		PenguinAnims.attach(_anim)
	var bird := visual.get_node_or_null("PackAvatar") as Node3D
	var sled := AssetPack.spawn("winter", "sled")
	if sled:
		sled.name = "SledProp"
		sled.rotation.y = PI  # kit faces +Z, the run goes -Z
		visual.add_child(sled)
		var sock: Array = AssetRegistry.sockets("winter/sled").get("socket_rider", [0.0, 0.05, 0.215])
		if bird:
			bird.position = Basis(Vector3.UP, PI) * Vector3(float(sock[0]), float(sock[2]), -float(sock[1]))
	_spray = CPUParticles3D.new()
	_spray.amount = 40
	_spray.lifetime = 0.55
	_spray.local_coords = false
	_spray.position = Vector3(0, 0.08, 0.55)
	_spray.direction = Vector3(0, 0.6, 1)
	_spray.spread = 40.0
	_spray.initial_velocity_min = 1.5
	_spray.initial_velocity_max = 4.0
	_spray.gravity = Vector3(0, -6, 0)
	_spray.scale_amount_min = 0.5
	_spray.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.98, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_spray.mesh = mesh
	_spray.emitting = false
	add_child(_spray)
	_play("sledding/sled_ready")


func _burst(n: int) -> void:
	if _spray == null:
		return
	var b := _spray.duplicate() as CPUParticles3D
	b.one_shot = true
	b.amount = n
	b.explosiveness = 0.9
	b.initial_velocity_max = 6.0
	b.spread = 90.0
	b.emitting = true
	get_parent().add_child(b)
	b.global_position = global_position + Vector3.UP * 0.2
	get_tree().create_timer(1.5).timeout.connect(b.queue_free)


func _play(clip: String) -> void:
	if _anim == null or clip == _clip or not _anim.has_animation(clip):
		return
	_clip = clip
	_anim.play(clip, 0.15)


func _drop(node_name: String) -> void:
	var node := get_node_or_null(node_name)
	if node:
		node.free()
