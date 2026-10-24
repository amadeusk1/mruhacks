extends Node
## Cinema port smoke tests (one per ported piece; see Engine Specs/Cinema Sandbox Log).
##   Godot --path . res://tools/cinema_smoke.tscn -- --part=client
## Needs the gateway (services/cinema) on PENGLOO_CINEMA_URL and the host invite code in
## PENGLOO_CINEMA_TEST_CODE (set from the shell at run time; never stored).
## Prints CINEMA_SMOKE <part> PASS|FAIL and quits.

var part := "client"
var url := ""
var code := ""
var room: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.get_slice("=", 1)
	url = OS.get_environment("PENGLOO_CINEMA_URL")
	code = OS.get_environment("PENGLOO_CINEMA_TEST_CODE")
	if part in ["screen", "pick", "offline", "viewer"]:  # feature flags on for this run only
		ProjectSettings.set_setting("pengloo/cinema/service_enabled", true)
		ProjectSettings.set_setting("pengloo/cinema/screen_video", true)
	room = (load("res://scenes/locations/cinema.tscn") as PackedScene).instantiate() as Node3D
	add_child(room)  # enter the cinema
	await get_tree().process_frame
	match part:
		"client":
			_client()
		"overlay":
			_with_film(_overlay, CinemaService.client)
		"screen":
			_with_film(_screen, CinemaService.client)
		"pick":
			_pick()
		"offline":
			_offline()
		"viewer":
			_viewer()
		"room":  # baseline: just enter and leave the cinema
			_done(true)
		_:
			_done(false, "unknown part")


func _done(ok: bool, why := "") -> void:
	print("CINEMA_SMOKE ", part, " ", "PASS" if ok else "FAIL", " ", why)
	room.queue_free()  # leave the cinema
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


# ---- 1. service client --------------------------------------------------------------------
func _client() -> void:
	var c := CinemaServiceClient.new()
	add_child(c)
	c.set_service("http://127.0.0.1:1/cinema/")
	c.health(func(dead_up: bool) -> void:
		if dead_up:
			_done(false, "dead service reported up"); return
		c.set_service(url)
		c.health(func(up: bool) -> void:
			if not up:
				_done(false, "service down at " + url); return
			c.login("Smoke", code, func(ok: bool, err: String) -> void:
				if not ok:
					_done(false, "login: " + err); return
				c.library("", func(films: Variant) -> void:
					c.state(func(st: Variant) -> void:
						var n: int = (films as Array).size() if films is Array else 0
						c.logout(func() -> void:
							_done(n > 0 and st is Dictionary and not c.signed_in, "films=%d state=%s" % [n, st is Dictionary])))))))


## Signs in as host, starts the longest film, then calls body(client). Ends paused + signed out.
func _with_film(body: Callable, shared: CinemaServiceClient = null) -> void:
	var c := shared if shared else CinemaServiceClient.new()
	if shared == null:
		add_child(c)
	c.log_line.connect(func(t: String) -> void: print("HTTP %.1f %s" % [Time.get_ticks_msec() / 1000.0, t]))
	c.set_service(url)
	c.login("Smoke", code, func(ok: bool, err: String) -> void:
		if not ok:
			_done(false, "login: " + err); return
		c.library("", func(films: Variant) -> void:
			var film := {}
			for f in (films if films is Array else []):
				if float(f.get("duration", 0)) > 3000:
					film = f
					break
			if film.is_empty():
				_done(false, "no film"); return
			c.claim(func(_claimed: bool) -> void:
				c.control("load", {"id": film["id"]}, func(loaded: bool, _d: Variant) -> void:
					c.control("play", {}, func(playing: bool, _d2: Variant) -> void:
						if not (loaded and playing):
							_done(false, "host could not start the film"); return
						# past the opening titles, so a screenshot shows picture
						c.control("seek", {"position": 600.0}, func(_o: bool, _d3: Variant) -> void: body.call(c)))))))


func _finish(c: CinemaServiceClient, ok: bool, why: String) -> void:
	c.control("pause", {}, func(_o: bool, _d: Variant) -> void:
		c.logout(func() -> void: _done(ok, why)))


# ---- 2. watch overlay ---------------------------------------------------------------------
func _overlay(c: CinemaServiceClient) -> void:
	var good := 0
	var notes: Array = []
	for i in 5:
		var o: Control = load("res://ui/activities/cinema/cinema_watch_overlay.gd").new()
		UIRouter.push(o)
		var before := CinemaService.player.frames_shown
		await get_tree().create_timer(6.0 if i == 0 else 3.0).timeout  # first open waits for the first chunk
		var p: CinemaScreenPlayer = o.get("player")
		var pic := (o.get("_picture") as TextureRect).texture
		var shown := p.frames_shown - before
		notes.append("%d:%d" % [i + 1, shown])
		if pic != null and shown > 10 and p.playing:
			good += 1
		print("OPEN %d %.1f frames=%d" % [i + 1, Time.get_ticks_msec() / 1000.0, p.frames_shown])
		o.call("close")
		await get_tree().process_frame
	_finish(c, good == 5, "opens with picture %d/5 frames %s" % [good, " ".join(notes)])


# ---- 3. video on the auditorium screen ------------------------------------------------------
func _screen(c: CinemaServiceClient) -> void:
	var notes: Array = []
	var good := 0
	for i in 5:  # enter the cinema, watch the big screen, leave; five times
		if i > 0:
			room.queue_free()
			await get_tree().process_frame
			room = (load("res://scenes/locations/cinema.tscn") as PackedScene).instantiate() as Node3D
			add_child(room)
		var before := CinemaService.player.frames_shown
		await get_tree().create_timer(6.0).timeout  # entering rebuilds the cinema + navmesh first
		var scr := room.find_child("CinemaScreen", true, false) as CinemaScreen
		var frames := CinemaService.player.frames_shown - before
		notes.append("%d:%d" % [i + 1, frames])
		var mat := scr.material_override as StandardMaterial3D if scr else null
		if mat and mat.albedo_texture and frames > 10:
			good += 1
		if i == 0 and scr:
			var hall := scr.hall
			var screen := Sockets.find(hall, "screen")
			var cam := Camera3D.new()
			room.add_child(cam)
			var marker := room.get_node_or_null("InsideScreen") as Node3D  # where players land in the hall
			cam.global_position = (marker.global_position if marker else hall.global_position) + Vector3(0, 2.2, 1.5)
			cam.look_at(screen.global_position)
			cam.fov = 60
			cam.current = true
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/cinema_smoke_screen.png")
	_finish(c, good == 5, "screen with picture %d/5 frames %s" % [good, " ".join(notes)])


# ---- 4. host-pick UI + sync (the real kiosk -> ActivityScreens -> cinema_ui with GatewaySource) ------
func _pick() -> void:
	var kiosk := room.find_child("CinemaLibraryKiosk", true, false)
	Activities.request("cinema", kiosk, null)
	await get_tree().create_timer(1.0).timeout
	var ui: Control = UIRouter.top()
	var src = ui.get("source") if ui else null
	if not src is GatewaySource or src.status != "signed_out":
		_done(false, "kiosk did not open the gateway sign-in (%s)" % (src.status if src else "no ui")); return
	src.sign_in(code)
	await _until(func() -> bool: return not src.items.is_empty(), 15.0)
	var film := {}
	for f in src.items:
		if float(f.get("duration_s", 0)) > 3000:
			film = f
	if film.is_empty():
		film = src.items[0]
	ui.set("_sel", film["id"])
	ui.call("_build")
	var play: Button = null
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).text == "Play for Group":
			play = b
	if play == null or play.disabled:
		_done(false, "Play for Group missing or disabled (controller=%s)" % src.is_controller(str(Net.local_id()))); return
	play.pressed.emit()  # the host picks the film for everyone
	await _until(func() -> bool: return ui.get("mode") == "watch" and bool(src.snapshot.get("playing", false)), 30.0)
	var watching: bool = ui.get("mode") == "watch"
	await get_tree().create_timer(6.0).timeout
	var live := ui.find_child("Live", true, false) as TextureRect
	var picture := live != null and live.texture != null
	if OS.has_environment("PICK_HOLD"):  # run_sync: keep playing so a viewer instance can follow
		await get_tree().create_timer(float(OS.get_environment("PICK_HOLD"))).timeout
	src.request_pause()
	await _until(func() -> bool: return not bool(src.snapshot.get("playing", true)), 10.0)
	var paused := not bool(src.snapshot.get("playing", true))
	ui.call("close")
	await get_tree().process_frame
	CinemaService.client.logout(func() -> void:
		_done(watching and picture and paused, "film=%s watch=%s picture=%s paused_followed=%s" % [film["title"], watching, picture, paused]))


func _until(cond: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + seconds * 1000.0
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.25).timeout


# ---- 4b. service down: the cinema UI falls back to the labelled Demo library ------------------------
func _offline() -> void:
	CinemaService.client.set_service("http://127.0.0.1:1/cinema/")
	Activities.request("cinema", room.find_child("CinemaLibraryKiosk", true, false), null)
	await get_tree().create_timer(2.0).timeout
	var ui: Control = UIRouter.top()
	var src = ui.get("source") if ui else null
	var ok: bool = src is CinemaSource.DemoSource and src.status == "demo" and not src.items.is_empty()
	if ui:
		ui.call("close")
	_done(ok, "fell back to %s" % (src.status if src else "nothing"))


# ---- 4c. viewer instance: follows a host instance (tools/cinema_sync.sh runs both) ---------------
func _viewer() -> void:
	Activities.request("cinema", room.find_child("CinemaLibraryKiosk", true, false), null)
	await get_tree().create_timer(1.0).timeout
	var ui: Control = UIRouter.top()
	var src = ui.get("source")
	src.sign_in(code)
	await _until(func() -> bool: return ui.get("mode") == "watch" and bool(src.snapshot.get("playing", false)), 40.0)
	var follows: bool = ui.get("mode") == "watch"
	var guest: bool = not src.is_controller(str(Net.local_id()))
	var play_disabled := true
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text == "Play/Pause":
			play_disabled = (b as Button).disabled
	await get_tree().create_timer(5.0).timeout
	var p := CinemaService.player
	var got := {"err": 99.0}  # lambdas capture locals by value; mutate a dictionary instead
	CinemaService.client.state(func(st: Variant) -> void:
		if st is Dictionary:
			var srv := float(st.get("position", 0.0)) + (float(st.get("serverNow", 0)) - float(st.get("updatedAt", 0))) / 1000.0
			got["err"] = absf(p.position() - srv) if bool(st.get("playing", false)) else 0.0)
	await get_tree().create_timer(1.0).timeout
	var err: float = got["err"]
	var picture := p.texture != null and p.frames_shown > 30
	await _until(func() -> bool: return not bool(src.snapshot.get("playing", true)), 30.0)  # host pauses
	var paused := not bool(src.snapshot.get("playing", true))
	ui.call("close")
	CinemaService.client.logout(func() -> void:
		_done(follows and guest and play_disabled and picture and err < 0.5 and paused,
			"watch=%s guest=%s controls_locked=%s picture=%s sync_err=%.2fs followed_pause=%s" % [follows, guest, play_disabled, picture, err, paused]))
