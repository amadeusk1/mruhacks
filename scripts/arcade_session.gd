extends Node

## Opens Puck Rally when a penguin sits at an arcade cabinet.
## Solo practice is local. Two players on one duo cabinet ready up and the host runs the puck.


var _ui = null


func _ready() -> void:
	Activities.requested.connect(_on_requested)
	Net.roster_changed.connect(_paint)
	Net.arcade_state.connect(_on_state)
	Net.seat_denied.connect(_on_denied)


const _CABINET_GAMES := ["pac", "tetris", "dino"]


func _on_requested(activity: String, anchor: Node, _player: Node) -> void:
	if activity in _CABINET_GAMES:
		_open_cabinet(activity, anchor)
		return
	if activity != "arcade" or _ui != null:
		return
	var ui := preload("res://ui/activities/arcade/arcade_ui.gd").new()
	ui.cabinet = _cabinet(anchor)
	ui.station = _side(anchor)
	ui.slots = _slots(anchor, ui.cabinet)
	ui.intent.connect(_on_intent)
	_ui = ui
	UIRouter.push(ui)
	_arm_music(ui)
	Net.arcade_watch(ui.cabinet)
	_paint()


func _open_cabinet(activity: String, anchor: Node) -> void:
	if _ui != null:
		return
	var ui := preload("res://ui/activities/arcade/cabinet_play.gd").new()
	ui.game_id = activity
	ui.anchor = anchor
	ui.intent.connect(_on_intent)
	_ui = ui
	UIRouter.push(ui)
	_arm_music(ui)


func _arm_music(ui: Node) -> void:
	var token := Music.play_arcade()
	ui.tree_exiting.connect(func() -> void: Music.leave_arcade(token))


func _on_intent(action: String) -> void:
	if _ui == null:
		return
	match action:
		"leave":
			_ui = null
			Net.arcade_stop()
			var player := get_tree().get_first_node_in_group("local_player")
			if player != null and player.has_method("stand_up"):
				player.call("stand_up")
		"solo":
			Net.arcade_solo()
		"ready":
			Net.arcade_ready()
		"play_again":
			if not ("local_solo" in _ui):
				return
			if bool(_ui.local_solo) or not _partner_here():
				Net.arcade_solo()
				_ui.start_solo()
			else:
				Net.arcade_watch(str(_ui.cabinet))
				_ui.return_lobby()
				_paint()


func _on_state(state: Dictionary) -> void:
	if _ui == null or not ("cabinet" in _ui) or str(state.get("cab", "")) != str(_ui.cabinet) or bool(_ui.local_solo):
		return
	var phase := str(state.get("phase", ""))
	if phase == "results":
		_ui.show_match_end(int(state.get("sa", 0)), int(state.get("sb", 0)))
	elif phase == "live":
		_ui.apply_live(
			float(state["px"]), float(state["py"]),
			float(state["lp"]), float(state["rp"]),
			int(state["sa"]), int(state["sb"])
		)


func _on_denied(key: String) -> void:
	if _ui == null or not ("cabinet" in _ui):
		return
	var cab := str(_ui.cabinet)
	if cab != "" and key.begins_with(cab):
		_ui.close()


func _paint() -> void:
	if _ui == null or not is_instance_valid(_ui):
		_ui = null
		return
	if not ("phase" in _ui) or str(_ui.phase) != "lobby" or bool(_ui.local_solo):
		return
	var rows: Array = [
		{"name": "", "status": "", "body": 0, "outfit": {}},
		{"name": "", "status": "", "body": 0, "outfit": {}},
	]
	var waiting := "Waiting for a friend" if int(_ui.slots) > 1 else "This cabinet is solo"
	if Net.is_online():
		for entry in Net.roster():
			var bench := str(entry.get("bench", ""))
			if _cabinet_of_bench(bench) != str(_ui.cabinet):
				continue
			var side := 1 if bench.ends_with("_player_2") else 0
			rows[side] = {
				"name": str(entry.get("name", "")),
				"status": "At the cabinet",
				"body": int(entry.get("color", 0)),
				"outfit": {},
			}
	var profile := Net.local_profile()
	rows[clampi(int(_ui.station), 0, 1)] = {
		"name": str(profile.get("name", "You")),
		"status": "Ready to play!",
		"body": int(profile.get("color", 0)),
		"outfit": {},
	}
	for i in 2:
		if str(rows[i].get("name", "")) == "":
			rows[i]["status"] = waiting
	_ui.versus = int(_ui.slots) > 1 and str(rows[0]["name"]) != "" and str(rows[1]["name"]) != ""
	_ui.show_lobby(rows)


func _partner_here() -> bool:
	if _ui == null or str(_ui.cabinet) == "":
		return false
	var n := 0
	for entry in Net.roster():
		if _cabinet_of_bench(str(entry.get("bench", ""))) == str(_ui.cabinet):
			n += 1
	return n >= 2


func _cabinet(anchor: Node) -> String:
	if anchor.has_method("bench_key"):
		return _cabinet_of_bench(str(anchor.call("bench_key")))
	return ""


func _side(anchor: Node) -> int:
	if anchor.has_method("bench_key") and str(anchor.call("bench_key")).ends_with("_player_2"):
		return 1
	return 0


func _slots(anchor: Node, cab: String) -> int:
	if cab == "" or anchor.get_parent() == null:
		return 1
	var n := 0
	for s in anchor.get_parent().get_children():
		if s.has_method("bench_key") and _cabinet_of_bench(str(s.call("bench_key"))) == cab:
			n += 1
	return maxi(n, 1)


func _cabinet_of_bench(bench: String) -> String:
	if bench.ends_with("_player_1"):
		return bench.trim_suffix("_player_1")
	if bench.ends_with("_player_2"):
		return bench.trim_suffix("_player_2")
	return ""
