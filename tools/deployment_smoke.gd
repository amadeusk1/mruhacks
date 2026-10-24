extends Node
var role := "a"
var chats := 0
var poses := 0
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-role="):
			role = arg.trim_prefix("--test-role=")
	Net.chat_received.connect(func(_n, _m): chats += 1)
	Net.remote_pose.connect(func(_a,_b,_c,_d,_e,_f,_g): poses += 1)
	assert(Net.join_game("DeployTest" + role) == "")
	await Net.session_started
	Net.arrive("town", "BusArrival", false)
	for i in range(8):
		Net.note_pose(Vector3(i, 0.3, 0), 0, 1, false)
		Net.say("Deployment probe " + role)
		await get_tree().create_timer(1).timeout
	assert(Net.roster().size() >= 2, "Both clients not in shared roster")
	assert(chats > 2, "Chat relay failed")
	assert(poses > 0, "Movement relay failed")
	if role == "a":
		assert(Net.claim_bench("town:deployment-test-seat"))
		await get_tree().create_timer(3).timeout
		Net.release_bench()
	else:
		await get_tree().create_timer(1).timeout
		assert(Net.bench_held_by_other("town:deployment-test-seat"), "Seat ownership not shared")
	await get_tree().create_timer(3).timeout
	assert(not Net.bench_held_by_other("town:deployment-test-seat"), "Seat release not shared")
	Net.arrive("cinema", "InsideLobby", false)
	await get_tree().create_timer(1).timeout
	var found := false
	for p in Net.roster():
		if int(p.id) == Net.local_id():
			found = p.location == "cinema"
	assert(found, "Room change not replicated")
	print("DEPLOYMENT_PASS ", role, " peers=", Net.roster().size(), " chats=", chats, " poses=", poses)
	Net.shutdown()
	await get_tree().create_timer(1).timeout
	get_tree().quit()
