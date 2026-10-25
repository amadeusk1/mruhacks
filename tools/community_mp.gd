extends Node
## Community-server e2e client (tools/community_mp.sh): joins PENGLOO_WS_URL (a lobby relay URL or
## the official server), walks, chats, and checks it sees the other client. Prints COMMUNITY_PASS/FAIL.
var role := "a"
var want := 2
var expect_full := false
var chats := 0
var poses := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
		elif a.begins_with("--want="):
			want = int(a.trim_prefix("--want="))
		elif a == "--expect-full":
			expect_full = true
		elif a.begins_with("--admin="):
			Net.admin_code = a.trim_prefix("--admin=")
	Net.chat_received.connect(func(speaker: String, msg: String) -> void:
		if msg.begins_with("probe") and speaker != "Comm" + role: chats += 1)
	Net.remote_pose.connect(func(_a, _b, _c, _d, _e, _f, _g) -> void: poses += 1)
	Net.join_full.connect(func(players: int, cap: int) -> void: _done(expect_full, "refused full %d/%d" % [players, cap]))
	get_tree().create_timer(60.0).timeout.connect(func() -> void: _done(false, "timeout"))
	var err := Net.join_game("Comm" + role)
	if err != "":
		_done(false, err)
		return
	await Net.session_started
	if expect_full:
		_done(false, "joined a full server")
		return
	Net.arrive("town", "BusArrival", false)
	var seen := 0
	for i in 12:
		seen = maxi(seen, Net.roster().size())  # the other client may finish and leave first
		Net.note_pose(Vector3(i, 0.3, 0), 0, 1, false)
		Net.say("probe from " + role)
		await get_tree().create_timer(1.0).timeout
	var others := Net.roster().filter(func(p) -> bool: return int(p.id) != Net.local_id())
	var ok := seen >= want and (want < 2 or (chats > 2 and poses > 0))
	_done(ok, "roster=%d (max %d) others=%d chats=%d poses=%d" % [Net.roster().size(), seen, others.size(), chats, poses])


var _finished := false


func _done(ok: bool, why: String) -> void:
	if _finished:
		return
	_finished = true
	print("COMMUNITY_%s %s %s" % ["PASS" if ok else "FAIL", role, why])
	Net.shutdown()
	get_tree().quit(0 if ok else 1)
