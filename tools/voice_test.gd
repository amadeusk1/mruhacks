extends SceneTree
## Voice self-check: mu-law round trip error, and Net._relay_voice room/distance/rate filtering.
func _init() -> void:
	await process_frame
	var V = root.get_node("Voice")
	var worst := 0.0
	for i in 2001:
		var x := -1.0 + i * 0.001
		worst = maxf(worst, absf(V._mulaw_decode(V._mulaw_encode(x)) - x) / (absf(x) + 0.01))
	assert(worst < 0.06, "mulaw relative error %f" % worst)
	var N = root.get_node("Net")
	N._mode = N.Mode.HOST
	N._players = {1: N._blank(1, "Host", 0), 2: N._blank(2, "A", 1), 3: N._blank(3, "B", 2), 4: N._blank(4, "C", 3)}
	for id in [1, 2, 3, 4]:
		N._players[id]["hidden"] = false
		N._players[id]["location"] = "town"
	N._players[4]["location"] = "cafe_interior"   # other room
	N._voice_pos = {1: Vector3.ZERO, 2: Vector3(5, 0, 0), 3: Vector3(40, 0, 0), 4: Vector3(1, 0, 0)}
	N._players[5] = N._blank(5, "D", 4)
	N._players[5]["hidden"] = false
	N._players[5]["location"] = "town"   # no pose yet: must not be heard
	var pkt := PackedByteArray(); pkt.resize(960)
	# 2 is 5 m from host -> host hears it; 3 is 40 m away; 4 in another room
	N._relay_voice(2, pkt)
	N._relay_voice(3, pkt)
	N._relay_voice(4, pkt)
	N._relay_voice(5, pkt)
	assert(V._speakers.has(2) and not V._speakers.has(3) and not V._speakers.has(4) and not V._speakers.has(5), "room/distance filter")
	for k in 30:   # rate cap: 24000 B/s
		N._relay_voice(2, pkt)
	assert(int(N._voice_budget[2]["left"]) < 960, "rate cap")
	print("VOICE_TEST PASS mulaw_max_err=%.4f" % worst)
	N._mode = N.Mode.OFF
	quit()
