extends SceneTree

## Shot-arc check for court_match: each loft should fly a different arc height and still drop in.
##   Godot --headless --path . -s res://tools/court_aim_check.gd

const Match := preload("res://scripts/court_match.gd")


func _init() -> void:
	var fails := 0
	var last_apex := 0.0
	for loft in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for dist in [2.0, 4.5]:
			var m := Match.new()
			m.configure(Vector3(dist - 2.0, 1.67, 0.0), AABB(Vector3(-6, 0, -4), Vector3(12, 0.2, 8)))
			m.force_make = true
			var bodies := {1: {"x": -2.0, "y": 0.0, "z": 0.0, "yaw": -PI / 2.0, "speed": 0.0}}
			m.ball_pos = Vector3(-2.0, 0.12, 0.0)
			m.tick(0.016, [1], bodies)
			if m.ball_mode != "held":
				print("COURT_AIM FAIL not holding")
				fails += 1
				continue
			m.request(1, "shoot:%.2f" % loft)
			var apex := 0.0
			for i in 400:
				m.tick(0.016, [1], bodies)
				apex = maxf(apex, m.ball_pos.y)
			var scored := m.coral_score > 0
			print("COURT_AIM dist=%.1f loft=%.2f apex=%.2f scored=%s fit=%.2f" % [dist, loft, apex, scored, Match.loft_fit(dist, loft)])
			if not scored:
				fails += 1
			if dist == 2.0:
				if apex <= last_apex and loft > 0.0:
					print("COURT_AIM FAIL apex did not rise with loft")
					fails += 1
				last_apex = apex
	# Green means in: random rolls on, every green arc over the whole range must score.
	var greens := 0
	var yellow_made := 0
	var yellow_total := 0
	for hoop_x in [0.5, 1.5, 2.5, 3.5, 4.5, 5.5]:
		for step in 21:
			var loft := step * 0.05
			var m := Match.new()
			m.configure(Vector3(hoop_x, 1.67, 0.0), AABB(Vector3(-6, 0, -4), Vector3(12, 0.2, 8)))
			var bodies := {1: {"x": -2.0, "y": 0.0, "z": 0.0, "yaw": -PI / 2.0, "speed": 0.0}}
			m.ball_pos = Vector3(-2.0, 0.12, 0.0)
			m.tick(0.016, [1], bodies)
			var dist: float = hoop_x - (-2.0 + 0.34)
			var fit: float = Match.loft_fit(dist, loft)
			m.request(1, "shoot:%.2f" % loft)
			for i in 400:
				m.tick(0.016, [1], bodies)
			if fit >= Match.FIT_GOOD:
				greens += 1
				if m.coral_score == 0:
					print("COURT_AIM FAIL green missed: dist=%.1f loft=%.2f" % [dist, loft])
					fails += 1
			elif fit >= Match.FIT_OK:
				yellow_total += 1
				yellow_made += 1 if m.coral_score > 0 else 0
	print("COURT_AIM green arcs tried=%d  yellow made %d of %d" % [greens, yellow_made, yellow_total])
	var pts := Match.arc_points(Vector3(0, 1, 0), Vector3(4, 1.67, 0), 0.5, 10)
	print("COURT_AIM arc ends at %s (want 4, 1.67, 0)" % pts[pts.size() - 1])
	if pts[pts.size() - 1].distance_to(Vector3(4, 1.67, 0)) > 0.01:
		fails += 1
	print("COURT_AIM %s" % ("OK" if fails == 0 else "FAILED %d" % fails))
	quit(fails)
