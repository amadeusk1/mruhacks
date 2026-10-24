extends RefCounted

## Snowball fight rules (GAME_DESIGN_CONTEXT §13), run on the host only. Pure state: net.gd feeds it
## who stands in the arena and their throw requests and publishes view(); clients only draw it.
## tools/snow_rules_check.gd drives it with simulated peers.

const TEAMS := ["coral", "teal"]
const COOLDOWN := 0.8
const RESPAWN := 3.0
const COUNTDOWN := 3.0
const RESULTS := 6.0
const SPEED := 13.0  # horizontal m/s; every throw is the same arc, aimed at the cursor's ground point
const GRAVITY := 9.0
const RANGE := 11.0
const RELEASE_Y := 0.9  # above the thrower's feet
const BODY_R := 0.45
const BODY_H := 1.1
const PAD_R := 1.0
const FLIGHT := 2.0  # a ball still airborne after this long is dropped
const STEP := 0.02

var team_size := 2
var win_score := 10
var duration := 120.0

var field := Rect2()  # x/z of the playing area
var floor_y := 0.0
var pads := {}  # team -> Vector2 ready-pad centre (x/z)
var spawns := {}  # team -> Array[Vector3]
var cover: Array = []  # world AABBs that stop snowballs (the visible walls and banks)

var phase := "lobby"  # lobby -> countdown -> live -> result -> lobby
var clock := 0.0
var coral_score := 0
var teal_score := 0
var teams := {}  # id -> "coral" | "teal" while a match runs
var lives := {}  # id -> {cool, down, safe, life, slot, hits}
var ready := {"coral": [], "teal": []}  # pad queues in arrival order, match players excluded
var balls: Array = []  # {ball, by, team, p: Vector3, v: Vector3, age}
var events: Array = []  # newest last; each has a unique "n" so a client applies it once
var text := ""
var rows: Array = []
var _n := 0
var _ball_n := 0


func configure(area: Rect2, ground_y: float, pad_at: Dictionary, spawn_at: Dictionary, blocks: Array) -> void:
	field = area
	floor_y = ground_y
	pads = pad_at
	spawns = spawn_at
	cover = blocks


func reset() -> void:
	_to_lobby()
	ready = {"coral": [], "teal": []}
	events.clear()


func tick(delta: float, present: Array, bodies: Dictionary) -> void:
	if phase == "result":
		_track_pads(present, bodies)
		clock -= delta
		if clock <= 0.0:
			_to_lobby()
		return
	if phase == "live":
		_tick_live(delta, present, bodies)
		return
	_track_pads(present, bodies)
	var n := mini(team_size, mini(ready["coral"].size(), ready["teal"].size()))
	if n == 0:
		phase = "lobby"
		clock = 0.0
		text = "Stand on a team pad to play"
		return
	if phase == "lobby":
		phase = "countdown"
		clock = COUNTDOWN
	clock -= delta
	text = "Starting in %d" % maxi(1, ceili(clock))
	if clock <= 0.0:
		_start(n)


## A throw request from `id` toward the ground point `target` (x/z). The origin is the host's own
## record of the thrower, never the client's word. Returns whether a ball flew.
func throw(id: int, target: Vector2, bodies: Dictionary) -> bool:
	if phase != "live" or not teams.has(id) or not bodies.has(id):
		return false
	var life: Dictionary = lives[id]
	if float(life["down"]) > 0.0 or float(life["cool"]) > 0.0:
		return false
	var body: Dictionary = bodies[id]
	var from := Vector2(float(body["x"]), float(body["z"]))
	if not field.grow(0.3).has_point(from):
		return false
	var aim := target - from
	if aim.length() < 0.2:
		return false
	var dist := clampf(aim.length(), 1.5, RANGE)
	var dir := aim.normalized()
	var t := dist / SPEED
	var vy := (GRAVITY * t * t * 0.5 - RELEASE_Y) / t  # lands on the aimed ground point
	life["cool"] = COOLDOWN
	life["safe"] = false  # spawn protection ends on throwing
	_ball_n += 1
	var ball := {
		"ball": _ball_n,
		"by": id,
		"team": teams[id],
		"p": Vector3(from.x + dir.x * 0.35, float(body["y"]) + RELEASE_Y, from.y + dir.y * 0.35),
		"v": Vector3(dir.x * SPEED, vy, dir.y * SPEED),
		"age": 0.0,
	}
	balls.append(ball)
	_event({"k": "throw", "ball": _ball_n, "by": id, "team": teams[id], "p": ball["p"], "v": ball["v"]})
	return true


## Where a ball thrown with launch point p and velocity v is after t seconds (clients draw this).
static func arc(p: Vector3, v: Vector3, t: float) -> Vector3:
	return p + v * t + Vector3(0.0, -0.5 * GRAVITY * t * t, 0.0)


func spawn_point(id: int) -> Vector3:
	if not lives.has(id) or not teams.has(id):
		return Vector3.ZERO
	var list: Array = spawns.get(teams[id], [])
	if list.is_empty():
		return Vector3.ZERO
	return list[int(lives[id]["slot"]) % list.size()]


func view() -> Dictionary:
	var packed := {}
	for id in lives:
		var life: Dictionary = lives[id]
		packed[id] = [snappedf(float(life["cool"]), 0.01), snappedf(float(life["down"]), 0.01), bool(life["safe"]),
			int(life["life"]), int(life["hits"]), int(life["slot"])]  # cool, down, safe, life, hits, slot
	return {
		"phase": phase,
		"clock": snappedf(clock, 0.01),
		"coral": coral_score,
		"teal": teal_score,
		"teams": teams.duplicate(),
		"lives": packed,
		"ready": {"coral": ready["coral"].duplicate(), "teal": ready["teal"].duplicate()},
		"events": events.duplicate(true),
		"text": text,
		"rows": rows.duplicate(true),
		"win": win_score,
		"size": team_size,
	}


func _tick_live(delta: float, present: Array, bodies: Dictionary) -> void:
	_track_pads(present, bodies)
	for id in teams.keys():
		if not present.has(id) or not bodies.has(id):
			_drop(int(id))
	if phase != "live":
		return
	clock -= delta
	for id in lives:
		var life: Dictionary = lives[id]
		life["cool"] = maxf(0.0, float(life["cool"]) - delta)
		if float(life["down"]) > 0.0:
			life["down"] = float(life["down"]) - delta
			if float(life["down"]) <= 0.0:
				life["down"] = 0.0
				life["life"] = int(life["life"]) + 1  # clients warp to their spawn once per life
				life["safe"] = true
				_event({"k": "respawn", "who": id})
	var steps := maxi(1, ceili(delta / STEP))
	for s in steps:
		for ball in balls.duplicate():
			if _step_ball(ball, delta / steps, bodies):
				balls.erase(ball)
	if coral_score >= win_score or teal_score >= win_score or clock <= 0.0:
		_finish("")


func _step_ball(ball: Dictionary, h: float, bodies: Dictionary) -> bool:
	var v: Vector3 = ball["v"]
	v.y -= GRAVITY * h
	ball["v"] = v
	var at: Vector3 = ball["p"] + v * h
	ball["p"] = at
	ball["age"] = float(ball["age"]) + h
	for box in cover:
		if (box as AABB).has_point(at):
			_event({"k": "pop", "ball": ball["ball"], "at": at, "why": "cover"})
			return true
	for id in teams:
		if teams[id] == ball["team"] or not bodies.has(id):
			continue  # no friendly fire: teammates are not in the way
		var life: Dictionary = lives[id]
		if float(life["down"]) > 0.0:
			continue
		var body: Dictionary = bodies[id]
		var feet := Vector3(float(body["x"]), float(body["y"]), float(body["z"]))
		if Vector2(at.x - feet.x, at.z - feet.z).length() > BODY_R or at.y < feet.y - 0.1 or at.y > feet.y + BODY_H:
			continue
		if bool(life["safe"]):
			_event({"k": "pop", "ball": ball["ball"], "at": at, "why": "shield"})
			return true
		_hit(ball, int(id), at)
		return true
	if at.y < floor_y - 0.1 or float(ball["age"]) > FLIGHT or not field.grow(1.0).has_point(Vector2(at.x, at.z)):
		_event({"k": "pop", "ball": ball["ball"], "at": at, "why": "miss"})
		return true
	return false


func _hit(ball: Dictionary, id: int, at: Vector3) -> void:
	lives[id]["down"] = RESPAWN
	var by := int(ball["by"])
	if lives.has(by):
		lives[by]["hits"] = int(lives[by]["hits"]) + 1
	if ball["team"] == "coral":
		coral_score += 1
	else:
		teal_score += 1
	_event({"k": "hit", "ball": ball["ball"], "who": id, "by": by, "at": at})


func _track_pads(present: Array, bodies: Dictionary) -> void:
	for team in TEAMS:
		var keep: Array = []
		for id in ready[team]:
			if _on_pad(id, team, present, bodies):
				keep.append(id)
		for id in present:
			if not keep.has(id) and _on_pad(id, team, present, bodies):
				keep.append(id)
		ready[team] = keep


func _on_pad(id: int, team: String, present: Array, bodies: Dictionary) -> bool:
	if teams.has(id) or not present.has(id) or not bodies.has(id) or not pads.has(team):
		return false
	var body: Dictionary = bodies[id]
	return Vector2(float(body["x"]), float(body["z"])).distance_to(pads[team]) <= PAD_R


func _start(n: int) -> void:
	teams.clear()
	lives.clear()
	balls.clear()
	rows.clear()
	for team in TEAMS:
		for i in n:
			var id: int = ready[team][i]
			teams[id] = team
			lives[id] = {"cool": 0.0, "down": 0.0, "safe": true, "life": 1, "slot": i, "hits": 0}
		ready[team] = ready[team].slice(n)  # late arrivals stay queued for the next match
	coral_score = 0
	teal_score = 0
	phase = "live"
	clock = duration
	text = "First to %d" % win_score
	_event({"k": "start"})


## The player walked away from the pads or quit the match from the HUD.
func leave(id: int) -> void:
	for team in TEAMS:
		ready[team].erase(id)
	if phase == "live":
		_drop(id)


## A player left mid-match. Policy (§13.6): an unbalanced match ends at once with the score so far.
func _drop(id: int) -> void:
	if not teams.has(id):
		return
	teams.erase(id)
	lives.erase(id)
	var counts := {"coral": 0, "teal": 0}
	for other in teams:
		counts[teams[other]] += 1
	if counts["coral"] != counts["teal"]:
		_finish("A player left")


func _finish(note: String) -> void:
	phase = "result"
	clock = RESULTS
	balls.clear()  # nothing scores once results begin
	rows.clear()
	var ids := lives.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(lives[a]["hits"]) > int(lives[b]["hits"]))
	for id in ids:
		rows.append({"id": id, "score": int(lives[id]["hits"]), "team": teams[id]})
	if coral_score == teal_score:
		text = "Draw"
	else:
		text = "Coral wins" if coral_score > teal_score else "Teal wins"
	if note != "":
		text = "%s. %s" % [note, text]
	_event({"k": "end"})


func _to_lobby() -> void:
	phase = "lobby"
	clock = 0.0
	teams.clear()
	lives.clear()
	balls.clear()
	rows.clear()
	coral_score = 0
	teal_score = 0
	text = "Stand on a team pad to play"


func _event(e: Dictionary) -> void:
	_n += 1
	e["n"] = _n
	events.append(e)
	if events.size() > 24:
		events.pop_front()
