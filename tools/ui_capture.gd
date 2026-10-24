extends Node
## UI screenshot harness. Godot --path . res://tools/ui_capture.tscn -- --out=/abs/dir/ [--only=a,b]
## Saves <screen>.png at the window size (1280x720) for every screen in SHOTS.

var out := "user://"
var only: PackedStringArray = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	await _run()
	get_tree().quit()


func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)


func _run() -> void:
	if _want("main_menu"):
		var menu: Node = load("res://ui/screens/main_menu.tscn").instantiate()
		get_tree().root.add_child.call_deferred(menu)
		await _wait(5.0)
		await _shot("main_menu")
		if _want("settings_from_menu"):
			pass
		menu.queue_free()
		await _wait(0.3)
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await _wait(1.0)
	var lobby: Node = w.get_node("Lobby")
	for step in ["penguin_setup", "choose_world", "joining"]:
		if _want(step) and lobby.has_method("debug_show"):
			lobby.call("debug_show", step)
			await _wait(1.2)
			await _shot(step)
	if lobby.has_method("debug_show"):
		lobby.call("debug_show", "choose_world")
	w.call("_on_solo_pressed")
	await _wait(7.0)
	if _want("hud"):
		_stand_at_cafe()
		await _wait(1.5)
		await _shot("hud")
	for s in ["map", "friends", "player_card", "emotes", "pause", "settings", "controls", "accessibility",
			"microphone", "connection_lost", "leave_confirm", "results"]:
		if not _want(s):
			continue
		var c: Control = UIScreens.debug_open(s)
		await _wait(1.0)
		await _shot(s)
		UIRouter.close_all()
		await _wait(0.3)


## Put the penguin just outside the café door (its Interactable) so the HUD shows "Enter Café".
func _stand_at_cafe() -> void:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	for n in get_tree().get_nodes_in_group("interactables"):
		var key := (str(n.get("location")) + str(n.get("title"))).to_lower()
		if "caf" in key and player:
			var door := (n as Node3D).global_position
			var out := (Vector3(0, door.y, 0) - door).normalized()
			player.global_position = door + out * 1.2
			if player.has_method("halt"):
				player.call("halt")
			if player.has_method("face_point"):
				player.call("face_point", door)
			print("AT CAFE ", door)
			return
	print("NO CAFE INTERACTABLE")


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + n + ".png")
	print("SAVED ", n)
