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
	if part == "screen":  # feature flags on for this run only
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
