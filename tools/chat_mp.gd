extends Node
## Two-client chat test over real ENet: speech bubbles, typing indicator, minimize / unread / history.
##   Godot --path . res://tools/chat_mp.tscn -- --net-host --net-name=Snowdrop --net-port=7799 --out=/abs/dir/
##   Godot --path . res://tools/chat_mp.tscn -- --net-join --net-name=Milo --net-port=7799 --out=/abs/dir/
## The real world scene runs (launch args host / join); each side scripts its lines, screenshots
## chat_*.png and prints CHAT_MP checks. Exit 0 = every check passed.

var host := false
var me := "P"
var out := "/tmp/"
var world: Node
var checks := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--net-host": host = true
		if a.begins_with("--net-name="): me = a.trim_prefix("--net-name=")
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	UIRouter.settings["chat_minimized"] = false
	world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(world)  # its launch args host / join and drop us in town
	get_tree().create_timer(100.0).timeout.connect(func() -> void:
		print("CHAT_MP %s TIMEOUT %s" % [me, checks]); get_tree().quit(1))
	await _wait_in_town()
	await get_tree().create_timer(4.0).timeout  # both penguins in town
	_face_together()
	if host:
		await _host_script()
	else:
		await _client_script()
	var ok := checks.values().all(func(v: bool) -> bool: return v)
	print("CHAT_MP %s %s %s" % [me, "PASS" if ok else "FAIL", checks])
	await get_tree().create_timer(3.0).timeout  # let the other side finish its screenshots
	get_tree().quit(0 if ok else 1)


func _wait_in_town() -> void:
	while not (world.has_method("current_location_id") and str(world.call("current_location_id")) != "" and Net.roster().size() >= 2):
		await get_tree().create_timer(0.25).timeout


## Stand the two penguins a metre apart so one camera shows both bubbles.
func _face_together() -> void:
	var p := get_tree().get_first_node_in_group("local_player") as Node3D
	if p and not host:
		var other := get_tree().get_first_node_in_group("remote_player") as Node3D
		if other:
			p.global_position = other.global_position + Vector3(1.4, 0, 0.3)


func _bubbles() -> Node:
	return get_tree().root.find_child("ChatBubbles", true, false)


func _hud() -> Node:
	return world.get_node("PlayHud")


var _heard := {}   ## "typing:<id>" / "chat:<id>" -> true, from Net signals


func _listen() -> void:
	Net.typing_changed.connect(func(id: int, on: bool) -> void:
		if on: _heard["typing:%d" % id] = 1)
	Net.chat_from.connect(func(id: int, _s: String, _m: String) -> void:
		_heard["chat:%d" % id] = int(_heard.get("chat:%d" % id, 0)) + 1)


## Waits until `key` was heard `n` times (chats are counted per sender).
func _until(key: String, seconds: float, n := 1) -> bool:
	var end := Time.get_ticks_msec() + seconds * 1000.0
	while int(_heard.get(key, 0)) < n and Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.1).timeout
	return int(_heard.get(key, 0)) >= n


## Event-driven, so the two instances' different load times don't matter.
func _host_script() -> void:
	_listen()
	var milo := _peer_of("Milo")
	await _until("chat:%d" % milo, 60.0)  # handshake: the client says hi once it's listening
	world.call("send_chat", "Hey Milo! Want to go sledding after the movie?")
	await _until("typing:%d" % milo, 30.0)
	await get_tree().create_timer(0.3).timeout
	var b = _bubbles()._bubbles.get(milo)
	checks["sees_typing_dots"] = b != null and b.typing
	await _shot("chat_typing")
	await _until("chat:%d" % milo, 20.0, 2)
	await get_tree().create_timer(0.3).timeout
	b = _bubbles()._bubbles.get(milo)
	checks["sees_reply_bubble"] = b != null and not b.typing
	await _shot("chat_bubbles")
	await get_tree().create_timer(1.0).timeout
	world.call("send_chat", "Bring snacks. The popcorn machine is finally fixed")
	await get_tree().create_timer(1.0).timeout
	world.call("send_chat", "See you at the sled hill!")
	await get_tree().create_timer(10.0).timeout
	b = _bubbles()._bubbles.get(Net.local_id())
	checks["own_bubble_fades"] = b == null or not is_instance_valid(b) or b.modulate.a < 1.0


func _client_script() -> void:
	_listen()
	var host_id := _peer_of("Snowdrop")
	world.call("send_chat", "Hi!")  # handshake: listening now
	await _until("chat:%d" % host_id, 30.0)
	await get_tree().create_timer(0.3).timeout
	var b = _bubbles()._bubbles.get(host_id)
	checks["sees_host_bubble"] = b != null and not b.typing
	await get_tree().create_timer(1.0).timeout
	Net.note_typing(true)  # what the chat entry does while you type
	await get_tree().create_timer(2.5).timeout
	Net.note_typing(false)
	_hud().call("toggle_chat")  # minimize first; the host answers with two lines
	checks["minimized"] = bool(_hud().call("minimized"))
	world.call("send_chat", "Yes! Meet you at the hill. I call the blue sled")
	await get_tree().create_timer(1.0).timeout
	await _shot("chat_bubbles_client")
	var end := Time.get_ticks_msec() + 15000
	while int(_hud().get("_unread")) < 2 and Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.2).timeout
	checks["unread_badge"] = int(_hud().get("_unread")) == 2 and "2 new" in str(_hud().get("_toggle").text)
	await _shot("chat_minimized")
	_hud().call("toggle_chat")  # restore: full history, badge cleared
	await get_tree().create_timer(0.6).timeout
	var lines: PackedStringArray = _hud().get("_lines")
	checks["history_restored"] = lines.size() >= 5 and int(_hud().get("_unread")) == 0 and _hud().get("_log_panel").visible
	await _shot("chat_history")
	UIRouter.set_setting("chat_minimized", false)


func _peer_of(player_name: String) -> int:
	for p in Net.roster():
		if str(p.get("name", "")) == player_name:
			return int(p.get("id", 0))
	return -1


func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ("" if host else "") + ".png")
	print("CHAT_MP %s SAVED %s" % [me, name])
