extends SceneTree
## Headless check of court formats: solo shoot-around, 1v1, 3v3 and 5v5.
##   Godot --headless --path . --script res://tools/tests/court_modes_test.gd

const Match := preload("res://scripts/court_match.gd")

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	_solo_stays_open()
	_one_vs_one()
	_waits_for_full_sides()
	_three_and_five()
	_live_ignores_format_change()
	_next_game_rotates()
	print("COURT_MODES %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _fresh():
	var m = Match.new()
	m.configure_ends(Vector3(6.0, 1.67, 0.0), Vector3(-6.0, 1.67, 0.0), AABB(Vector3(-8.0, 0.0, -6.0), Vector3(16.0, 0.2, 12.0)))
	return m


func _bodies(ids: Array) -> Dictionary:
	var bodies := {}
	var i := 0
	for id in ids:
		bodies[int(id)] = {"x": 3.0 + float(i) * 0.6, "y": 0.0, "z": 3.0, "yaw": 0.0, "speed": 0.0}
		i += 1
	return bodies


func _play(m, ids: Array, seconds: float) -> void:
	var bodies := _bodies(ids)
	var steps := int(seconds / 0.05)
	for _i in steps:
		m.tick(0.05, ids, bodies)


func _sides(m) -> Dictionary:
	return m.teams


func _solo_stays_open() -> void:
	var m = _fresh()
	_play(m, [1, 2, 3, 4], 8.0)
	check(m.phase == "practice" and m.ruleset == "solo", "four players stay in solo shoot-around, phase %s" % m.phase)
	check(m.teams.is_empty(), "solo deals nobody")
	m.force_make = true
	var bodies := {1: {"x": m.ball_pos.x, "y": 0.0, "z": m.ball_pos.z, "yaw": 0.0, "speed": 0.0}}
	m.tick(0.05, [1], bodies)
	check(m.ball_mode == "held", "solo still picks the ball up")
	m.request(1, "shoot:0.5")
	for _i in 400:
		m.tick(0.016, [1], bodies)
	check(m.coral_score > 0 and m.phase == "practice", "solo basket counts and does not start a match")


func _one_vs_one() -> void:
	var m = _fresh()
	_play(m, [1], 0.2)
	m.request(1, "mode:1v1")
	_play(m, [1], 2.0)
	check(m.phase == "practice" and m.ruleset == "1v1", "1v1 waits for a second player")
	check(str(m.text).contains("needs 2"), "1v1 says it needs 2, got %s" % m.text)
	_play(m, [1, 2], 0.2)
	check(m.phase == "lobby", "two players open the 1v1 lobby, phase %s" % m.phase)
	_play(m, [1, 2], 5.2)
	check(m.phase == "live", "1v1 tips off")
	check(_sides(m).get(1) == "coral" and _sides(m).get(2) == "teal", "1v1 is one per side: %s" % _sides(m))
	m.request(1, "mode:2v2")
	check(m.ruleset == "1v1", "unknown format is ignored")


func _waits_for_full_sides() -> void:
	var m = _fresh()
	_play(m, [1, 2, 3, 4, 5], 0.2)
	m.request(1, "mode:3v3")
	_play(m, [1, 2, 3, 4, 5], 3.0)
	check(m.phase == "practice", "3v3 does not tip with 5")
	check(str(m.text).contains("needs 6"), "3v3 wait text %s" % m.text)
	m.request(1, "mode:solo")
	_play(m, [1, 2, 3, 4, 5, 6], 6.0)
	check(m.phase == "practice" and m.ruleset == "solo", "back to solo even with 6 on the paint")


func _three_and_five() -> void:
	var m = _fresh()
	var six := [1, 2, 3, 4, 5, 6]
	_play(m, six, 0.2)
	m.request(1, "mode:3v3")
	check(m.phase == "lobby", "6 players open 3v3")
	_play(m, six, 5.2)
	check(m.phase == "live", "3v3 tips off")
	var coral := 0
	var teal := 0
	for id in six:
		var side := str(_sides(m).get(id, ""))
		coral += 1 if side == "coral" else 0
		teal += 1 if side == "teal" else 0
	check(coral == 3 and teal == 3, "3v3 deals 3 and 3, got %s" % _sides(m))

	var five = _fresh()
	var ten := []
	for id in range(1, 12):
		ten.append(id)
	_play(five, ten, 0.2)
	five.request(1, "mode:5v5")
	_play(five, ten, 5.2)
	check(five.phase == "live", "5v5 tips off with 11 present")
	coral = 0
	teal = 0
	var bench := 0
	for id in ten:
		var side := str(five.teams.get(id, ""))
		coral += 1 if side == "coral" else 0
		teal += 1 if side == "teal" else 0
		bench += 1 if side == "bench" else 0
	check(coral == 5 and teal == 5 and bench == 1, "5v5 is 5, 5 and one waiting: %s" % five.teams)


func _live_ignores_format_change() -> void:
	var m = _fresh()
	_play(m, [1, 2], 0.2)
	m.request(1, "mode:1v1")
	_play(m, [1, 2], 5.2)
	check(m.phase == "live", "live before the locked format check")
	m.request(1, "mode:5v5")
	check(m.ruleset == "1v1" and m.phase == "live", "format stays 1v1 during the game")


func _next_game_rotates() -> void:
	var m = _fresh()
	var ids := [1, 2, 3]
	_play(m, ids, 0.2)
	m.request(1, "mode:1v1")
	_play(m, ids, 5.2)
	check(m.phase == "live", "1v1 with a bench player started")
	check(str(m.teams.get(3, "")) == "bench", "third player waits the first game: %s" % m.teams)
	m.coral_score = 2
	m.teal_score = 0
	m.clock = 0.02
	m.tick(0.05, ids, _bodies(ids))
	check(m.phase == "result", "clock ends the game, phase %s text %s" % [m.phase, m.text])
	_play(m, ids, 6.2)
	check(m.phase == "lobby" or m.phase == "live", "next 1v1 queues, phase %s" % m.phase)
	check(str(m.teams.get(1, "")) == "bench", "the first player sits the next game: %s" % m.teams)
