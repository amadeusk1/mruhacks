class_name PetFollower
extends Node3D
## A pet from the pets kit that trails its bird (the parent penguin) through town.
## No collision and no skeleton: the pack models carry movable part_* children that are
## animated here per species. Pets face +Z (Blender -Y), so yaw = atan2(dir.x, dir.z).
##   baby_pengloo  waddles, flaps, belly-slides to catch up. Down follows the owner's coat.
##   leash_fish    flop-hops on a leash from the owner's flipper, lies gasping when idle.
##   snowball_pet  rolls, grows while it rolls and pops back small with a puff of snow.
## display = true keeps it in place and idling (wardrobe preview, the plaza pet pen).

const FOLLOW_OFFSET := Vector3(0.55, 0.0, 0.75)   ## owner-local: right and behind (owner faces -Z)
const STOP := 0.3
const SNAP := 9.0
const LEASH_SEGS := 10

@export var species := "baby_pengloo"
@export var display := false
var coat := Color("#3D7BD9")

var _model: Node3D
var _parts := {}
var _owner3d: Node3D
var _last_owner := Vector3.ZERO
var _speed := 0.0            ## current ground speed, m/s
var _phase := 0.0
var _idle_t := 0.0
var _quirk := ""             ## idle gag playing: "flap", "look", "flop", "wobble"
var _quirk_t := 0.0
var _size := 1.0             ## snowball growth
var _pop_t := 0.0
var _slide := false
var _leash: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
# emotes (see "Emotes" below)
var _emote := ""             ## pet emote playing: "copy" is a mode, "fetch" and "pop" own the pet
var _emote_t := 0.0
var _copy_t := 0.0           ## Copy Me: seconds left of copying the owner's emotes
var _pending: Array = []     ## [[delay, kind, exaggerated], ...] reactions waiting to start
var _react := ""             ## reaction playing: an owner emote kind ("wave", "dance"...)
var _react_t := 0.0
var _react_big := false      ## Copy Me exaggerations (tip-over, faceplant)
var _fetch_phase := ""
var _fetch_goal := Vector3.ZERO
var _fetch_prop: Node3D
var _zzz: Label3D


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf() * TAU
	_model = AssetPack.spawn("pets", species)
	if _model == null:
		return
	add_child(_model)
	for n in _model.find_children("part_*", "Node3D", true, false):
		_parts[String(n.name).substr(5)] = {"node": n, "rest": (n as Node3D).transform}
	set_coat(coat)
	if display:
		return
	_owner3d = get_parent() as Node3D
	top_level = true
	if _owner3d:
		_last_owner = _owner3d.global_position
		global_position = _home()
		rotation.y = _owner3d.global_rotation.y + PI
	if species == "leash_fish":
		_build_leash()


func set_coat(c: Color) -> void:
	coat = c
	if _model and species == "baby_pengloo":
		Tints.apply(_model, {"body": c.lerp(Color(0.86, 0.88, 0.92), 0.35)})  # a softer, downy version of its owner


func _home() -> Vector3:
	return _owner3d.global_transform * FOLLOW_OFFSET


func _process(delta: float) -> void:
	if _model == null:
		return
	if display:
		_speed = 0.0
	else:
		_follow(delta)
	_tick_emotes(delta)
	if _react != "":
		_anim_react(delta)
	elif _emote == "pop":
		_anim_pop(delta)
	else:
		match species:
			"baby_pengloo":
				_anim_baby(delta)
			"leash_fish":
				_anim_fish(delta)
			"snowball_pet":
				_anim_snowball(delta)
	if not _leash.is_empty():
		_update_leash()


func _follow(delta: float) -> void:
	if _owner3d == null or not is_instance_valid(_owner3d):
		queue_free()
		return
	var owner_pos := _owner3d.global_position
	var owner_speed := (owner_pos - _last_owner).length() / maxf(delta, 0.0001)
	_last_owner = owner_pos
	var fetching := _emote == "fetch" and _fetch_phase in ["out", "back"]
	var target := _fetch_goal if fetching else _home()
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var dist := flat.length()
	if dist > SNAP:  # travelled, teleported or respawned: appear beside the bird
		_end_emote()
		global_position = _home()
		_speed = 0.0
		return
	var want := 0.0
	if fetching:
		want = 4.2 if dist > 0.12 else 0.0
	elif _emote == "fetch" or _react != "":
		want = 0.0  # standing still for the emote
	elif dist > STOP:
		want = clampf(maxf(owner_speed, 1.2) * (0.6 + dist * 0.35), 0.0, 7.0)
	_speed = lerpf(_speed, want, 1.0 - exp(-6.0 * delta)) if not fetching else want
	_slide = species == "baby_pengloo" and dist > 2.6
	if _speed > 0.05 and dist > 0.001:
		var step := flat / dist * minf(_speed * delta, dist)
		global_position += step
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-10.0 * delta))
	elif owner_speed < 0.1:
		# settled: turn to look at the bird
		var to_owner := owner_pos - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to_owner.x, to_owner.z), 1.0 - exp(-3.0 * delta))
	global_position.y = lerpf(global_position.y, owner_pos.y, 1.0 - exp(-12.0 * delta))


func _part(n: String) -> Node3D:
	return _parts[n]["node"] if _parts.has(n) else null


func _rest(n: String) -> Transform3D:
	return _parts[n]["rest"] if _parts.has(n) else Transform3D.IDENTITY


## Rotates a part from its rest pose about a Godot-space axis.
func _turn(n: String, axis: Vector3, angle: float) -> void:
	var p := _part(n)
	if p:
		var r := _rest(n)
		p.transform = Transform3D(Basis(axis, angle) * r.basis, r.origin)


## Picks an occasional idle gag once the pet has been still for a moment.
func _tick_idle(delta: float, gags: Array) -> void:
	if _speed > 0.2:
		_idle_t = 0.0
		_quirk = ""
		return
	_idle_t += delta
	if _quirk != "":
		_quirk_t += delta
		return
	if _idle_t > 2.5 and _rng.randf() < delta * 0.35:
		_quirk = gags[_rng.randi() % gags.size()]
		_quirk_t = 0.0


func _end_quirk(after: float) -> bool:
	if _quirk_t >= after:
		_quirk = ""
		_idle_t = 0.0
		return true
	return false


# --------------------------------------------------------------- baby pengloo --
func _anim_baby(delta: float) -> void:
	_tick_idle(delta, ["flap", "look", "hop"])
	var moving := _speed > 0.2
	var m := _model
	if _slide and moving:
		# belly-slide: tip forward onto the tummy, flippers swept back
		_phase += delta * 4.0
		m.rotation = m.rotation.lerp(Vector3(deg_to_rad(75), 0, 0), 1.0 - exp(-10.0 * delta))
		m.position = m.position.lerp(Vector3(0, 0.17, 0), 1.0 - exp(-10.0 * delta))
		_turn("flipper_L", Vector3.FORWARD, deg_to_rad(-20))
		_turn("flipper_R", Vector3.FORWARD, deg_to_rad(20))
		return
	if moving:
		_phase += delta * (8.0 + _speed * 3.0)
		var s := sin(_phase)
		m.rotation = Vector3(deg_to_rad(8), 0, s * 0.2)
		m.scale = Vector3.ONE
		m.position = Vector3(0, absf(cos(_phase)) * 0.035, 0)
		_turn("foot_L", Vector3.RIGHT, maxf(0.0, s) * -0.5)
		_turn("foot_R", Vector3.RIGHT, maxf(0.0, -s) * -0.5)
		var flap := 0.35 + absf(s) * 0.25
		_turn("flipper_L", Vector3.BACK, flap)
		_turn("flipper_R", Vector3.BACK, -flap)
		return
	_phase += delta * 2.0
	var breathe := sin(_phase) * 0.012
	m.rotation = m.rotation.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	m.position = Vector3(0, maxf(0.0, breathe), 0)
	m.scale = Vector3(1.0 - breathe, 1.0 + breathe, 1.0 - breathe)
	_turn("foot_L", Vector3.RIGHT, 0.0)
	_turn("foot_R", Vector3.RIGHT, 0.0)
	var flap := 0.0
	match _quirk:
		"flap":
			flap = absf(sin(_quirk_t * 18.0)) * 0.9
			_end_quirk(1.0)
		"look":
			m.rotation.y = sin(_quirk_t * 2.4) * 0.6
			_end_quirk(2.6)
		"hop":
			var t := clampf(_quirk_t / 0.45, 0.0, 1.0)
			m.position.y = sin(t * PI) * 0.12
			flap = sin(t * PI) * 0.8
			_end_quirk(0.6)
	_turn("flipper_L", Vector3.BACK, flap)
	_turn("flipper_R", Vector3.BACK, -flap)


# ------------------------------------------------------------- fish on a leash --
func _anim_fish(delta: float) -> void:
	_tick_idle(delta, ["flop", "flop", "wag"])
	var m := _model
	if _speed > 0.2:
		# flop-hop: a bouncy arc per hop, nose dipping on landing, tail thrashing
		_phase += delta * (7.0 + _speed * 2.5)
		var hop := absf(sin(_phase))
		m.position = Vector3(0, hop * 0.2, 0)
		m.rotation = Vector3(-cos(_phase) * 0.35 * signf(sin(_phase)), 0, sin(_phase * 0.5) * 0.12)  # nose up rising, down landing
		_turn("tail", Vector3.UP, sin(_phase * 2.0) * 0.6)
		_turn("fin_L", Vector3.BACK, 0.3 + hop * 0.6)
		_turn("fin_R", Vector3.BACK, -0.3 - hop * 0.6)
		return
	_phase += delta * 3.0
	var side := 0.0
	var tail := sin(_phase * 2.0) * 0.25
	match _quirk:
		"flop":  # dramatic gasp on its side, then perks right back up
			var t := _quirk_t
			side = deg_to_rad(80) * clampf(t / 0.25, 0.0, 1.0) * (1.0 - clampf((t - 2.2) / 0.25, 0.0, 1.0))
			tail = sin(t * 9.0) * 0.4 if t < 2.2 else tail
			_end_quirk(2.6)
		"wag":
			tail = sin(_quirk_t * 22.0) * 0.7
			m.position.y = absf(sin(_quirk_t * 11.0)) * 0.05
			_end_quirk(1.2)
		_:
			m.position = m.position.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	m.rotation = m.rotation.lerp(Vector3(0, 0, side), 1.0 - exp(-12.0 * delta))
	_turn("tail", Vector3.UP, tail)
	_turn("fin_L", Vector3.BACK, 0.25 + sin(_phase) * 0.15)
	_turn("fin_R", Vector3.BACK, -0.25 - sin(_phase) * 0.15)


func _build_leash() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#D9473B")
	mat.roughness = 0.85
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.009
	cyl.bottom_radius = 0.009
	cyl.height = 1.0
	cyl.radial_segments = 5
	cyl.rings = 1
	cyl.material = mat
	for i in LEASH_SEGS:
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.top_level = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_leash.append(mi)


func _leash_ends() -> Array:
	var a := _owner3d.global_position + Vector3(0, 0.45, 0)
	var bird := _owner3d.find_child("PackAvatar", true, false)
	var hand := Sockets.find(bird, "hand_R") if bird else null
	if hand:
		a = hand.global_position
	var ring := Sockets.find(_model, "leash")
	var b := ring.global_position if ring else global_position + Vector3(0, 0.35, 0)
	return [a, b]


func _update_leash() -> void:
	if _owner3d == null or not is_instance_valid(_owner3d):
		return
	var ends := _leash_ends()
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var span := a.distance_to(b)
	var sag := clampf(1.6 - span, 0.0, 1.0) * 0.35   # slack when close, taut when pulling
	var pts: Array[Vector3] = []
	for i in LEASH_SEGS + 1:
		var t := float(i) / LEASH_SEGS
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	for i in LEASH_SEGS:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var d := p1 - p0
		var mi := _leash[i]
		var seg_len := d.length()
		if seg_len < 0.0001:
			mi.visible = false
			continue
		mi.visible = true
		var y := d / seg_len
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		mi.global_transform = Transform3D(Basis(x, y * seg_len, z), (p0 + p1) * 0.5)


# ------------------------------------------------------------------- snowball --
func _anim_snowball(delta: float) -> void:
	_tick_idle(delta, ["wobble", "bounce"])
	var m := _model
	var ball := _part("ball")
	var r := 0.19 * _size
	if _pop_t > 0.0:
		_pop_t -= delta
	if _speed > 0.2:
		if ball:
			ball.rotate_object_local(Vector3.RIGHT, _speed * delta / r)
		_size = minf(_size + delta * 0.035 * _speed, 1.75)
		if _size >= 1.75:
			_pop()
		_phase += delta * 9.0
		m.rotation = Vector3(0, 0, sin(_phase) * 0.05)
		m.position = Vector3(0, absf(sin(_phase)) * 0.015, 0)
		_turn("face", Vector3.RIGHT, -0.12)
	else:
		_size = maxf(_size - delta * 0.04, 1.0)   # packs back down slowly while resting
		_phase += delta * 2.0
		var y := 0.0
		var roll := sin(_phase) * 0.04
		match _quirk:
			"wobble":
				roll = sin(_quirk_t * 14.0) * 0.25 * (1.0 - clampf(_quirk_t / 1.2, 0.0, 1.0))
				_end_quirk(1.2)
			"bounce":
				var t := clampf(_quirk_t / 0.8, 0.0, 1.0)
				y = absf(sin(t * TAU)) * 0.14 * (1.0 - t * 0.5)
				_end_quirk(0.85)
		m.rotation = Vector3(0, 0, roll)
		m.position = Vector3(0, y, 0)
		_turn("face", Vector3.RIGHT, 0.0)
	var squash := 1.0 + maxf(_pop_t, 0.0) * 0.6
	m.scale = Vector3(_size * squash, _size / squash, _size * squash)


func _pop(big := false) -> void:
	_size = 1.0
	_pop_t = 0.5 if big else 0.35
	# a burst of faceted snow chunks that arc out, fall and shrink away
	var mesh := SphereMesh.new()
	mesh.radius = 0.05 if big else 0.035
	mesh.height = mesh.radius * 1.6
	mesh.radial_segments = 5
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#EEF4F7")
	mat.roughness = 0.9
	mesh.material = mat
	var origin := global_position + Vector3(0, 0.25 if big else 0.2, 0)
	var reach := 1.1 if big else 0.6
	for i in (18 if big else 10):
		var chunk := MeshInstance3D.new()
		chunk.mesh = mesh
		chunk.top_level = true
		add_child(chunk)
		chunk.global_position = origin
		chunk.scale = Vector3.ONE * _rng.randf_range(0.6, 1.3)
		var a := TAU * float(i) / (18.0 if big else 10.0) + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a)) * reach * _rng.randf_range(0.6, 1.0)
		var up := _rng.randf_range(0.35, 0.8) * (1.4 if big else 1.0)
		var tw := chunk.create_tween().set_parallel()
		tw.tween_property(chunk, "global_position:x", origin.x + out.x, 0.55)
		tw.tween_property(chunk, "global_position:z", origin.z + out.z, 0.55)
		tw.tween_property(chunk, "global_position:y", origin.y + up, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(chunk, "global_position:y", global_position.y + 0.02, 0.33).set_delay(0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(chunk, "scale", Vector3.ZERO, 0.3).set_delay(0.7)
		tw.chain().tween_callback(chunk.queue_free)


# --------------------------------------------------------------------- emotes --
## Pet emotes come from the manifest ("emotes") and play as "pet/<id>" on the owner, who sends
## them through the normal emote channel so every client runs the same thing.
##   copy   Baby Pengloo: for 8 s it repeats each owner emote half a second late, overdone.
##   fetch  Fish: flops off 4 m ahead of the owner, comes back with junk and drops it.
##   pop    Snowball: inflates, shudders and bursts in a big puff, then bounces happily.
## Every pet also mirrors owner emotes with a small reaction (on_owner_emote).

const COPY_TIME := 8.0
const FETCH_JUNK := ["fetch_boot", "fetch_sock", "fetch_can"]
const REACT_DUR := {"wave": 1.2, "cheer": 1.0, "laugh": 1.4, "dance": 2.4, "shy": 1.6, "sleepy": 2.6,
		"surprised": 0.9, "happy_bounce": 1.5}


func play_emote(id: String) -> bool:
	if _model == null or display:
		return false
	match id:
		"copy":
			if species != "baby_pengloo":
				return false
			_copy_t = COPY_TIME
			_pending = [[0.5, "wave", true]]  # the owner waves to start it, and the chick copies that too
			return true
		"fetch":
			if species != "leash_fish" or _emote == "fetch":
				return false
			_end_emote()
			_emote = "fetch"
			_fetch_phase = "wait"
			_emote_t = 0.0
			return true
		"pop":
			if species != "snowball_pet" or _emote == "pop":
				return false
			_end_emote()
			_emote = "pop"
			_emote_t = 0.0
			return true
	return false


## The owner played an emote ("emote_wave", "emotes/emote_dance"...): react to it.
func on_owner_emote(clip: String) -> void:
	var kind := clip.get_file().trim_prefix("emote_")
	if _model == null or not REACT_DUR.has(kind) or _emote != "":
		return
	var big := species == "baby_pengloo" and _copy_t > 0.0
	_pending.append([0.5 if big else 0.25, kind, big])
	if _pending.size() > 3:
		_pending.pop_front()


func _end_emote() -> void:
	if _fetch_prop and is_instance_valid(_fetch_prop):
		_fetch_prop.queue_free()
	_fetch_prop = null
	_emote = ""
	_fetch_phase = ""
	_react = ""
	_pending.clear()
	if _zzz:
		_zzz.visible = false


func _tick_emotes(delta: float) -> void:
	if _copy_t > 0.0:
		_copy_t -= delta
	for p in _pending:
		p[0] -= delta
	if _react == "" and not _pending.is_empty() and float(_pending[0][0]) <= 0.0:
		var p: Array = _pending.pop_front()
		_react = p[1]
		_react_t = 0.0
		_react_big = p[2]
	if _emote == "fetch" and not display:
		_tick_fetch(delta)


# Fetch -------------------------------------------------------------------------
func _tick_fetch(delta: float) -> void:
	_emote_t += delta
	var fwd := -_owner3d.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var gap := Vector2(_fetch_goal.x - global_position.x, _fetch_goal.z - global_position.z).length()
	match _fetch_phase:
		"wait":  # the owner's throw
			if _emote_t > 0.45:
				_fetch_phase = "out"
				_fetch_goal = _owner3d.global_position + fwd * 4.0
				_emote_t = 0.0
		"out":
			if gap < 0.15 or _emote_t > 3.0:
				_fetch_phase = "grab"
				_emote_t = 0.0
				_grab_junk()
		"grab":
			_quirk = "wag"
			if _emote_t > 0.6:
				_fetch_phase = "back"
				_emote_t = 0.0
		"back":
			_fetch_goal = _owner3d.global_position + fwd * 0.75
			if gap < 0.15 or _emote_t > 4.0:
				_fetch_phase = "drop"
				_emote_t = 0.0
				_drop_junk()
				_quirk = "wag"
				_quirk_t = 0.0
		"drop":
			if _emote_t > 1.2:
				_end_emote()


func _grab_junk() -> void:
	# the same pick on every client: emotes start within a frame or two of each other
	var junk: String = FETCH_JUNK[int(Time.get_unix_time_from_system() / 3.0) % FETCH_JUNK.size()]
	_fetch_prop = AssetPack.spawn("pets", junk)
	var mouth := Sockets.find(_model, "mouth")
	if _fetch_prop == null or mouth == null:
		return
	mouth.add_child(_fetch_prop)
	_fetch_prop.position = Vector3(0, -0.02, 0.05)
	_fetch_prop.rotation = Vector3(0, PI * 0.5, deg_to_rad(-70))


func _drop_junk() -> void:
	if _fetch_prop == null or not is_instance_valid(_fetch_prop):
		return
	var room := _owner3d.get_parent()
	var at := _fetch_prop.global_position
	_fetch_prop.get_parent().remove_child(_fetch_prop)
	room.add_child(_fetch_prop)
	_fetch_prop.global_position = Vector3(at.x, _owner3d.global_position.y + 0.045, at.z)
	_fetch_prop.rotation = Vector3(0, rotation.y + 0.6, PI * 0.5)  # lying on its side
	var prop := _fetch_prop
	_fetch_prop = null
	var tw := prop.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(prop, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(prop.queue_free)


# Grow & Pop --------------------------------------------------------------------
func _anim_pop(delta: float) -> void:
	_emote_t += delta
	var t := _emote_t
	var m := _model
	if t < 1.0:
		_size = lerpf(1.0, 1.95, 1.0 - pow(1.0 - t, 3.0))
		m.rotation = Vector3(0, 0, sin(t * 8.0) * 0.04)
		_turn("face", Vector3.RIGHT, -0.15)
	elif t < 1.45:
		_size = 1.95 + sin(t * 50.0) * 0.035  # straining
		m.rotation = Vector3(sin(t * 70.0) * 0.06, 0, sin(t * 60.0) * 0.09)
		_turn("face", Vector3.RIGHT, 0.12)
	else:
		_pop(true)
		_emote = ""
		_quirk = "bounce"
		_quirk_t = 0.0
		_idle_t = 3.0
		return
	m.position = Vector3.ZERO
	m.scale = Vector3.ONE * _size


# Reactions ---------------------------------------------------------------------
## One shared set of moves for every pet, driven from the root plus the species' parts.
## _react_big (Baby Pengloo in Copy Me) overdoes it: the dance ends in a tip-over and
## sleepy is an instant faceplant.
func _anim_react(delta: float) -> void:
	_react_t += delta
	var t := _react_t
	var dur: float = REACT_DUR[_react]
	var fade := clampf(minf(t / 0.15, (dur - t) / 0.25), 0.0, 1.0)
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var scl := Vector3.ONE
	var flap := 0.0  # flippers/fins out, 0..1
	var left_only := false
	var tail := sin(t * 14.0) * 0.4
	match _react:
		"wave":
			flap = 0.6 + 0.4 * sin(t * (30.0 if _react_big else 18.0))
			left_only = species == "baby_pengloo"
			rot.z = sin(t * 6.0) * 0.08
		"cheer", "happy_bounce":
			var hops := 2.0 if _react == "cheer" else 3.0
			var u := sin(fmod(t / dur * hops, 1.0) * PI)
			pos.y = u * (0.18 if _react == "cheer" else 0.1)
			flap = 1.0 if _react == "cheer" else u
			scl = Vector3(1.0 + (1.0 - u) * 0.06, 1.0 - (1.0 - u) * 0.06, 1.0 + (1.0 - u) * 0.06)
		"laugh":
			rot.z = sin(t * 32.0) * 0.14
			pos.y = absf(sin(t * 16.0)) * 0.03
			flap = absf(sin(t * 16.0)) * 0.4
			tail = sin(t * 30.0) * 0.5
		"dance":
			rot.y = t / dur * TAU * (2.0 if _react_big else 1.0)
			rot.z = sin(t * 10.0) * 0.2
			pos.y = absf(sin(t * 10.0)) * 0.05
			flap = absf(sin(t * 10.0))
			if _react_big:  # spins itself dizzy and keels over, then pops back up
				var k := clampf((t - (dur - 0.9)) / 0.2, 0.0, 1.0) * (1.0 - clampf((t - (dur - 0.25)) / 0.2, 0.0, 1.0))
				rot.y = minf(rot.y, TAU * 2.0 * (dur - 0.9) / dur)
				rot.z = lerpf(rot.z, 1.45, k)
				pos.y = lerpf(pos.y, 0.12, k)
		"shy":
			rot.y = 1.3
			scl = Vector3(1.0, 0.92, 1.0)
			flap = -0.3
			tail = sin(t * 4.0) * 0.15
		"sleepy":
			if species == "baby_pengloo":
				rot.x = 1.35 if _react_big else 0.25  # faceplant, or just nodding off
				pos.y = 0.14 if _react_big else 0.0
			elif species == "leash_fish":
				rot.z = PI  # belly up
				pos.y = 0.34
				tail = sin(t * 2.0) * 0.1
			else:
				scl = Vector3(1.1, 0.82, 1.1)
			_show_zzz(t)
		"surprised":
			var u := sin(clampf(t / 0.5, 0.0, 1.0) * PI)
			pos.y = u * 0.22
			flap = 1.0
			scl = Vector3.ONE * (1.0 + u * 0.12)
	var m := _model
	m.position = pos * fade
	m.rotation = Vector3(rot.x * fade, rot.y if _react == "dance" else rot.y * fade, rot.z * fade)
	m.scale = Vector3.ONE.lerp(scl, fade) * (_size if species == "snowball_pet" else 1.0)
	match species:
		"baby_pengloo":
			_turn("flipper_L", Vector3.BACK, flap * 1.3 * fade)
			_turn("flipper_R", Vector3.BACK, -flap * 1.3 * fade * (0.15 if left_only else 1.0))
		"leash_fish":
			_turn("fin_L", Vector3.BACK, (0.25 + flap * 0.8) * fade)
			_turn("fin_R", Vector3.BACK, -(0.25 + flap * 0.8) * fade)
			_turn("tail", Vector3.UP, tail)
		"snowball_pet":
			_turn("face", Vector3.RIGHT, -flap * 0.15 * fade)
	if t >= dur:
		_react = ""
		if _zzz:
			_zzz.visible = false


func _show_zzz(t: float) -> void:
	if _zzz == null:
		_zzz = Label3D.new()
		_zzz.text = "z Z z"
		_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_zzz.font_size = 48
		_zzz.outline_size = 10
		_zzz.pixel_size = 0.004
		_zzz.modulate = Color("#1E3460")
		_zzz.outline_modulate = Color.WHITE
		add_child(_zzz)
	_zzz.visible = true
	_zzz.position = Vector3(0, 0.6 + fmod(t, 1.0) * 0.12, 0)
