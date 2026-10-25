extends Node
## Screenshots of the sled hill and the arcade for review (windowed, it renders):
##   Godot --path . res://tools/minigame_capture.tscn -- --out=/abs/dir/ --what=sled|arcade
var out := "/tmp/"
var what := "sled"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--what="): what = a.trim_prefix("--what=")
	if what == "sled":
		await _sled()
	elif what == "arcade":
		await _arcade()
	get_tree().quit()


func _arcade() -> void:
	# every solo cabinet game, played for a few seconds with held inputs
	for g in ["tetris", "fish", "dino", "pac", "star"]:
		var ui: Control = preload("res://ui/activities/arcade/cabinet_play.gd").new()
		ui.game_id = g
		ui.cab_key = "arcade:test_" + g
		add_child(ui)
		Input.action_press("move_right")
		Input.action_press("move_forward")
		await get_tree().create_timer(1.2).timeout
		await _save("arcade_%s_countdown" % g)
		await get_tree().create_timer(2.6).timeout
		Input.action_release("move_forward")
		await get_tree().create_timer(1.6).timeout
		Input.action_release("move_right")
		Input.action_press("move_left")
		await get_tree().create_timer(1.2).timeout
		Input.action_release("move_left")
		await _save("arcade_%s" % g)
		ui.queue_free()
		await get_tree().process_frame
	# duo cabinet solo practice: Puck Rally and Snow Trails, then results
	for g in ["puck", "trails"]:
		var duo: Control = preload("res://ui/activities/arcade/arcade_ui.gd").new()
		add_child(duo)
		duo.preview("lobby")
		duo.game = g
		duo._build()
		await get_tree().create_timer(0.8).timeout
		await _save("arcade_duo_lobby_%s" % g)
		duo.start_solo()
		await get_tree().create_timer(3.5).timeout
		await _save("arcade_duo_%s" % g)
		duo.queue_free()
		await get_tree().process_frame
	# the room: cabinet screens in attract mode, one showing a player
	ArcadeNet.boards = {"tetris": [{"name": "Milo", "score": 4200}, {"name": "Pip", "score": 3100}]}
	var room: Node3D = load("res://scenes/locations/arcade.tscn").instantiate()
	add_child(room)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2.2, 0.8)
	cam.look_at(Vector3(0, 1.0, -3.6))
	cam.current = true
	await get_tree().create_timer(2.0).timeout
	for screen in room.find_children("Screen", "", true, false):
		if screen.get("game") == "fish":
			ArcadeNet.playing[screen.get("_cab")] = {"name": "Snowdrop", "game": "fish", "score": 1250}
	await get_tree().create_timer(1.0).timeout
	await _save("arcade_room_screens")
	cam.position = Vector3(-1.2, 1.5, -1.6)
	cam.look_at(Vector3(-2.0, 1.1, -3.8))
	await get_tree().create_timer(4.2).timeout
	await _save("arcade_room_closeup")


func _sled() -> void:
	var run: Node = load("res://scenes/sled_run.tscn").instantiate()
	add_child(run)
	await get_tree().create_timer(1.5).timeout
	await _save("sled_menu")
	SledRace.time_trial()
	await get_tree().create_timer(1.6).timeout
	await _save("sled_countdown")
	var sled: Node3D = run.get_node("Sled")
	var t0 := Time.get_ticks_msec()
	var shots := [5.0, 9.0, 13.0, 18.0]
	while Time.get_ticks_msec() - t0 < 45000:
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if not shots.is_empty() and el >= float(shots[0]):
			shots.pop_front()
			await _save("sled_run_%02d" % int(el))
			print("SLED s=%.1f speed=%.1f" % [sled.get("course_s"), sled.get("speed")])
		if run.get("_state") == "finished":
			break
		await get_tree().process_frame
	print("SLED end state=%s s=%.1f t=%.1f" % [run.get("_state"), sled.get("course_s"), (Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().create_timer(1.0).timeout
	await _save("sled_finish")


func _save(name: String) -> void:
	for f in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("SAVED ", name)
