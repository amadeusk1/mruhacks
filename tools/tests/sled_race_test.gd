extends SceneTree
## Headless check of the Sled Hill race rules (SledRaceGame + SledCourse).
##   Godot --headless --path . --script res://tools/tests/sled_race_test.gd

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	_course()
	_race()
	_trial_and_shortcut()
	_late_join_and_leave()
	print("SLED_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _course() -> void:
	var L := SledCourse.length()
	check(L > 330.0 and L < 420.0, "course length %f" % L)
	check(SledCourse.finish_s() > float(SledCourse.CHECKPOINTS[-1]), "finish after last checkpoint")
	for s in [10.0, 120.0, 250.0]:
		var p := SledCourse.point(s, 2.0)
		var back := SledCourse.locate(p)
		check(absf(back.x - s) <= 1.01 and absf(back.y - 2.0) < 0.3, "locate roundtrip at %s -> %s" % [s, back])
	check(SledCourse.point(100.0).y < SledCourse.point(20.0).y - 10.0, "course goes downhill")


## Rides a rider down the course in steps of `step` metres per 0.1 s.
func _ride(g: SledRaceGame, id: int, t0: float, step: float) -> float:
	var t := t0
	var s := SledCourse.START_S
	while s < SledCourse.finish_s() + 2.0:
		g.pose(id, SledCourse.point(s, 0.5), t)
		s += step
		t += 0.1
	g.pose(id, SledCourse.point(SledCourse.finish_s() + 2.0), t)
	return t


func _race() -> void:
	var g := SledRaceGame.new()
	g.join(1, "Snowdrop", 0.0)
	check(g.phase == "lobby" and g.deadline == 0.0, "one racer waits")
	g.tick(30.0)
	check(g.phase == "lobby", "no start alone")
	g.join(2, "Milo", 31.0)
	check(g.deadline == 31.0 + SledRaceGame.LOBBY_WAIT, "auto-start timer")
	g.join(3, "Pip", 40.0)
	check(g.deadline >= 45.0, "late join tops up")
	g.start_now(2, 41.0)
	g.tick(41.0)
	check(g.phase == "countdown" and g.racers.size() == 3, "countdown with 3")
	check(int(g.racers[3]["lane"]) == 2, "lanes in join order")
	g.pose(1, SledCourse.point(60.0), 42.0)
	check(float(g.racers[1]["s"]) == 0.0, "poses before go ignored")
	g.tick(44.0)
	check(g.phase == "racing", "racing at start_at")
	var t1 := _ride(g, 2, 44.0, 2.0)   # 20 m/s: fastest
	var t2 := _ride(g, 1, 44.0, 1.5)
	check(bool(g.racers[2]["done"]) and bool(g.racers[1]["done"]), "two finished")
	var st := g.standings()
	check(int(st[0]["id"]) == 2 and int(st[1]["id"]) == 1 and int(st[2]["id"]) == 3, "order by time then distance")
	g.tick(maxf(t1, t2) + 1.0)
	check(g.phase == "racing", "waits for the last racer")
	g.tick(t1 + SledRaceGame.DNF_AFTER + 0.1)
	check(g.phase == "results" and bool(g.racers[3]["dnf"]), "DNF after the first finish + 30 s")
	check(g.board.size() == 2 and str(g.board[0]["name"]) == "Milo", "board best first")
	var v := g.view_for(3, t1 + 31.0)
	check(v.has("standings") and (v["standings"] as Array).size() == 3, "results in view")
	g.tick(t1 + 31.0 + SledRaceGame.RESULTS_HOLD)
	check(g.phase == "idle" and g.racers.is_empty(), "back to idle")


func _trial_and_shortcut() -> void:
	var g := SledRaceGame.new()
	g.trial(5, "Tux", 0.0)
	check(g.view_for(5, 1.0)["trial_left"] == 2.0, "trial countdown")
	# straight to the finish line without the checkpoints: rejected
	g.pose(5, SledCourse.point(SledCourse.START_S + 1.0), 3.5)
	g.pose(5, SledCourse.point(SledCourse.finish_s() + 1.0), 3.6)
	check(g.trials.has(5) and not g.trial_results.has(5), "teleport to finish rejected")
	g.trials.erase(5)
	g.trial(5, "Tux", 10.0)
	var t := _ride(g, 5, 13.0, 1.8)
	check(g.trial_results.has(5) and absf(float(g.trial_results[5]["time"]) - (t - 13.0)) < 0.2, "trial time from server clock")
	check(int(g.trial_results[5]["rank"]) == 1, "trial ranks on board")
	g.trial(5, "Tux", 100.0)
	_ride(g, 5, 103.0, 1.0)  # slower: keeps the best
	check(g.board.size() == 1 and float(g.board[0]["time"]) < 25.0, "one entry per name, best kept")


func _late_join_and_leave() -> void:
	var g := SledRaceGame.new()
	g.join(1, "A", 0.0)
	g.join(2, "B", 0.0)
	g.tick(10.0)
	g.tick(13.0)
	check(g.phase == "racing", "racing")
	g.join(3, "C", 14.0)
	check(g.pending.has(3) and not g.racers.has(3), "mid-race join waits")
	g.leave(1, 15.0)
	check(bool(g.racers[1]["dnf"]), "leaver is DNF")
	_ride(g, 2, 15.0, 2.0)
	g.tick(60.0)
	check(g.phase == "results", "results when everyone is done")
	g.tick(60.0 + SledRaceGame.RESULTS_HOLD)
	check(g.phase == "lobby" and g.lobby == [3], "pending racer moves to the next lobby")
	for i in range(10, 20):
		g.join(i, "P%d" % i, 80.0)
	check(g.lobby.size() == SledRaceGame.MAX_RACERS, "lobby caps at 8")
