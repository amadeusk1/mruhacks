extends Node3D

## Sled Hill. The bus loads this room for the sled_hill destination.
## The start card offers a Time trial (solo, any time) or a Race (2-8 riders: lobby, start lights,
## live placings, podium, rematch). SledRace (autoload) runs the rules and the best-times board on
## the server; this scene drives the local sled, the start lights, the HUD and the other riders.

@onready var sled: CharacterBody3D = $Sled
@onready var hud: CanvasLayer = $HUD
@onready var track: Node3D = $Track
@onready var cam: Node3D = $CameraRig

var _mode := ""            ## "" | trial | race
var _state := "menu"       ## menu | lobby | countdown | running | finished | results
var _go_at := 0.0          ## local clock when the current run starts
var _clock := 0.0
var _race_seen := 0
var _trial_seen := {}
var _trial_id := 0
var _ghosts: Dictionary = {}
var _beeped := 4
var _view: Dictionary = {}
var _finish_time := 0.0


func _ready() -> void:
	add_to_group("activity")
	var nested := get_tree().get_first_node_in_group("world") != null
	if nested:
		for n in ["WorldEnvironment", "DirectionalLight3D"]:
			if has_node(n):
				get_node(n).queue_free()
	sled.crashed.connect(func() -> void: hud.flash("Spin out!", Color("#D4483A")))
	sled.boosted.connect(func() -> void: hud.flash("Boost!", Color("#E86D58")))
	sled.checkpoint.connect(func(i: int) -> void: hud.flash("Checkpoint %d" % (i + 1), Color("#2AA9A7")))
	sled.finished.connect(_on_finished)
	hud.retry_pressed.connect(_on_retry)
	hud.town_pressed.connect(_on_town)
	hud.trial_pressed.connect(func() -> void: SledRace.time_trial())
	hud.race_pressed.connect(func() -> void: SledRace.join_race())
	hud.start_now_pressed.connect(func() -> void: SledRace.start_now())
	hud.leave_lobby_pressed.connect(func() -> void:
		SledRace.leave_race()
		_menu())
	SledRace.view_changed.connect(_on_view)
	var mine := Net.local_profile()
	sled.apply_identity(str(mine["name"]), int(mine["color"]))
	if Net.is_online():
		Net.sled_pose.connect(_on_sled_pose)
	_park(_trial_spot())
	_menu()


func _process(delta: float) -> void:
	_clock += delta
	if Net.is_online():
		_sync_ghosts()
	match _state:
		"countdown":
			var left := _go_at - _clock
			var n := int(ceil(left))
			if n != _beeped and n >= 1 and n <= 3:
				_beeped = n
				hud.set_countdown(str(n))
				track.set_lamps(4 - n, false)
				Sfx.play(self, "count", -4.0)
			if left <= 0.0:
				_go()
		"running", "finished":
			if _state == "running" and _clock - _go_at > 0.6 and hud._count.text == "Go!":
				hud.set_countdown("")
			_update_next()
	if _state == "running" and track.clock_label:
		track.clock_label.text = hud._fmt(_clock - _go_at)
	if _state == "running":
		SledRace.local_pose(sled.global_position)


func _go() -> void:
	_state = "running"
	_beeped = 4
	track.set_lamps(3, true)
	hud.set_countdown("Go!")
	hud.start_clock()
	Sfx.play(self, "go", -2.0)
	sled.begin()


func _update_next() -> void:
	for cp in SledCourse.CHECKPOINTS:
		if sled.course_s < float(cp):
			hud.set_next(float(cp) - sled.course_s, false)
			return
	hud.set_next(SledCourse.finish_s() - sled.course_s, true)


## Server view: lobby, countdown, live standings, results, time-trial starts and results.
func _on_view(v: Dictionary) -> void:
	_view = v
	hud.set_board(v.get("board", []))
	var phase := str(v.get("phase", ""))
	var me := Net.local_id()
	# time trial accepted: line up and count down
	if v.has("trial_left") and int(v.get("trial_id", 0)) != _trial_id:
		_trial_id = int(v.get("trial_id", 0))
		_begin_countdown("trial", _trial_spot(), float(v["trial_left"]))
		return
	if v.has("trial_result") and _mode == "trial":
		var r: Dictionary = v["trial_result"]
		var key := str(r)
		if not _trial_seen.has(key):
			_trial_seen[key] = true
			var rank := int(r.get("rank", 0))
			var note := "Official time %s." % hud._fmt(float(r["time"]))
			if rank == 1:
				note = "New hill record! %s" % hud._fmt(float(r["time"]))
			elif rank > 0:
				note = "#%d on the hill board! %s" % [rank, hud._fmt(float(r["time"]))]
			hud.set_finish_note(note)
	# race
	if bool(v.get("racer", false)) and phase == "countdown" and int(v.get("race", 0)) != _race_seen:
		_race_seen = int(v.get("race", 0))
		_begin_countdown("race", _lane_spot(int(v.get("lane", 0))), float(v.get("left", 3.0)))
		return
	if bool(v.get("in_lobby", false)) or bool(v.get("pending", false)):
		if _state != "running" and _state != "countdown":
			_state = "lobby"
			hud.show_lobby(v.get("lobby", []), float(v.get("left", 0.0)), bool(v.get("pending", false)))
		return
	if bool(v.get("racer", false)) and _mode == "race" and v.has("standings"):
		hud.set_standings(v["standings"], me)
		if phase == "results" and _state != "results":
			_state = "results"
			hud.show_run_hud(false, false)
			hud.show_podium(v["standings"], me, _colors())
			Sfx.play(self, "win", -4.0)
		elif _state == "finished":
			var place := 1
			for row in v["standings"]:
				if int(row["id"]) == me:
					break
				place += 1
			hud.set_finish_note("You placed %s. Waiting for the others..." % hud.ORDINAL[clampi(place - 1, 0, 7)])
		return
	if _state == "lobby":
		_menu()


func _begin_countdown(mode: String, spot: Transform3D, left: float) -> void:
	_mode = mode
	_state = "countdown"
	_go_at = _clock + maxf(0.0, left)
	_beeped = 4
	hud.hide_cards()
	hud.reset_clock()
	hud.show_run_hud(true, mode == "race")
	hud.set_hint("Drag the stick to steer" if Mobile.active() else "A and D to steer")
	track.set_lamps(0, false)
	_park(spot)


func _on_finished() -> void:
	_state = "finished"
	_finish_time = _clock - _go_at
	hud.stop_clock(_finish_time)
	hud.set_hint("")
	var best: bool = hud.save_best(_finish_time)
	_pay("sled", 15 if best else 5)
	if _mode == "race":
		hud.show_finish("Finished!", _finish_time, "Waiting for the others...", "")
	else:
		hud.show_finish("Finished!", _finish_time, "New personal best!" if best else "", "Retry")


func _on_retry() -> void:
	if _mode == "race" and _state in ["countdown", "running"]:
		return
	SledRace.time_trial()


func _menu() -> void:
	_state = "menu"
	_mode = ""
	hud.show_run_hud(false, false)
	hud.set_countdown("")
	hud.set_hint("")
	var waiting := (_view.get("lobby", []) as Array).size()
	hud.show_menu(Net.is_online(), waiting)
	track.set_lamps(0, false)


func _park(spot: Transform3D) -> void:
	sled.reset_run(spot.origin, spot.basis.get_euler().y)
	if cam.has_method("snap"):
		cam.snap()


func _trial_spot() -> Transform3D:
	return _spot(SledCourse.START_S - 3.0, 0.0)


## Grid: two rows of four behind the start line, in lobby join order.
func _lane_spot(lane: int) -> Transform3D:
	return _spot(SledCourse.START_S - 3.0 - float(lane / 4) * 3.2, -3.3 + float(lane % 4) * 2.2)


func _spot(s: float, lateral: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, SledCourse.yaw(s)), SledCourse.point(s, lateral) + Vector3.UP * 0.25)


func _colors() -> Dictionary:
	var out := {}
	for entry in Net.roster():
		out[int(entry.get("id", 0))] = Net.coat_color(int(entry.get("color", 0)))
	out[Net.local_id()] = Net.coat_color(int(Net.local_profile().get("color", 0)))
	return out


func _on_sled_pose(peer_id: int, x: float, y: float, z: float, yaw: float, steer: float, crashed: bool) -> void:
	if not _ghosts.has(peer_id):
		_sync_ghosts()
	var ghost: Object = _ghosts.get(peer_id)
	if ghost != null and is_instance_valid(ghost):
		ghost.present_remote(Vector3(x, y, z), yaw, steer, crashed)


func _sync_ghosts() -> void:
	if not Net.is_online():
		_clear_ghosts()
		return
	var live: Dictionary = {}
	for entry in Net.roster():
		var id := int(entry.get("id", 0))
		if id == Net.local_id():
			continue
		if str(entry.get("location", "")) != "sled_hill" or bool(entry.get("hidden", false)):
			continue
		live[id] = true
		if not _ghosts.has(id) or not is_instance_valid(_ghosts[id]):
			var ghost := sled.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as CharacterBody3D
			ghost.name = "Guest%s" % id
			ghost.set_meta("remote_peer", id)
			add_child(ghost)
			var spot := _trial_spot()
			ghost.reset_run(spot.origin + Vector3(2.0 * float(_ghosts.size() + 1), 0, 2.0), spot.basis.get_euler().y)
			_ghosts[id] = ghost
		_ghosts[id].apply_identity(str(entry.get("name", "Penguin")), int(entry.get("color", 0)), entry.get("outfit", {}))
	var stale: Array = []
	for id in _ghosts.keys():
		if not live.has(int(id)):
			stale.append(int(id))
	for id in stale:
		var node: Node = _ghosts[id]
		_ghosts.erase(id)
		if is_instance_valid(node):
			node.queue_free()


func _clear_ghosts() -> void:
	for id in _ghosts.keys():
		var node: Node = _ghosts[id]
		if is_instance_valid(node):
			node.queue_free()
	_ghosts.clear()


func _pay(id: String, coins: int) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("note_activity"):
		world.call("note_activity", id, coins)


func _on_town() -> void:
	SledRace.leave_race()
	hud.lock()
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("travel_to"):
		world.call_deferred("travel_to", LocationCatalog.MAIN)
		return
	get_tree().change_scene_to_file("res://scenes/world.tscn")
