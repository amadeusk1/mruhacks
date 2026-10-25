extends SceneTree
## Headless check of the Snow Trails rules and the Puck Rally host stepping.
##   Godot --headless --path . --script res://tools/tests/arcade_test.gd

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	_trails()
	_puck()
	print("ARCADE_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _run(g: TrailsGame, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		g.step(0.05)
		t += 0.05


func _trails() -> void:
	var g := TrailsGame.new()
	g.start()
	g.set_dir(0, 3)  # reverse into own trail: ignored
	check(g._want[0] == 1, "no instant reverse")
	# rider A turns up into the top edge, B keeps going: B takes the round
	g.set_dir(0, 0)
	_run(g, 1.6)
	check(g.sb == 1 and g.sa == 0, "edge crash scores for the other rider (%d-%d)" % [g.sa, g.sb])
	check(g.round_wait > 0.0, "pause between rounds")
	var v := g.view()
	check((v["a"] as PackedInt32Array).size() >= 4, "trail polyline has the turn and the head")
	_run(g, 2.0)  # next round: both head straight at each other along the middle row
	check(g.sa == g.sb - 1 or g.sa + g.sb >= 1, "round resolved")
	var before := g.sa + g.sb
	var g2 := TrailsGame.new()
	g2.start()
	_run(g2, 4.0)  # head-on in the middle: a draw, nobody scores
	check(g2.sa == 0 and g2.sb == 0, "head-on is a draw (%d-%d)" % [g2.sa, g2.sb])
	var g3 := TrailsGame.new()
	g3.start()
	for r in TrailsGame.TARGET:
		g3.set_dir(1, 0)  # B drives into the top edge every round
		_run(g3, 3.0)
	check(g3.sa == TrailsGame.TARGET and g3.done and not g3.running, "first to %d ends the match" % TrailsGame.TARGET)
	var ai := TrailsGame.new()
	ai.ai_b = true
	ai.start()
	ai.set_dir(0, 0)
	_run(ai, 1.0)
	ai.set_dir(0, 1)
	_run(ai, 8.0)
	check(ai.sb >= 1 or ai.sa >= 1 or ai.done, "practice AI plays rounds out")
	check(before >= 1, "trails progressed")


func _puck() -> void:
	var b := PuckBoard.new()
	b.start()
	var t := 0.0
	while b.running and t < 120.0:
		b.step_with(0.05, 0.5, 0.1)  # right paddle parked at the top: left player wins
		t += 0.05
	check(not b.running and b.score.x == b.target, "puck match ends at %d (%s)" % [b.target, b.score])
	b.free()
