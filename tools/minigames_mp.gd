extends Node
## Two-instance test over real ENet on localhost: a sled race, then a Snow Trails duo match.
##   Godot --path . res://tools/minigames_mp.tscn -- --role=host --name=Snowdrop --net-port=7791 --out=/abs/dir/
##   Godot --headless --path . res://tools/minigames_mp.tscn -- --role=client --name=Milo --net-port=7791
## Prints MP lines; the host saves screenshots of the race lobby, the race and the podium.

var role := "host"
var me := "P"
var out := "/tmp/"
var _run: Node
var _results := false
var _duo_done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
		if a.begins_with("--name="): me = a.trim_prefix("--name=")
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	Net.session_started.connect(_on_session)
	var err := Net.host_game(me) if role == "host" else Net.join_game(me)
	print("MP %s start err='%s'" % [me, err])
	get_tree().create_timer(170.0).timeout.connect(func() -> void:
		print("MP %s TIMEOUT results=%s duo=%s" % [me, _results, _duo_done])
		get_tree().quit(1))


func _on_session() -> void:
	await get_tree().create_timer(2.0).timeout
	Net.arrive("sled_hill", "", false)
	_run = load("res://scenes/sled_run.tscn").instantiate()
	add_child(_run)
	SledRace.view_changed.connect(_on_view)
	await get_tree().create_timer(2.5).timeout
	SledRace.join_race()
	print("MP %s joined race" % me)


func _on_view(v: Dictionary) -> void:
	var phase := str(v.get("phase", ""))
	if role == "host" and phase == "lobby" and (v.get("lobby", []) as Array).size() == 2 and not has_meta("lobby_shot"):
		set_meta("lobby_shot", true)
		await _shot("sled_race_lobby")
		SledRace.start_now()
	if role == "host" and phase == "racing" and not has_meta("race_shot") and float(v.get("left", 0.0)) < -6.0:
		set_meta("race_shot", true)
		await _shot("sled_race_live")
	if phase == "results" and not _results:
		_results = true
		var rows: Array = v.get("standings", [])
		var line := []
		for r in rows:
			line.append("%s:%s" % [r["name"], "DNF" if bool(r["dnf"]) else "%.2f" % float(r["time"])])
		print("MP %s RACE RESULTS %s board=%s" % [me, line, v.get("board", [])])
		await get_tree().create_timer(1.5).timeout
		await _shot("sled_race_podium")
		await get_tree().create_timer(1.0).timeout
		_duo()


## Both sit at one duo cabinet, pick Snow Trails, ready, and steer randomly until results.
func _duo() -> void:
	SledRace.leave_race()
	_run.queue_free()
	Net.arrive("arcade", "", false)
	await get_tree().create_timer(1.5).timeout
	Net.claim_bench("arcade:TestDuo_player_%d" % (1 if role == "host" else 2))
	ArcadeNet.duo_changed.connect(_on_duo)
	await get_tree().create_timer(2.0).timeout
	ArcadeNet.duo_pick("trails")
	await get_tree().create_timer(0.5).timeout
	ArcadeNet.duo_ready()
	print("MP %s duo ready" % me)
	while not _duo_done:
		await get_tree().create_timer(0.4).timeout
		ArcadeNet.duo_input(float(randi() % 4))


func _on_duo(cab: String, s: Dictionary) -> void:
	if str(s.get("phase", "")) == "results" and not _duo_done:
		_duo_done = true
		print("MP %s DUO RESULTS cab=%s game=%s %d-%d names=%s" % [me, cab, s.get("game"), int(s.get("sa", 0)), int(s.get("sb", 0)), s.get("names")])
		await get_tree().create_timer(3.0).timeout
		get_tree().quit(0)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("MP saved ", name)
