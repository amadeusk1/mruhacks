extends RefCounted

## Host-owned half-court match. One ball. Teams are dealt from arrival order.
## Clients only display the dictionary from view().

const GRAVITY := 9.8
const BALL_R := 0.12
const PICKUP := 0.7
const STEAL_REACH := 0.85
const STEAL_COOLDOWN := 1.2
const PASS_REACH := 6.0
const ARC_THREE := 4.6
const WIN_SCORE := 11
const WIN_CAP := 15
const MATCH_SECONDS := 240.0

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

var hoop := Vector3(0.0, 1.67, -3.0)
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
var _ignore_until := 0.0
var _ignore_id := 0


func configure(next_hoop: Vector3, bounds: AABB) -> void:
	hoop = next_hoop
	min_x = bounds.position.x
	max_x = bounds.position.x + bounds.size.x
	min_z = bounds.position.z
	max_z = bounds.position.z + bounds.size.z


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
	_arrival.clear()
	_flight_kind = ""
	_bodies.clear()


func request(id: int, action: String) -> void:
	if action == "shoot":
		_shoot(id)
	elif action == "pass":
		_pass(id)
	elif action == "steal":
		_steal(id)


func tick(delta: float, present: Array, bodies: Dictionary) -> void:
	_time += delta
	_bodies = bodies
	var ids := _ints(present)
	_sync_arrival(ids)
	_sync_sides(ids)
	if phase == "practice" and ids.size() == 1:
		_begin_solo(ids[0])
	elif phase == "practice" and ids.size() >= 2:
		_open_lobby()
	elif solo and ids.size() >= 2:
		solo = false
		_open_lobby()
	elif phase == "lobby":
		if ids.size() < 2:
			_open_practice()
		else:
			teams = _deal(_arrival, game_index)
			phase_left -= delta
			text = "Teams in %d" % maxi(1, int(ceil(phase_left)))
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
			if ids.size() >= 2:
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


func _shoot(id: int) -> void:
	if not _holding(id):
		return
	var body: Dictionary = _bodies.get(id, {})
	if body.is_empty():
		return
	var from := _carry(Vector3(float(body["x"]), float(body["y"]), float(body["z"])), float(body["yaw"]))
	var dist := Vector2(from.x - hoop.x, from.z - hoop.z).length()
	var contested := _contested(id, Vector3(float(body["x"]), 0.0, float(body["z"])))
	var chance := _chance(dist, contested)
	var made := force_make or _roll() < chance
	var aim := hoop
	if not made:
		aim.x += 0.62 if _roll() > 0.5 else -0.62
		aim.y -= 0.05
	_flight_made = made
	_flight_points = 3 if dist >= ARC_THREE else 2
	_flight_from = id
	_flight_catch = 0
	_launch(id, from, aim, 0.62, "shot")


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
	ball_pos = Vector3(0.0, 0.45, max_z - 0.85)
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
	possessor = 0
	ball_mode = "loose"
	ball_vel = Vector3.ZERO
	inbound = ""
	_flight_kind = ""
	solo = false
	teams = _deal(_arrival, game_index)
	text = "Teams in 5"


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
	var count := ids.size()
	if count <= 1:
		return {}
	var shift := game % count if count > 4 else 0
	var ordered: Array[int] = []
	for i in count:
		ordered.append(ids[(i + shift) % count])
	var playing: Array[int] = []
	for i in mini(4, ordered.size()):
		playing.append(ordered[i])
	var dealt: Dictionary = {}
	if playing.size() == 2:
		dealt[playing[0]] = "coral"
		dealt[playing[1]] = "teal"
	elif playing.size() == 3:
		var solo := game % 3
		for i in 3:
			dealt[playing[i]] = "coral" if i == solo else "teal"
	else:
		var pairs := [
			[[0, 2], [1, 3]],
			[[0, 1], [2, 3]],
			[[0, 3], [1, 2]],
		]
		var pair: Array = pairs[game % 3]
		var coral_idx: Array = pair[0]
		for i in playing.size():
			dealt[playing[i]] = "coral" if coral_idx.has(i) else "teal"
	for i in range(4, ordered.size()):
		dealt[ordered[i]] = "bench"
	return dealt


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


func _chance(dist: float, contested: bool) -> float:
	if dist < 2.5:
		return 0.45 if contested else 0.85
	if dist < ARC_THREE:
		return 0.25 if contested else 0.55
	return 0.15 if contested else 0.35


func _carry(pos: Vector3, yaw: float) -> Vector3:
	return pos + _forward(yaw) * 0.34 + Vector3(0.0, 0.48, 0.0)


func _forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _center() -> Vector3:
	return Vector3(0.0, BALL_R, (min_z + max_z) * 0.5)


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
