extends SceneTree
## Two-process voice test. Host:   -- --vrole=host [--net-ws]
## Talker (client): -- --vrole=talk --voice-tone      Listener (client): -- --vrole=listen --vpos=X --vloc=town
## The listener prints VOICE_RX packets=N first_ms=T every second; the talker prints VOICE_TX_START ms.
var role := ""
var pos := Vector3.ZERO
var loc := "town"
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vrole="): role = a.trim_prefix("--vrole=")
		if a.begins_with("--vpos="): pos = Vector3(float(a.trim_prefix("--vpos=")), 0, 0)
		if a.begins_with("--vloc="): loc = a.trim_prefix("--vloc=")
	await process_frame
	var N = root.get_node("Net")
	var V = root.get_node("Voice")
	var U = root.get_node("UIRouter")
	U.settings["mic"] = role == "talk"
	U.settings["push_to_talk"] = false
	if role == "host":
		N.host_game("Host")
	else:
		N.join_game(role)
	for i in 40:
		await create_timer(0.25).timeout
		if N.is_online() and (role == "host" or N.multiplayer.get_unique_id() != 0):
			break
	await create_timer(1.0).timeout
	var secs := 12 if role != "host" else int(OS.get_environment("VSECS") if OS.get_environment("VSECS") != "" else "12")
	if role != "host":
		N.arrive(loc, "Spawn", false)
		await create_timer(0.5).timeout
	var first := -1.0
	var t0 := Time.get_unix_time_from_system()
	if role == "talk":
		print("VOICE_TX_START ms=%d" % int(t0 * 1000.0))
	for s in secs:
		for k in 10:
			if role != "host":
				N.note_pose(pos, 0.0, 0.0, false)
			elif OS.get_cmdline_user_args().has("--vfollow"):
				# listen host: stand on top of the first remote player so it is in range both ways
				if N._players.get(1, {}).get("location", "") == "":
					N._players[1]["location"] = "town"; N._players[1]["hidden"] = false
				for id in N._voice_pos:
					if int(id) != 1:
						N._voice_pos[1] = N._voice_pos[id]
						break
			await create_timer(0.1).timeout
			if role == "listen" and first < 0.0 and V.rx_packets > 0:
				first = Time.get_unix_time_from_system()
				print("VOICE_RX_FIRST ms=%d" % int(first * 1000.0))
		if role == "listen" or role == "host":
			print("VOICE_RX packets=%d" % V.rx_packets)
	quit()
