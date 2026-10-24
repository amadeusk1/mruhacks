extends SceneTree
## Voice self-check: mu-law round trip, Opus packet format, distance falloff, native Opus encode /
## decode (when TwoVoIP is loaded) with bandwidth, and Net._relay_voice room/distance/rate filtering.
func _init() -> void:
	await process_frame
	var V = root.get_node("Voice")
	var worst := 0.0
	for i in 2001:
		var x := -1.0 + i * 0.001
		worst = maxf(worst, absf(V._mulaw_decode(V._mulaw_encode(x)) - x) / (absf(x) + 0.01))
	assert(worst < 0.06, "mulaw relative error %f" % worst)
	# packet format: round trip, never 960 bytes (legacy marker), malformed -> []
	var frames := [PackedByteArray([1, 2, 3]), PackedByteArray([4, 5]), PackedByteArray([6])]
	var pkt: PackedByteArray = V.build_packet(frames)
	assert(V.parse_packet(pkt) == frames, "packet round trip")
	var big := PackedByteArray(); big.resize(950)
	assert(V.build_packet([big]).size() != 960, "legacy size collision")
	assert(V.parse_packet(pkt.slice(0, pkt.size() - 1)).is_empty(), "truncated packet")
	assert(V.parse_packet(PackedByteArray([0xA2, 1, 1, 0, 9])).is_empty(), "unknown version")
	# falloff: full near, about -10 dB at 8 m, silent by 14 m
	assert(V.gain_at(2.0) == 1.0 and V.gain_at(14.0) == 0.0 and V.gain_at(20.0) == 0.0, "falloff ends")
	assert(absf(V.gain_at(8.0) - 0.298) < 0.01, "falloff mid %f" % V.gain_at(8.0))
	var kbps := 0.0
	if V._enc != null:  # native Opus: 1 s of a 440 Hz tone through the real send path
		V._tone = true
		var before: int = V.tx_bytes  # Net is offline: send_voice is a no-op, tx_bytes still counts
		for k in 50:
			V._pump_mic(0.02)
		kbps = (V.tx_bytes - before) * 8.0 / 1000.0
		assert(kbps > 15.0 and kbps < 40.0, "opus bitrate %f kbps" % kbps)
		var enc_frames := []
		var t := 0.0
		for k in 10:
			var c := PackedVector2Array()
			for i in 960:
				t += 1.0 / 48000.0
				c.append(Vector2.ONE * 0.3 * sin(TAU * 440.0 * t))
			V._enc.call("process_chunk", c)
			enc_frames.append(V._enc.call("encode_chunk", PackedByteArray(), 0))
		V.receive(77, V.build_packet(enc_frames.slice(0, 3)))
		V.receive(77, V.build_packet(enc_frames.slice(3, 6)))
		var pb: Object = V._speakers[77]["opus_pb"]
		await create_timer(0.3).timeout
		assert(int(pb.call("get_decode_errors")) == 0, "opus decode errors")
		assert(float(pb.call("get_chunk_max")) > 0.2, "decoded level %f" % float(pb.call("get_chunk_max")))
		V._speakers[77]["player"].queue_free(); V._speakers[77]["opus_player"].queue_free(); V._speakers.erase(77)
		V._tone = false
	var N = root.get_node("Net")
	N._mode = N.Mode.HOST
	N._players = {1: N._blank(1, "Host", 0), 2: N._blank(2, "A", 1), 3: N._blank(3, "B", 2), 4: N._blank(4, "C", 3)}
	for id in [1, 2, 3, 4]:
		N._players[id]["hidden"] = false
		N._players[id]["location"] = "town"
	N._players[4]["location"] = "cafe_interior"   # other room
	N._voice_pos = {1: Vector3.ZERO, 2: Vector3(5, 0, 0), 3: Vector3(17, 0, 0), 4: Vector3(1, 0, 0)}
	N._players[5] = N._blank(5, "D", 4)
	N._players[5]["hidden"] = false
	N._players[5]["location"] = "town"   # no pose yet: must not be heard
	var legacy := PackedByteArray(); legacy.resize(960)
	# 2 is 5 m from host -> host hears it; 3 is 17 m away (past VOICE_RANGE); 4 in another room
	N._relay_voice(2, legacy)
	N._relay_voice(3, legacy)
	N._relay_voice(4, legacy)
	N._relay_voice(5, legacy)
	assert(V._speakers.has(2) and not V._speakers.has(3) and not V._speakers.has(4) and not V._speakers.has(5), "room/distance filter")
	for k in 30:   # rate cap: 24000 B/s
		N._relay_voice(2, legacy)
	assert(int(N._voice_budget[2]["left"]) < 960, "rate cap")
	print("VOICE_TEST PASS codec=%s mulaw_max_err=%.4f opus_kbps=%.1f" % [V.codec, worst, kbps])
	N._mode = N.Mode.OFF
	quit()
