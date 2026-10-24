extends SceneTree

## Headless rules check for scripts/snow_match.gd with simulated peers: pad queue and rotation,
## scoring, duplicate hits, friendly fire, cover blocking, respawn and spawn protection, rejected
## throws, disconnect policy and both match ends.
##   Godot --headless --path . -s res://tools/snow_rules_check.gd

const Match := preload("res://scripts/snow_match.gd")

var fails := 0


func _init() -> void:
	_rotation()
	_scoring_and_rules()
	_ends()
	print("SNOW_RULES %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print("SNOW_RULES %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _arena() -> RefCounted:
	var m := Match.new()
	# 12 x 8 field; wall in front of the coral spawn at x=2.5 (z 2.5..5.5), as in §13.4
	m.configure(Rect2(0, 0, 12, 8), 0.0, {"coral": Vector2(5, 9.5), "teal": Vector2(7, 9.5)},
		{"coral": [Vector3(1, 0, 4), Vector3(1, 0, 5)], "teal": [Vector3(11, 0, 4), Vector3(11, 0, 5)]},
		[AABB(Vector3(2.2, 0, 2.5), Vector3(0.6, 0.7, 3.0))])
	return m


func _at(x: float, z: float) -> Dictionary:
	return {"x": x, "y": 0.0, "z": z}


func _run(m: RefCounted, seconds: float, present: Array, bodies: Dictionary) -> void:
	var t := 0.0
	while t < seconds:
		m.tick(0.05, present, bodies)
		t += 0.05


func _rotation() -> void:
	var m := _arena()
	var bodies := {1: _at(5, 9.5), 2: _at(5.2, 9.4), 3: _at(4.8, 9.6), 4: _at(7, 9.5), 5: _at(7.2, 9.4)}
	var present := [1, 2, 3, 4, 5]
	m.tick(0.05, present, bodies)
	_check(m.phase == "countdown", "countdown once both pads hold a player")
	_run(m, 3.2, present, bodies)
	_check(m.phase == "live" and m.teams.size() == 4, "2v2 starts after the countdown")
	_check(m.ready["coral"] == [3], "third coral arrival stays queued")
	_check(not m.teams.has(3), "queued player is not in the match")
	_check(not m.throw(3, Vector2(7, 4), bodies), "queued player's throw is rejected")
	m._finish("")
	_run(m, Match.RESULTS + 0.1, present, bodies)
	_check(m.phase == "countdown" or m.phase == "lobby", "results return to the lobby")
	_check(m.ready["coral"].size() > 0 and m.ready["coral"][0] == 3, "queued player is first in line next match")
	# 1v1 debug size
	var duel := _arena()
	duel.team_size = 1
	duel.tick(0.05, present, bodies)
	_run(duel, 3.2, present, bodies)
	_check(duel.teams.size() == 2, "team_size 1 runs a 1v1")


func _live(m: RefCounted, bodies: Dictionary) -> Array:
	var present := bodies.keys()
	m.team_size = 2
	m.tick(0.05, present, bodies)
	_run(m, 3.2, present, bodies)
	return present


func _scoring_and_rules() -> void:
	var m := _arena()
	# coral 1,2 on the coral pad, teal 3,4 on the teal pad, 9 is a spectator outside the field
	var bodies := {1: _at(5, 9.5), 2: _at(5.1, 9.6), 3: _at(7, 9.5), 4: _at(7.1, 9.6), 9: _at(6, 9.8)}
	var present := _live(m, bodies)
	_check(m.phase == "live", "match live")
	# everyone walks to the field
	bodies[1] = _at(4, 1)
	bodies[2] = _at(4, 7)
	bodies[3] = _at(8, 1)
	bodies[4] = _at(8, 7)
	_check(not m.throw(9, Vector2(8, 1), bodies), "spectator cannot throw")
	_check(m.throw(1, Vector2(8, 1), bodies), "coral 1 throws along the lower lane")
	_check(not m.throw(1, Vector2(8, 1), bodies), "cooldown rejects an instant second throw")
	_run(m, 1.0, present, bodies)
	_check(m.coral_score == 0, "spawn protection shields the first hit")
	_check(bool(m.lives[3]["safe"]), "target still protected (it has not thrown)")
	_check(m.throw(3, Vector2(4, 7), bodies), "teal 3 throws, ending its protection")
	_run(m, 1.0, present, bodies)
	_check(not bool(m.lives[3]["safe"]), "protection is off after throwing")
	_check(m.coral_score == 0 and m.teal_score == 0, "coral 2 still protected")
	_check(m.throw(1, Vector2(8, 1), bodies), "coral 1 throws again")
	_run(m, 1.0, present, bodies)
	_check(m.coral_score == 1, "a hit on an unprotected opponent scores 1")
	var hits := 0
	for e in m.events:
		if e["k"] == "hit":
			hits += 1
	_check(hits == 1, "exactly one hit event for one ball")
	_check(float(m.lives[3]["down"]) > 0.0, "the hit player is down")
	_check(not m.throw(3, Vector2(4, 1), bodies), "a downed player cannot throw")
	var life_before: int = int(m.lives[3]["life"])
	_run(m, Match.RESPAWN + 0.1, present, bodies)
	_check(int(m.lives[3]["life"]) == life_before + 1 and bool(m.lives[3]["safe"]), "respawn: new life with protection")
	_check(m.spawn_point(3) == Vector3(11, 0, 4), "respawn point is the team spawn")
	# friendly fire: coral 2 stands right in front of coral 1's throw, no opponent on the line
	bodies[2] = _at(6, 1)
	bodies[3] = _at(8, 4)
	m.throw(2, Vector2(2, 7), bodies)  # coral 2 throws away to drop its own protection
	_run(m, 1.0, present, bodies)
	var before: int = m.coral_score
	m.throw(1, Vector2(6, 1), bodies)
	_run(m, 1.0, present, bodies)
	_check(m.coral_score == before and float(m.lives[2]["down"]) == 0.0, "friendly fire neither scores nor downs")
	# cover: teal 4 throws at coral 1 crouched behind the coral spawn wall
	bodies[1] = _at(1.6, 4)
	bodies[4] = _at(8, 4)
	var teal_before: int = m.teal_score
	m.throw(1, Vector2(9, 0), bodies)  # coral 1 drops protection, throwing out of the wall's way
	_run(m, 1.0, present, bodies)
	m.throw(4, Vector2(1.6, 4), bodies)
	_run(m, 1.5, present, bodies)
	var blocked := false
	for e in m.events:
		if e["k"] == "pop" and e["why"] == "cover":
			blocked = true
	_check(blocked and m.teal_score == teal_before, "the snow wall blocks the throw")
	# thrower outside the field
	bodies[4] = _at(8, 9.5)
	_check(not m.throw(4, Vector2(4, 4), bodies), "throw from outside the field is rejected")
	bodies[4] = _at(8, 7)
	# disconnect: teal 4 leaves -> 2v1 -> match ends
	present.erase(4)
	_run(m, 0.1, present, bodies)
	_check(m.phase == "result" and str(m.text).begins_with("A player left"), "unbalanced match ends on a disconnect")
	var after: int = m.coral_score
	_check(not m.throw(1, Vector2(8, 4), bodies), "no throws during results")
	_check(m.coral_score == after, "no scoring once results begin")


func _ends() -> void:
	var m := _arena()
	var bodies := {1: _at(5, 9.5), 3: _at(7, 9.5)}
	m.team_size = 1
	var present := bodies.keys()
	m.tick(0.05, present, bodies)
	_run(m, 3.2, present, bodies)
	bodies[1] = _at(4, 1)
	bodies[3] = _at(8, 1)
	var t := 0.0
	while m.phase == "live" and t < 90.0:
		var teal: Dictionary = m.lives[3]
		if bool(teal["safe"]) and float(teal["down"]) == 0.0:
			m.throw(3, Vector2(10, 7), bodies)  # teal keeps dropping its protection
		m.throw(1, Vector2(8, 1), bodies)
		_run(m, 0.25, present, bodies)
		t += 0.25
	_check(m.coral_score == 10 and m.phase == "result" and m.text == "Coral wins", "first to 10 wins")
	_check(m.rows.size() == 2 and int(m.rows[0]["score"]) == 10, "result rows rank the hits")
	var timed := _arena()
	timed.team_size = 1
	timed.duration = 5.0
	var tb := {1: _at(5, 9.5), 3: _at(7, 9.5)}
	timed.tick(0.05, tb.keys(), tb)
	_run(timed, 3.2, tb.keys(), tb)
	tb[1] = _at(4, 1)
	tb[3] = _at(8, 1)
	_run(timed, 5.2, tb.keys(), tb)
	_check(timed.phase == "result" and timed.text == "Draw", "time runs out: a tie is a draw")
