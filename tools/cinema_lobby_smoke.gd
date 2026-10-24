extends Node
## Integration harness: three actual game processes, live ENet roster, seats and WRY.
## Run with res://tools/cinema_lobby_smoke.tscn -- --net-host/--net-join --cinema-test=host/viewer/late.
var net: Node
var client: Node
var world: Node
var role := "host"
var view: Control
var observations := 0
var host_playing := false
var decoded := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cinema-test="):
			role = arg.trim_prefix("--cinema-test=")
	call_deferred("run_test")

func run_test() -> void:
	net = get_tree().root.get_node("Net")
	client = get_tree().root.get_node("CinemaClient")
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for i in range(600):
		await get_tree().create_timer(0.1).timeout
		if world.current_location_id() != "" and not world.is_traveling():
			break
	assert(net.is_online(), "No game lobby")
	if role == "late":
		await get_tree().create_timer(3).timeout
	await world.travel_to("cinema", "InsideScreen")
	await get_tree().create_timer(2).timeout
	var room: Node = world.get_node("LocationHost").get_child(0)
	var seats: Array = []
	for node in room.get_children():
		if node is SeatSpot and node.kit == "cinema":
			seats.append(node)
	assert(seats.size() >= 3, "Missing cinema seats")
	var seat: Node = seats[0 if role == "host" else (1 if role == "viewer" else 2)]
	var penguin: Node3D = world.get_node("Penguin")
	penguin.global_position = seat.seat_point
	assert(seat.interact(penguin), "Seat interaction rejected")
	for i in range(200):
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(client._overlay) and is_instance_valid(client._overlay._view):
			view = client._overlay._view
			break
	assert(is_instance_valid(view), "No authorized cinema webview")
	view.connect("ipc_message", observe)
	print("CINEMA_GAME ", role, " SEATED peer=", net.local_id(), " roster=", net.roster().size())
	await get_tree().create_timer(4).timeout
	if role == "host":
		view.call("eval", "(async()=>{for(let n=0;n<120;n++){const b=document.querySelector('[data-select]:not(:disabled)');if(b){b.click();break;}await new Promise(r=>setTimeout(r,500));}for(let n=0;n<120;n++){if(state?.media?.id){await command('play');window.ipc.postMessage(JSON.stringify({playingTest:true}));break;}await new Promise(r=>setTimeout(r,500));}})()")
		for i in range(120):
			if host_playing:
				break
			await get_tree().create_timer(0.5).timeout
		assert(host_playing, "Host could not select and play a film")
	for tick in range(42):
		if not is_instance_valid(view):
			break
		view.call("eval", "window.ipc.postMessage(JSON.stringify({test:true,time:video.currentTime,width:video.videoWidth,paused:video.paused,loginVisible:!document.getElementById('login').hidden,viewerCount:state?.viewers,remote:state?.controller===me?.id,seekDisabled:document.getElementById('seek').disabled,seeking:video.seeking,ready:video.readyState,now:Date.now(),status:document.getElementById('status').textContent}))")
		if role == "host" and tick == 21:
			view.call("eval", "command('seek',{position:300})")
		if role == "host" and tick == 32:
			view.call("eval", "command('pause')")
		await get_tree().create_timer(1).timeout
	if role == "viewer":
		client._overlay.close()
		await get_tree().process_frame
		assert(not penguin.is_sitting(), "Return did not release seat")
		assert(not is_instance_valid(client._overlay), "Return retained overlay")
		print("CINEMA_GAME viewer RETURN_AND_SEAT_RELEASE_PASS")
	elif role == "late":
		await world.travel_to("plaza")
		await get_tree().create_timer(2).timeout
		assert(not is_instance_valid(client._overlay), "Travel retained cinema")
		print("CINEMA_GAME late TRAVEL_REVOKES_PASS")
	else:
		await get_tree().create_timer(60).timeout
	net.shutdown()
	get_tree().quit(0 if decoded else 1)

func observe(message: String) -> void:
	var data: Variant = JSON.parse_string(message)
	if data is Dictionary and data.get("playingTest", false):
		host_playing = true
	if data is Dictionary and data.get("test", false):
		decoded = decoded or int(data.get("width", 0)) > 0
		observations += 1
		print("CINEMA_GAME ", role, " ", message)
