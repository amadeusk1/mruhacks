class_name DanceFloor
extends Node3D

## The plaza dance floor. Stand still on it and your penguin dances; everyone on the floor
## dances on the same beat (the beat is derived from the shared wall clock, so it matches on
## every client with no extra networking), the floor tiles, stage lights, disco ball and
## confetti pulse with it, and the town's synthesised dance track fades in.

const CENTER := Vector3(6.6, 0.0, 0.0)
const RADIUS := 2.3
const STILL_S := 0.35  # stand still this long to start dancing
const BEAT_S := DanceMusic.BEAT_S
const RIG_R := RADIUS + 0.35
const RIG_H := 3.4
const HUES := [Color(0.2, 0.9, 1.0), Color(1.0, 0.3, 0.8), Color(1.0, 0.85, 0.2), Color(0.5, 1.0, 0.4)]

## Tools can pin the clock (unix seconds) to get repeatable frames.
static var clock_override := -1.0

var _floor_mat: ShaderMaterial
var _ball_mat: ShaderMaterial
var _ball: MeshInstance3D
var _rim_mat: StandardMaterial3D
var _heads: Array = []  # [StandardMaterial3D]
var _beams: Array = []  # [pivot Node3D, ShaderMaterial, phase]
var _lights: Array = []  # OmniLight3D
var _confetti: GPUParticles3D
var _player: AudioStreamPlayer
var _music: DanceMusic
var _hint: Label
var _party := 0.0
var _quiet := 99.0  # seconds since anyone last danced
var _still := {}
var _dancing := {}  # instance id -> penguin
var _t := 0.0


static func clock() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()


## Shared beat counter, 0..16 and then around again (16 beats = one 8 s loop of the track).
static func beat() -> float:
	return fposmod(clock(), DanceMusic.LOOP_S) / BEAT_S


func _ready() -> void:
	name = "DanceFloor"
	position = _ground(CENTER) + Vector3(0, 0.02, 0)  # the paving mesh stands ~5 cm above its collision
	_build_floor()
	_build_rig()
	_build_lights()
	_build_confetti()
	_build_audio()
	_build_hud()


func dancer_count() -> int:
	return _dancing.size()


func _exit_tree() -> void:  # leaving the town must not leave penguins stuck mid-dance
	for id in _dancing:
		if is_instance_valid(_dancing[id]):
			(_dancing[id] as Node).call("set_dancing", -1.0, BEAT_S)
	_dancing.clear()


func _process(delta: float) -> void:
	_t += delta
	_scan(delta)
	var n := _dancing.size()
	_party = move_toward(_party, clampf(0.55 + 0.225 * float(n - 1), 0.0, 1.0) if n > 0 else 0.0, delta * 1.2)
	_quiet = 0.0 if n > 0 else _quiet + delta
	_pulse(beat())
	_sound(delta)
	_update_hint(n)


func _ground(p: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 8.0, p.z), Vector3(p.x, -4.0, p.z))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return Vector3(p.x, hit.position.y if hit else p.y, p.z)


# ---------------------------------------------------------------- dancers

func _scan(delta: float) -> void:
	var b := beat()
	var here := {}
	for group in ["local_player", "remote_player"]:
		for node in get_tree().get_nodes_in_group(group):
			var p := node as Node3D
			if p == null or not p.has_method("set_dancing"):
				continue
			var id := p.get_instance_id()
			var off := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
			var reach := RADIUS + (0.25 if _dancing.has(id) else -0.1)
			var calm := float(p.call("court_speed")) <= 0.25 and absf(p.global_position.y - global_position.y) < 1.2
			if off.length() < reach and calm:
				_still[id] = float(_still.get(id, 0.0)) + delta
			else:
				_still[id] = 0.0
			if float(_still[id]) >= STILL_S:
				here[id] = p
				p.call("set_dancing", b, BEAT_S)
	for id in _dancing:
		if not here.has(id) and is_instance_valid(_dancing[id]):
			(_dancing[id] as Node).call("set_dancing", -1.0, BEAT_S)
	_dancing = here
	for id in _still.keys():
		if instance_from_id(id) == null:
			_still.erase(id)


func _local() -> Node3D:
	return get_tree().get_first_node_in_group("local_player") as Node3D


# ---------------------------------------------------------------- lights and floor

func _pulse(b: float) -> void:
	var step_i := int(b)
	var phase := b - float(step_i)
	var flash := 1.0 - phase
	var glow := 0.3 + 0.7 * _party
	_floor_mat.set_shader_parameter("beat", b)
	_floor_mat.set_shader_parameter("party", _party)
	_ball_mat.set_shader_parameter("beat", b)
	_ball_mat.set_shader_parameter("party", _party)
	_ball.rotation.y += get_process_delta_time() * (0.6 + 1.2 * _party)
	_rim_mat.albedo_color = HUES[step_i % 4].lerp(Color.WHITE, flash * 0.35) * (0.5 + 0.9 * glow * (0.6 + 0.4 * flash))
	var spin := _t * (0.7 + 0.8 * _party)
	for i in _beams.size():
		var beam: Array = _beams[i]
		var hue: Color = HUES[(step_i + i) % 4]
		var pivot := beam[0] as Node3D
		var swing := spin + float(beam[2])
		var aim := global_position + Vector3(cos(swing), 0.0, sin(swing)) * (0.9 + 0.7 * sin(_t * 0.9 + float(i)))
		pivot.look_at(aim, Vector3.RIGHT)
		(beam[1] as ShaderMaterial).set_shader_parameter("tint", hue)
		(beam[1] as ShaderMaterial).set_shader_parameter("intensity", (0.1 + 0.55 * glow) * (0.6 + 0.4 * flash))
		(_heads[i] as StandardMaterial3D).albedo_color = hue * (0.6 + 0.9 * glow)
	var night := LivingTown.night(LivingTown.hour())
	for i in _lights.size():
		var light := _lights[i] as OmniLight3D
		var hue: Color = HUES[(step_i + i * 2) % 4]
		light.light_color = hue
		light.light_energy = (0.25 + 1.9 * _party * (0.55 + 0.45 * flash)) * (0.55 + 0.45 * night)
	_confetti.emitting = _party > 0.5


func _sound(delta: float) -> void:
	if _music != null and not _music.done():
		if _music.step(3000):
			_player.stream = _music.stream()
	var me := _local()
	var near := 0.0
	if me != null:
		var d := Vector2(me.global_position.x - global_position.x, me.global_position.z - global_position.z).length()
		near = clampf(1.0 - (d - 4.0) / 26.0, 0.0, 1.0)
	var want := near * near * clampf(1.0 - (_quiet - 1.0) / 3.0, 0.0, 1.0)  # lingers a moment after the last dancer
	var target_db := -80.0 if want <= 0.001 else linear_to_db(want) - 5.0
	_player.volume_db = move_toward(_player.volume_db, target_db, delta * 60.0)
	if _player.stream == null:
		return
	if _player.volume_db > -60.0:
		var at := fposmod(clock() + AudioServer.get_output_latency(), DanceMusic.LOOP_S)
		if not _player.playing:
			_player.play(at)
		elif absf(wrapf(_player.get_playback_position() - at, -DanceMusic.LOOP_S * 0.5, DanceMusic.LOOP_S * 0.5)) > 0.2:
			_player.seek(at)
	elif _player.playing:
		_player.stop()


func _update_hint(n: int) -> void:
	var me := _local()
	var close := false
	if me != null:
		close = Vector2(me.global_position.x - global_position.x, me.global_position.z - global_position.z).length() < RADIUS + 5.0
	_hint.get_parent().visible = close
	if n == 0:
		_hint.text = "Dance floor: step on and stand still to dance"
	elif n == 1:
		_hint.text = "Dancing! Friends who join the floor dance in sync with you"
	else:
		_hint.text = "%d penguins dancing in sync" % n


# ---------------------------------------------------------------- building

func _build_floor() -> void:
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS + 0.2
	disc.bottom_radius = RADIUS + 0.22
	disc.height = 0.036
	disc.radial_segments = 48
	disc.rings = 1
	base.mesh = disc
	base.position.y = 0.018
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.1, 0.12, 0.2)
	rock.roughness = 0.6
	base.material_override = rock
	add_child(base)

	var tiles := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = RADIUS
	top.bottom_radius = RADIUS
	top.height = 0.02
	top.radial_segments = 48
	top.rings = 1
	tiles.mesh = top
	tiles.position.y = 0.03
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = load("res://scripts/world/dance_floor.gdshader")
	tiles.material_override = _floor_mat
	tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tiles)

	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS - 0.02
	ring.outer_radius = RADIUS + 0.1
	ring.rings = 48
	ring.ring_segments = 8
	rim.mesh = ring
	rim.position.y = 0.05
	rim.scale = Vector3(1, 0.45, 1)
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = _rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)


func _build_rig() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.17, 0.22)
	steel.metallic = 0.5
	steel.roughness = 0.45
	var beam_shader := load("res://scripts/world/spot_beam.gdshader") as Shader
	var cone_len := Vector2(RIG_R, RIG_H).length() + 0.4
	for i in 4:
		var a := PI * 0.25 + float(i) * PI * 0.5
		var spot := Vector3(cos(a) * RIG_R, 0.0, sin(a) * RIG_R)
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.08
		cyl.height = RIG_H
		cyl.radial_segments = 10
		pole.mesh = cyl
		pole.material_override = steel
		pole.position = spot + Vector3(0, RIG_H * 0.5, 0)
		add_child(pole)
		var head := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.14
		bulb.height = 0.28
		bulb.radial_segments = 12
		bulb.rings = 6
		head.mesh = bulb
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		head.material_override = hm
		_heads.append(hm)
		var pivot := Node3D.new()
		pivot.position = spot + Vector3(0, RIG_H, 0)
		add_child(pivot)
		pivot.add_child(head)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 0.04
		cm.height = cone_len
		cm.radial_segments = 20
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		cone.mesh = cm
		cone.rotation.x = -PI * 0.5
		cone.position.z = -cone_len * 0.5
		var bm := ShaderMaterial.new()
		bm.shader = beam_shader
		cone.material_override = bm
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(cone)
		_beams.append([pivot, bm, float(i) * PI * 0.5])

	var truss := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RIG_R - 0.04
	tm.outer_radius = RIG_R + 0.04
	tm.rings = 48
	tm.ring_segments = 6
	truss.mesh = tm
	truss.position.y = RIG_H
	truss.material_override = steel
	add_child(truss)
	var cross := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(RIG_R * 2.0, 0.07, 0.07)
	cross.mesh = bx
	cross.position.y = RIG_H
	cross.material_override = steel
	add_child(cross)

	var cable := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.012
	cc.bottom_radius = 0.012
	cc.height = 0.45
	cc.radial_segments = 6
	cable.mesh = cc
	cable.position.y = RIG_H - 0.225
	cable.material_override = steel
	add_child(cable)
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	sphere.radial_segments = 24
	sphere.rings = 12
	_ball.mesh = sphere
	_ball.position.y = RIG_H - 0.45 - 0.36
	_ball_mat = ShaderMaterial.new()
	_ball_mat.shader = load("res://scripts/world/disco_ball.gdshader")
	_ball.material_override = _ball_mat
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)


func _build_lights() -> void:
	for i in 3:
		var a := float(i) * TAU / 3.0 + 0.5
		var l := OmniLight3D.new()
		l.position = Vector3(cos(a) * 1.1, 1.7, sin(a) * 1.1)
		l.omni_range = 5.5
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)


func _build_confetti() -> void:
	_confetti = GPUParticles3D.new()
	_confetti.name = "Confetti"
	_confetti.amount = 70
	_confetti.lifetime = 3.2
	_confetti.preprocess = 3.0
	_confetti.emitting = false
	_confetti.position.y = RIG_H - 0.2
	_confetti.visibility_aabb = AABB(Vector3(-4, -5, -4), Vector3(8, 6, 8))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	quad.material = qm
	_confetti.draw_pass_1 = quad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(RADIUS * 0.8, 0.1, RADIUS * 0.8)
	pm.direction = Vector3.DOWN
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, -1.1, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -240.0
	pm.angular_velocity_max = 240.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	ramp.colors = PackedColorArray([HUES[0], HUES[1], HUES[2], HUES[3]])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_initial_ramp = ramp_tex
	_confetti.process_material = pm
	add_child(_confetti)


func _build_audio() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "DanceMusic"
	_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_player.volume_db = -80.0
	add_child(_player)
	_music = DanceMusic.new()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DanceHud"
	layer.layer = 2
	add_child(layer)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.offset_top = -150.0
	box.offset_bottom = -112.0
	box.visible = false
	layer.add_child(box)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.24))
	_hint.add_theme_constant_override("outline_size", 6)
	var font := load("res://fonts/Fredoka-Bold.ttf") as Font
	if font != null:
		_hint.add_theme_font_override("font", font)
	box.add_child(_hint)
