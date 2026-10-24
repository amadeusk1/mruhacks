extends Node3D
## In-world cinema screenshot harness: the real cinema location, four seated penguins with
## popcorn, a Demo movie night in CinemaSession and the seated HUD.
##   Godot --path . res://tools/cinema_preview.tscn -- --view=seats|iso --out=/abs.png [--kiosk]
## Live gateway check (browse, select, play, pause, seek against services/cinema):
##   PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/ PENGLOO_CINEMA_TEST_CODE=<host code from the
##   shell, never committed> Godot ... -- --emby --out=/abs/prefix

const LOOKS := [
	{"name": "Snowdrop", "look": {"color": 0, "head": "red_beanie", "torso": "hoodie"}},
	{"name": "Pebble", "look": {"color": 1, "head": "frog_hood"}},
	{"name": "Waddles", "look": {"color": 2, "head": "explorer_hat"}},
	{"name": "Juniper", "look": {"color": 3, "head": "wizard_hat", "torso": "wizard_robe"}},
]


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		else:
			args[a.trim_prefix("--")] = true
	get_window().size = Vector2i(1280, 720)
	if args.has("emby"):
		await _emby_check(str(args.get("out", "user://emby")))
		get_tree().quit()
		return
	var room := (load("res://scenes/locations/cinema.tscn") as PackedScene).instantiate() as Node3D
	add_child(room)
	for i in 3:
		await get_tree().process_frame
	var hall := room.find_child("cinema_auditorium", true, false) as Node3D
	var seats: Array = room.get_children().filter(func(n: Node) -> bool: return n is SeatSpot and n.kit == "cinema")
	seats.sort_custom(func(a: SeatSpot, b: SeatSpot) -> bool:
		return a.seat_point.z < b.seat_point.z - 0.2 or (absf(a.seat_point.z - b.seat_point.z) <= 0.2 and a.seat_point.x < b.seat_point.x))
	var row: Array = seats.slice(0, 4) if seats.size() >= 4 else seats
	if seats.size() > 8:   # middle row, like the mockups
		var mid := seats.filter(func(s: SeatSpot) -> bool: return absf(s.seat_point.z - seats[seats.size() / 2].seat_point.z) < 0.2)
		row = mid.slice(0, 4)
	print("PREVIEW seats=", seats.size(), " row=", row.size())
	var birds: Array = []
	for i in row.size():
		var p := (load("res://scenes/penguin.tscn") as PackedScene).instantiate()
		add_child(p)
		await get_tree().process_frame
		Outfit.dress(p.get_node("Visual").get_node_or_null("PackAvatar") as Node3D, Outfit.DEFAULT.merged(LOOKS[i]["look"], true))
		p.call("apply_identity", LOOKS[i]["name"], int(LOOKS[i]["look"]["color"]))
		var s: SeatSpot = row[i]
		p.call("sit_down", s, s.seat_point, s.face_yaw, s.seat_point + Vector3(0, 0, 1))
		p.call("set_seat_clip", "cinema")
		p.call("hold_prop", "interaction_props/popcorn_tub")
		birds.append(p)
	var screen := Sockets.find(hall, "screen") if hall else null
	var aim := screen.global_position if screen else (hall.global_position if hall else Vector3.ZERO)
	var cam := Camera3D.new()
	add_child(cam)
	var mid_seat: Vector3 = row[1].seat_point if row.size() > 1 else aim + Vector3(0, 0, 4)
	if str(args.get("view", "seats")) == "iso":
		cam.fov = 50
		cam.global_position = mid_seat + Vector3(-4.6, 5.6, 5.4)
		cam.look_at(mid_seat + (aim - mid_seat) * 0.45 + Vector3(0, 0.6, 0))
	else:
		cam.fov = 58
		cam.global_position = mid_seat + Vector3(-1.1, 1.75, 2.9)
		cam.look_at(aim + Vector3(0.6, 0.2, 0))
	cam.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#0E1A2B")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8C7A6A")
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	# Demo movie night: Snowdrop hosts Moonbound, four friends seated.
	var s := CinemaSession
	s.use_demo()
	s.host_id = Net.local_id()
	for i in row.size():
		s._watching(100 + i if i > 0 else Net.local_id(), LOOKS[i]["name"], true)
	s._picked(s.source.items[0], "Snowdrop")
	s._playback(s.source.items[0], true, 2852.0)
	if birds.is_empty():
		push_warning("no cinema seats found")
	else:
		s._open_hud(row[0], birds[0])
	if args.has("kiosk"):
		s.open_kiosk()
	await get_tree().create_timer(0.6).timeout
	if birds.size() > 3:
		Net.chat_received.emit("Snowdrop", "Here we go!")
		Net.chat_received.emit("Juniper", "Saved you a seat")
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := str(args.get("out", "user://cinema.png"))
	get_viewport().get_texture().get_image().save_png(out)
	print("SAVED ", out)
	get_tree().quit()


func _emby_check(prefix: String) -> void:
	var s := CinemaSession
	var src := s.ensure_source()
	var kiosk := s.open_kiosk()
	while src.status == "connecting":
		await get_tree().process_frame
	print("EMBY status=", src.status, " ", src.detail)
	await _shot(prefix + "_signin.png")
	src.sign_in("Snowdrop", OS.get_environment("PENGLOO_CINEMA_TEST_CODE"))
	await src.catalog_changed
	print("EMBY browse items=", src.items.size(), " can_host=", src.can_host())
	await get_tree().create_timer(6.0).timeout   # posters stream in
	await _shot(prefix + "_browse.png")
	src.search("jump")
	await src.catalog_changed
	print("EMBY search 'jump' -> ", src.items.map(func(t: Dictionary) -> String: return t["title"]))
	await get_tree().create_timer(2.0).timeout
	await _shot(prefix + "_search.png")
	var film: Dictionary = src.items[0]
	s.start_movie(film)
	await _until(func() -> bool: return bool(src.snapshot.get("playing", false)), 40.0)
	print("EMBY play media=", src.snapshot.get("media_id"), " playing=", src.snapshot.get("playing"), " session film=", s.film.get("title"), " host=", s.is_host())
	await get_tree().create_timer(3.0).timeout
	s.set_playing(false)
	await _until(func() -> bool: return not bool(src.snapshot.get("playing", true)), 10.0)
	print("EMBY pause playing=", src.snapshot.get("playing"), " pos=", snappedf(src.position_now(), 0.1), " session playing=", s.playing)
	s.seek(600.0)
	await _until(func() -> bool: return absf(src.position_now() - 600.0) < 2.0, 10.0)
	print("EMBY seek pos=", snappedf(src.position_now(), 0.1), " session pos=", snappedf(s.position_now(), 0.1))
	s.set_playing(true)
	await _until(func() -> bool: return bool(src.snapshot.get("playing", false)), 10.0)
	print("EMBY resume playing=", src.snapshot.get("playing"))
	var url: String = await src.closeup_url()
	print("EMBY closeup ticket ok=", url.contains("embed=1&ticket="))
	if is_instance_valid(kiosk):
		kiosk.queue_free()
	var hud: Control = load("res://ui/activities/cinema/cinema_hud.gd").new()
	UIRouter.push(hud)
	await get_tree().create_timer(1.0).timeout
	await _shot(prefix + "_hud.png")
	s.set_playing(false)
	await get_tree().create_timer(1.5).timeout
	printerr("EMBY done")


func _until(cond: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + seconds * 1000.0
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.25).timeout


func _shot(out: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SAVED ", out)
