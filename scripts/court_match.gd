extends RefCounted

## Host-owned court. One ball. Clients only display the dictionary from view().
## Solo is open shoot-around. 1v1, 3v3 and 5v5 tip off once both sides are full.
## Teams are dealt from arrival order; extras sit and rotate in the next game.

const GRAVITY := 9.8
const BALL_R := 0.12
const PICKUP := 1.25
const STEAL_REACH := 0.85
const STEAL_COOLDOWN := 1.2
const PASS_REACH := 6.0
const ARC_THREE := 4.6
const WIN_SCORE := 11
const WIN_CAP := 15
const MATCH_SECONDS := 240.0
const LOFT_DEFAULT := 0.5
## Players on one side. Solo is 0: nobody is dealt, the paint stays open.
const FORMATS := {"solo": 0, "1v1": 1, "3v3": 3, "5v5": 5}

var force_make := false

var phase := "practice"
var phase_left := 0.0
var coral_score := 0
var teal_score := 0
var possessor := 0
var ball_mode := "loose"
var ball_pos := Vector3(0.0, 0.2, 0.2)
var ball_vel := Vector3.ZERO
var inbound := ""
var inbound_left := 0.0
var clock := MATCH_SECONDS
var overtime := false
var text := "Shoot around"
var teams: Dictionary = {}
var game_index := 0
var solo := false
var ruleset := "solo"

var hoop := Vector3(0.0, 1.67, -3.0)
var hoop_coral := Vector3(0.0, 1.67, -3.0)
var hoop_teal := Vector3(0.0, 1.67, -3.0)
var min_x := -4.35
var max_x := 4.35
var min_z := -3.85
var max_z := 3.85

var _arrival: Array[int] = []
var _bodies: Dictionary = {}
var _time := 0.0
var _steal_ready: Dictionary = {}
var _flight_left := 0.0
var _flight_aim := Vector3.ZERO
var _flight_kind := ""
var _flight_made := false
var _flight_points := 2
var _flight_from := 0
var _flight_catch := 0
var _flight_hoop := Vector3.ZERO
var _ignore_until := 0.0
var _ignore_id := 0


func configure(next_hoop: Vector3, bounds: AABB) -> void:
	configure_ends(next_hoop, next_hoop, bounds)


func configure_ends(coral_at: Vector3, teal_at: Vector3, bounds: AABB) -> void:
	hoop_coral = coral_at
	hoop_teal = teal_at
	hoop = coral_at
	min_x = bounds.position.x
	max_x = bounds.position.x + bounds.size.x
	min_z = bounds.position.z
	max_z = bounds.position.z + bounds.size.z
	if phase == "practice" and ball_mode == "loose":
		ball_pos = _center()


func reset() -> void:
	phase = "practice"
	phase_left = 0.0
	coral_score = 0
	teal_score = 0
	possessor = 0
	ball_mode = "loose"
	ball_pos = _center()
	ball_vel = Vector3.ZERO
	inbound = ""
	inbound_left = 0.0
	clock = MATCH_SECONDS
	overtime = false
	text = "Shoot around"
	teams.clear()
	game_index = 0
	solo = false
	ruleset = "solo"
	_arrival.clear()
	_flight_kind = ""
	_bodies.clear()


## "shoot" or "shoot:<loft>", loft 0 (flattest line to the rim) to 1 (tall lob).
func request(id: int, action: String) -> void:
	var bits := action.split(":")
	if bits[0] == "shoot":
		_shoot(id, clampf(float(bits[1]) if bits.size() > 1 and bits[1].is_valid_float() else LOFT_DEFAULT, 0.0, 1.0))
	elif action == "pass":
		_pass(id)
	elif action == "steal":
		_steal(id)
	elif bits[0] == "mode":
		_choose_format(bits[1] if bits.size() > 1 else "")


func tick(delta: float, present: Array, bodies: Dictionary) -> void:
	_time += delta
	_bodies = bodies
	var ids := _ints(present)
	_sync_arrival(ids)
	_sync_sides(ids)
	if ball_mode == "held" and not ids.has(possessor):
		_drop_loose(ball_pos)
	if solo and ids.size() >= 2:
		solo = false
	if phase == "practice" and ruleset != "solo" and ids.size() >= _needed():
		_open_lobby()
	elif phase == "lobby":
		if ruleset == "solo" or ids.size() < _needed():
			_open_practice()
		else:
			teams = _deal(_arrival, game_index)
			phase_left -= delta
			text = "%s in %d" % [_format_label(), maxi(1, int(ceil(phase_left)))]
			if phase_left <= 0.0:
				teams = _deal(_arrival, game_index)
				_start_live()
	elif phase == "result":
		phase_left -= delta
		if phase_left <= 0.0:
			game_index += 1
			coral_score = 0
			teal_score = 0
			overtime = false
			clock = MATCH_SECONDS
			if ruleset != "solo" and ids.size() >= _needed():
				_open_lobby()
			else:
				_open_practice()
	if phase == "live":
		_tick_live(delta, ids)
	_tick_ball(delta)
	if phase == "live" or phase == "practice":
		_pickup(ids)
		if _flight_kind != "":
			_intercept(ids)
		_check_out()
	if phase == "practice":
		if ruleset != "solo" and ids.size() < _needed():
			text = _wait_text(ids.size()) if ball_mode != "held" else "Click to shoot"
		elif ball_mode == "held":
			text = "Click to shoot"
		elif text == "Click to shoot":
			text = "Shoot around"


func view() -> Dictionary:
	var packed := PackedStringArray()
	for id in teams.keys():
		packed.append("%s:%s" % [int(id), str(teams[id])])
	return {
		"phase": phase,
		"left": phase_left,
		"coral": coral_score,
		"teal": teal_score,
		"poss": possessor,
		"mode": ball_mode,
		"bx": ball_pos.x,
		"by": ball_pos.y,
		"bz": ball_pos.z,
		"inbound": inbound,
		"teams": ",".join(packed),
		"clock": clock,
		"text": text,
		"overtime": overtime,
		"solo": solo,
		"format": ruleset,
		"need": _needed(),
		"here": _arrival.size(),
	}


func _tick_live(delta: float, ids: Array[int]) -> void:
	var coral_n := 0
	var teal_n := 0
	for id in ids:
		var side := str(teams.get(id, ""))
		if side == "coral":
			coral_n += 1
		elif side == "teal":
			teal_n += 1
	if not solo and (coral_n == 0 or teal_n == 0):
		if coral_n == 0 and teal_n == 0:
			_open_practice()
		elif coral_n == 0:
			_finish("Teal")
		else:
			_finish("Coral")
		return
	if inbound_left > 0.0:
		inbound_left -= delta
		if inbound_left <= 0.0:
			inbound = ""
	if not overtime:
		clock -= delta
		if clock <= 0.0:
			clock = 0.0
			if solo:
				_finish_solo_time()
				return
			if coral_score == teal_score:
				overtime = true
				text = "Next basket"
			elif coral_score > teal_score:
				_finish("Coral")
			else:
				_finish("Teal")


func _tick_ball(delta: float) -> void:
	if ball_mode == "held":
		var body: Dictionary = _bodies.get(possessor, {})
		if body.is_empty():
			_drop_loose(ball_pos)
			return
		ball_pos = _carry(Vector3(float(body["x"]), float(body["y"]), float(body["z"])), float(body["yaw"]))
		ball_vel = Vector3.ZERO
		return
	if phase == "lobby" or phase == "result":
		ball_vel = Vector3.ZERO
		if phase == "lobby":
			ball_pos = _center() + Vector3(0.0, 1.1, 0.0)
		else:
			ball_pos = _center()
		return
	ball_vel.y -= GRAVITY * delta
	ball_pos += ball_vel * delta
	if ball_pos.y < BALL_R:
		ball_pos.y = BALL_R
		if ball_vel.y < 0.0:
			ball_vel.y = 0.0
		ball_vel.x *= 0.72
		ball_vel.z *= 0.72
		if ball_mode == "flight" and _flight_kind == "" and ball_vel.length() < 0.35:
			ball_mode = "loose"
	if _flight_kind == "":
		return
	_flight_left -= delta
	if ball_pos.distance_to(_flight_aim) < 0.34 or _flight_left <= 0.0:
		_resolve_flight()


func _pickup(ids: Array[int]) -> void:
	if ball_mode != "loose":
		return
	if ball_pos.y > 1.15:
		return
	var best := 0
	var best_dist := PICKUP
	for id in ids:
		if not _can_touch(id):
			continue
		var body: Dictionary = _bodies.get(id, {})
		if body.is_empty():
			continue
		var dist := _flat(ball_pos, Vector3(float(body["x"]), 0.0, float(body["z"])))
		if dist < best_dist:
			best = id
			best_dist = dist
	if best == 0:
		return
	possessor = best
	ball_mode = "held"
	_flight_kind = ""
	_ignore_id = best
	if text == "Tip":
		text = ""
	if inbound != "" and str(teams.get(best, "")) == inbound:
		inbound = ""
		inbound_left = 0.0


## Flight time for a loft setting. The flattest shot peaks right at the rim (anything quicker
## would still be climbing as it arrives); full loft is a lob about 2.4 times as slow.
static func flight_time(rise: float, loft: float) -> float:
	var flattest := maxf(sqrt(maxf(rise, 0.05) / (0.5 * GRAVITY)), 0.4)
	return flattest * lerpf(1.0, 2.4, clampf(loft, 0.0, 1.0))


## The loft that suits a distance: close shots want a flat-ish arc, long ones a higher one.
static func ideal_loft(dist: float) -> float:
	return clampf(0.25 + dist * 0.09, 0.2, 0.95)


## 1 at the ideal loft, 0 when it is 0.45 or more off.
static func loft_fit(dist: float, loft: float) -> float:
	return 1.0 - clampf(absf(loft - ideal_loft(dist)) / 0.45, 0.0, 1.0)


## What the aim guide colour means. Green (a good arc for the distance) goes in, a defender on
## you only takes it down a little. Yellow is a coin flip. Orange falls back to the distance odds.
const FIT_GOOD := 0.7
const FIT_OK := 0.4


static func shot_chance(dist: float, loft: float, contested: bool) -> float:
	var fit := loft_fit(dist, loft)
	if fit >= FIT_GOOD:
		return 0.85 if contested else 1.0
	if fit >= FIT_OK:
		return 0.4 if contested else 0.55
	return minf(_distance_chance(dist, contested) * 0.6, 0.5)


## Points along the ball's path from `from` to `aim`, the same maths _launch flies.
static func arc_points(from: Vector3, aim: Vector3, loft: float, steps: int) -> PackedVector3Array:
	var duration := flight_time(aim.y - from.y, loft)
	var vel := (aim - from) / duration
	vel.y += 0.5 * GRAVITY * duration
	var out := PackedVector3Array()
	for i in steps + 1:
		var t := duration * float(i) / steps
		out.append(from + vel * t - Vector3(0.0, 0.5 * GRAVITY * t * t, 0.0))
	return out


func _shoot(id: int, loft := LOFT_DEFAULT) -> void:
	if not _holding(id):
		return
	var body: Dictionary = _bodies.get(id, {})
	if body.is_empty():
		return
	var from := _carry(Vector3(float(body["x"]), float(body["y"]), float(body["z"])), float(body["yaw"]))
	var aim_hoop := _attack_hoop(id)
	var dist := Vector2(from.x - aim_hoop.x, from.z - aim_hoop.z).length()
	var contested := _contested(id, Vector3(float(body["x"]), 0.0, float(body["z"])))
	var chance := shot_chance(dist, loft, contested)
	var made := force_make or _roll() < chance
	var aim := aim_hoop
	_flight_hoop = aim_hoop
	if not made:
		aim.x += 0.62 if _roll() > 0.5 else -0.62
		aim.y -= 0.05
	_flight_made = made
	_flight_points = 3 if dist >= ARC_THREE else 2
	_flight_from = id
	_flight_catch = 0
	_launch(id, from, aim, flight_time(aim.y - from.y, loft), "shot")


func _pass(id: int) -> void:
	if not _holding(id):
		return
	var body: Dictionary = _bodies.get(id, {})
	if body.is_empty():
		return
	var from := _carry(Vector3(float(body["x"]), float(body["y"]), float(body["z"])), float(body["yaw"]))
	var forward := _forward(float(body["yaw"]))
	var catch_id := 0
	var catch_at := from + forward * 3.2 + Vector3(0.0, 0.1, 0.0)
	var best := PASS_REACH
	for other in _bodies.keys():
		var oid := int(other)
		if oid == id or not _same_side(id, oid):
			continue
		var at := Vector3(float(_bodies[oid]["x"]), float(_bodies[oid]["y"]), float(_bodies[oid]["z"]))
		var to := at - Vector3(float(body["x"]), 0.0, float(body["z"]))
		to.y = 0.0
		var dist := to.length()
		if dist < 0.3 or dist > PASS_REACH or dist >= best:
			continue
		if forward.dot(to / dist) < 0.45:
			continue
		best = dist
		catch_id = oid
		catch_at = at + Vector3(0.0, 0.48, 0.0)
	_flight_made = false
	_flight_points = 0
	_flight_from = id
	_flight_catch = catch_id
	var duration := 0.42 if catch_id != 0 else 0.38
	_launch(id, from, catch_at, duration, "pass")


func _steal(id: int) -> void:
	if ball_mode != "held" or possessor == id:
		return
	if not _can_touch(id):
		return
	if float(_steal_ready.get(id, 0.0)) > _time:
		return
	var mine: Dictionary = _bodies.get(id, {})
	var theirs: Dictionary = _bodies.get(possessor, {})
	if mine.is_empty() or theirs.is_empty():
		return
	if float(theirs["speed"]) < 0.45:
		return
	var dist := _flat(
		Vector3(float(mine["x"]), 0.0, float(mine["z"])),
		Vector3(float(theirs["x"]), 0.0, float(theirs["z"]))
	)
	if dist > STEAL_REACH:
		return
	if phase == "live" and _same_side(id, possessor):
		return
	_steal_ready[id] = _time + STEAL_COOLDOWN
	possessor = id
	ball_mode = "held"
	_flight_kind = ""


func _launch(id: int, from: Vector3, aim: Vector3, duration: float, kind: String) -> void:
	possessor = 0
	ball_mode = "flight"
	ball_pos = from
	ball_vel = (aim - from) / duration
	ball_vel.y += 0.5 * GRAVITY * duration
	_flight_left = duration + 0.08
	_flight_aim = aim
	_flight_kind = kind
	_ignore_id = id
	_ignore_until = _time + 0.16


func _resolve_flight() -> void:
	var kind := _flight_kind
	var made := _flight_made
	var points := _flight_points
	var shooter := _flight_from
	var catch_id := _flight_catch
	_flight_kind = ""
	if kind == "shot" and made and phase != "result":
		_score(points, shooter)
		return
	if kind == "pass" and catch_id != 0 and _bodies.has(catch_id) and _can_touch(catch_id):
		possessor = catch_id
		ball_mode = "held"
		return
	var splash := Vector3(ball_vel.x * 0.35, 2.1, ball_vel.z * 0.35)
	_drop_loose(ball_pos)
	ball_vel = splash


func _intercept(ids: Array[int]) -> void:
	if _time < _ignore_until:
		return
	var best := 0
	var best_dist := 0.42
	for id in ids:
		if id == _ignore_id or not _can_touch(id):
			continue
		var body: Dictionary = _bodies.get(id, {})
		if body.is_empty():
			continue
		var at := Vector3(float(body["x"]), float(body["y"]) + 0.45, float(body["z"]))
		var dist := ball_pos.distance_to(at)
		if dist < best_dist:
			best = id
			best_dist = dist
	if best == 0:
		return
	_flight_kind = ""
	possessor = best
	ball_mode = "held"


func _check_out() -> void:
	if ball_mode == "held":
		return
	if ball_pos.y > 0.45:
		return
	if _inside(ball_pos):
		return
	if phase != "live":
		_drop_loose(_center())
		return
	var side := str(teams.get(_ignore_id, ""))
	if side != "coral" and side != "teal":
		_drop_loose(_center())
	elif solo:
		_give_inbound(side)
	elif side == "coral":
		_give_inbound("teal")
	else:
		_give_inbound("coral")


func _score(points: int, shooter: int) -> void:
	var side := str(teams.get(shooter, ""))
	if phase == "practice":
		coral_score += points
		text = "+%d" % points
		var drop := _flight_hoop.lerp(_center(), 0.18)
		drop.y = BALL_R
		_drop_loose(drop)
		return
	if phase == "live" and (side == "coral" or side == "teal"):
		if side == "coral":
			coral_score += points
		else:
			teal_score += points
		text = "%s +%d" % ["Coral" if side == "coral" else "Teal", points]
		if _winner() != "":
			_finish(_winner())
			return
		if solo:
			_give_inbound(side)
		else:
			_give_inbound("teal" if side == "coral" else "coral")
		return
	_drop_loose(Vector3(hoop.x, BALL_R, hoop.z + 0.7))


func _winner() -> String:
	if overtime and coral_score != teal_score:
		return "Coral" if coral_score > teal_score else "Teal"
	if coral_score >= WIN_CAP or teal_score >= WIN_CAP:
		if coral_score == teal_score:
			return ""
		return "Coral" if coral_score > teal_score else "Teal"
	if coral_score >= WIN_SCORE or teal_score >= WIN_SCORE:
		if absi(coral_score - teal_score) >= 2:
			return "Coral" if coral_score > teal_score else "Teal"
	return ""


func _finish(side: String) -> void:
	phase = "result"
	phase_left = 6.0
	text = "You win" if solo else "%s wins" % side
	possessor = 0
	ball_mode = "loose"
	ball_vel = Vector3.ZERO
	ball_pos = _center()
	inbound = ""
	_flight_kind = ""


func _give_inbound(side: String) -> void:
	inbound = side
	inbound_left = 2.0
	possessor = 0
	ball_mode = "loose"
	ball_vel = Vector3.ZERO
	var spot := _center()
	spot.y = 0.45
	ball_pos = spot
	_flight_kind = ""
	text = "" if solo else "%s ball" % ("Coral" if side == "coral" else "Teal")


func _drop_loose(at: Vector3) -> void:
	possessor = 0
	ball_mode = "loose"
	ball_pos = at
	ball_pos.y = maxf(ball_pos.y, BALL_R)
	ball_vel = Vector3.ZERO
	_flight_kind = ""


func _open_lobby() -> void:
	phase = "lobby"
	phase_left = 5.0
	coral_score = 0
	teal_score = 0
	overtime = false
	clock = MATCH_SECONDS
	possessor = 0
	ball_mode = "loose"
	ball_vel = Vector3.ZERO
	inbound = ""
	_flight_kind = ""
	solo = false
	teams = _deal(_arrival, game_index)
	text = "%s in 5" % _format_label()


func _begin_solo(id: int) -> void:
	solo = true
	teams = {id: "coral"}
	_start_live()
	text = ""


func _finish_solo_time() -> void:
	phase = "result"
	phase_left = 6.0
	text = "You scored %d" % coral_score
	possessor = 0
	ball_mode = "loose"
	ball_vel = Vector3.ZERO
	ball_pos = _center()
	inbound = ""
	_flight_kind = ""


func _open_practice() -> void:
	phase = "practice"
	phase_left = 0.0
	teams.clear()
	solo = false
	inbound = ""
	overtime = false
	text = "Shoot around"
	possessor = 0
	if ball_mode == "held":
		ball_mode = "loose"


func _start_live() -> void:
	phase = "live"
	phase_left = 0.0
	coral_score = 0
	teal_score = 0
	clock = MATCH_SECONDS
	overtime = false
	inbound = ""
	possessor = 0
	ball_mode = "loose"
	ball_vel = Vector3(0.0, -1.2, 0.0)
	ball_pos = _center() + Vector3(0.0, 1.35, 0.0)
	_flight_kind = ""
	text = "Tip"


func _sync_arrival(ids: Array[int]) -> void:
	var keep: Array[int] = []
	for id in _arrival:
		if ids.has(id):
			keep.append(id)
	for id in ids:
		if not keep.has(id):
			keep.append(id)
	_arrival = keep


func _sync_sides(ids: Array[int]) -> void:
	if phase != "live" and phase != "result":
		return
	var next: Dictionary = {}
	for id in teams.keys():
		var peer := int(id)
		if ids.has(peer):
			next[peer] = teams[id]
	for id in ids:
		if not next.has(id):
			next[id] = "bench"
	teams = next


func _deal(ids: Array[int], game: int) -> Dictionary:
	var per := _per_side()
	var window := per * 2
	if per <= 0 or ids.size() < window:
		return {}
	var count := ids.size()
	var shift := game % count if count > window else 0
	var ordered: Array[int] = []
	for i in count:
		ordered.append(ids[(i + shift) % count])
	var flip := game % 2 == 1
	var dealt := {}
	for i in window:
		var side := "coral" if i < per else "teal"
		if flip:
			side = "teal" if side == "coral" else "coral"
		dealt[ordered[i]] = side
	for i in range(window, ordered.size()):
		dealt[ordered[i]] = "bench"
	return dealt


func _choose_format(name: String) -> void:
	var key := name.to_lower()
	if not FORMATS.has(key) or phase == "live":
		return
	if key == ruleset and phase != "result":
		return
	ruleset = key
	if phase == "result":
		return
	if ruleset != "solo" and _arrival.size() >= _needed():
		_open_lobby()
	elif phase != "practice":
		_open_practice()
	elif ruleset == "solo":
		text = "Click to shoot" if ball_mode == "held" else "Shoot around"
	else:
		text = _wait_text(_arrival.size())


func _per_side() -> int:
	return int(FORMATS.get(ruleset, 0))


func _needed() -> int:
	return _per_side() * 2


func _format_label() -> String:
	return "Solo" if ruleset == "solo" else ruleset


func _wait_text(count: int) -> String:
	return "%s needs %d   (%d here)" % [_format_label(), _needed(), count]


func _can_touch(id: int) -> bool:
	if phase == "practice":
		return true
	if phase != "live":
		return false
	var side := str(teams.get(id, ""))
	if side != "coral" and side != "teal":
		return false
	if inbound != "" and inbound_left > 0.0 and side != inbound:
		return false
	return true


func _holding(id: int) -> bool:
	return ball_mode == "held" and possessor == id and _can_touch(id)


func _same_side(a: int, b: int) -> bool:
	if phase != "live":
		return true
	var left := str(teams.get(a, ""))
	var right := str(teams.get(b, ""))
	return left != "" and left != "bench" and left == right


func _contested(id: int, at: Vector3) -> bool:
	for other in _bodies.keys():
		var oid := int(other)
		if oid == id:
			continue
		if phase == "live" and _same_side(id, oid):
			continue
		var body: Dictionary = _bodies[oid]
		if _flat(at, Vector3(float(body["x"]), 0.0, float(body["z"]))) < 1.1:
			return true
	return false


static func _distance_chance(dist: float, contested: bool) -> float:
	if dist < 2.5:
		return 0.45 if contested else 0.85
	if dist < ARC_THREE:
		return 0.25 if contested else 0.55
	return 0.15 if contested else 0.35


func _carry(pos: Vector3, yaw: float) -> Vector3:
	return pos + _forward(yaw) * 0.34 + Vector3(0.0, 0.48, 0.0)


func _forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _attack_hoop(id: int) -> Vector3:
	var side := str(teams.get(id, ""))
	if phase == "live" and side == "teal":
		return hoop_teal
	if phase == "live" and side == "coral":
		return hoop_coral
	var body: Dictionary = _bodies.get(id, {})
	if body.is_empty():
		return hoop_coral
	var at := Vector3(float(body["x"]), 0.0, float(body["z"]))
	if _flat(at, hoop_teal) < _flat(at, hoop_coral):
		return hoop_teal
	return hoop_coral


func _center() -> Vector3:
	return Vector3((min_x + max_x) * 0.5, BALL_R, (min_z + max_z) * 0.5)


func _inside(at: Vector3) -> bool:
	return at.x >= min_x and at.x <= max_x and at.z >= min_z and at.z <= max_z


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _roll() -> float:
	return randf()


func _ints(present: Array) -> Array[int]:
	var ids: Array[int] = []
	for id in present:
		ids.append(int(id))
	return ids
