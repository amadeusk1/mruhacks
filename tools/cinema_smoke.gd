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
	if part in ["screen", "pick", "offline", "viewer", "ambience", "idle", "theatre"]:  # feature flags on for this run only
		ProjectSettings.set_setting("pengloo/cinema/service_enabled", true)
		ProjectSettings.set_setting("pengloo/cinema/screen_video", part != "idle")
		ProjectSettings.set_setting("pengloo/cinema/ambience", part == "ambience")
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
		"ambience":
			_with_film(_ambience, CinemaService.client)
		"idle":
			_with_film(_idle, CinemaService.client)
		"default":
			_default()
		"theatre":
			_theatre()
		"viewer":
			_viewer()
		"layout":
			_layout()
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
		await get_tree().create_timer(10.0 if i == 0 else 3.0).timeout  # cold start: first chunk transcodes (~4-8 s)
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
		if i == 0:  # cold start: the first chunk transcodes (4-12 s depending on the media server)
			await _until(func() -> bool: return CinemaService.player.frames_shown > 0, 25.0)
		await get_tree().create_timer(6.0).timeout  # entering rebuilds the cinema + navmesh first
		var scr := room.find_child("CinemaScreen", true, false) as CinemaScreen
		var frames := CinemaService.player.frames_shown - before
		notes.append("%d:%d" % [i + 1, frames])
		var mat := scr.material_override as StandardMaterial3D if scr else null
		var qs := (scr.mesh as QuadMesh).size if scr else Vector2.ONE
		if i == 0:
			notes.append("quad=%.2fx%.2f(%.3f)" % [qs.x, qs.y, qs.x / qs.y])
		if mat and mat.albedo_texture and frames > 10 and absf(qs.x / qs.y - 16.0 / 9.0) < 0.02:
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
	await _until(func() -> bool: return CinemaService.player.texture != null, 25.0)  # cold first chunk
	await get_tree().create_timer(2.0).timeout
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


# ---- 5. camera + ambience: seated local penguin, film playing -> lights dim, spill tinted, camera pinned --
func _ambience(c: CinemaServiceClient) -> void:
	var amb := room.find_child("CinemaAmbience", true, false) as CinemaAmbience
	if amb == null:
		_finish(c, false, "no ambience node"); return
	var seat: SeatSpot = null
	for n in room.get_children():
		if n is SeatSpot and n.kit == "cinema":
			seat = n
			break
	var me := (load("res://scenes/penguin.tscn") as PackedScene).instantiate() as Node3D
	room.add_child(me)
	var rig := Node3D.new()  # same shape as world.tscn's follow rig: script + child Camera3D
	var lens := Camera3D.new()
	lens.name = "Camera3D"
	rig.add_child(lens)
	rig.set_script(load("res://scripts/follow_camera.gd"))
	rig.set("target_path", me.get_path())
	room.add_child(rig)
	await get_tree().process_frame
	me.call("sit_down", seat, seat.seat_point, seat.face_yaw, seat.seat_point + Vector3(0, 0, 1))
	await _until(func() -> bool: return CinemaService.player.playing and amb._pinned != null, 15.0)
	await get_tree().create_timer(3.0).timeout
	var dimmed := true
	for l in amb._lights:
		if is_instance_valid(l) and (l as OmniLight3D).light_energy > amb._lights[l] * 0.5:
			dimmed = false
	var spill: Color = amb._spill.light_color
	var tinted := amb._spill.light_energy > 0.5 and spill != Color.WHITE
	var pinned := amb._pinned != null
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cinema_smoke_ambience.png")
	c.control("pause", {}, func(_o: bool, _d: Variant) -> void: pass)
	await _until(func() -> bool: return not CinemaService.player.playing, 10.0)
	await get_tree().create_timer(2.0).timeout
	var restored := amb._pinned == null
	for l in amb._lights:
		if is_instance_valid(l) and absf((l as OmniLight3D).light_energy - amb._lights[l]) > 0.05:
			restored = false
	me.call("stand_up")
	_finish(c, dimmed and tinted and pinned and restored, "lights=%d dimmed=%s spill=%s pinned=%s restored_on_pause=%s" % [amb._lights.size(), dimmed, spill.to_html(false), pinned, restored])


# ---- download gate: no view open -> no chunk downloads; overlay open -> downloads; closed -> stop ------
func _idle(c: CinemaServiceClient) -> void:
	var count := {"n": 0}
	c.log_line.connect(func(t: String) -> void:
		if t.begins_with("/api/segment"):
			count["n"] += 1)
	await get_tree().create_timer(6.0).timeout
	var idle_fetches: int = count["n"]
	var o: Control = load("res://ui/activities/cinema/cinema_watch_overlay.gd").new()
	UIRouter.push(o)
	await get_tree().create_timer(6.0).timeout
	await _until(func() -> bool: return count["n"] > idle_fetches, 20.0)  # cold first chunk
	var open_fetches: int = count["n"] - idle_fetches
	var picture := CinemaService.player.texture != null
	o.call("close")
	await _until(func() -> bool: return CinemaService.player._loading.is_empty(), 25.0)  # in-flight chunks land
	await get_tree().create_timer(1.0).timeout
	var after_close: int = count["n"]
	await get_tree().create_timer(12.0).timeout  # crosses at least one chunk boundary
	var later: int = count["n"] - after_close
	_finish(c, idle_fetches == 0 and open_fetches > 0 and picture and later == 0,
		"idle=%d open=%d after_close=%d" % [idle_fetches, open_fetches, later])


# ---- default config (no PENGLOO_CINEMA_URL): production URL; unreachable/undeployed -> labelled Demo ------
func _default() -> void:
	var url_ok := CinemaService.service_url() == "https://pengloo.party/cinema/"
	Activities.request("cinema", room.find_child("CinemaLibraryKiosk", true, false), null)
	await _until(func() -> bool:
		var u: Control = UIRouter.top()
		return u != null and u.get("source") != null and str(u.get("source").status) in ["demo", "signed_out"], 20.0)
	var ui: Control = UIRouter.top()
	var st := str(ui.get("source").status) if ui and ui.get("source") else "none"
	if ui:
		ui.call("close")
	_done(url_ok and st in ["demo", "signed_out"], "url=%s status=%s" % [CinemaService.service_url(), st])


## Debug: hall landmarks (local to the hall) + a top-down shot.
func _layout() -> void:
	var hall := room.find_child("cinema_auditorium", true, false) as Node3D
	var root := hall.get_parent() as Node3D
	print("LAYOUT hall_root=", root.global_position, " screen=", root.to_local(Sockets.find(hall, "screen").global_position))
	var ex := Sockets.find(hall, "exit")
	print("LAYOUT exit=", root.to_local(ex.global_position) if ex else "none", " landing=", root.to_local((room.get_node("InsideScreen") as Node3D).global_position))
	var xs: Array = []
	var zs: Array = []
	for n in room.get_children():
		if n is SeatSpot and n.kit == "cinema":
			var l := root.to_local(n.seat_point)
			xs.append(l.x); zs.append(l.z)
	print("LAYOUT seats x ", xs.min(), "..", xs.max(), " z ", zs.min(), "..", zs.max())
	var pod := room.find_child("movie_kiosk*", true, false) as Node3D
	print("LAYOUT podium=", pod.get_path() if pod else "none", " at ", root.to_local(pod.global_position) if pod else Vector3.ZERO, " visible=", pod.is_visible_in_tree() if pod else false)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 16
	cam.global_position = root.global_position + Vector3(0, 20, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cinema_layout.png")
	_done(true)


# ---- in-theatre flow: podium + pill + idle card, sit -> pick -> play -> change movie -> F from the seat ------
func _theatre() -> void:
	var notes: Array = []
	var spot := room.find_child("CinemaPickMovie", true, false) as CinemaMovieSpot
	var screen := room.find_child("CinemaScreen", true, false) as CinemaScreen
	var podium := room.find_child("movie_kiosk*", true, false)
	if spot == null or screen == null or podium == null:
		_done(false, "missing spot=%s screen=%s podium=%s" % [spot != null, screen != null, podium != null]); return
	var me := (load("res://scenes/penguin.tscn") as PackedScene).instantiate() as Node3D
	room.add_child(me)
	me.global_position = (room.get_node("InsideScreen") as Node3D).global_position
	await get_tree().create_timer(1.0).timeout
	var card := screen.get_node("IdleCard") as Label3D
	notes.append("pill=%s '%s'" % [spot.can_interact(), spot.prompt_text()])
	notes.append("card=%s" % card.visible)
	var ok_idle := spot.can_interact() and spot.prompt_text() == "Sign in to cinema" and card.visible and card.text.begins_with("Movie night")
	var cam := Camera3D.new()  # view from the back of the hall: idle card + podium
	room.add_child(cam)
	var hall_root := spot.hall_root
	cam.global_position = hall_root.to_global(Vector3(1.5, 3.6, 6.4))
	cam.look_at(hall_root.to_global(Vector3(-2.0, 1.4, -2.0)))
	cam.fov = 70
	cam.current = true
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cinema_theatre_idle.png")
	# signed out: the pill opens the shared sign-in screen; sign in through it (as a player would)
	spot.interact(me)
	await get_tree().create_timer(0.5).timeout
	var modal: Control = UIRouter.top()
	var modal_ok: bool = modal != null and modal.get_script() == CinemaService.SIGN_IN and modal.find_child("*", true, false) != null
	var copy_ok := false
	for l in modal.find_children("*", "Label", true, false):
		if "host code to pick movies" in (l as Label).text:
			copy_ok = true
	(modal.get("_code") as LineEdit).text = code
	modal.call("_submit")
	await _until(func() -> bool: return CinemaService.client.signed_in, 15.0)
	await get_tree().create_timer(1.0).timeout
	var after_prompt := spot.prompt_text()
	var after_card := card.text
	notes.append("modal=%s copy=%s then pill='%s' card='%s'" % [modal_ok, copy_ok, after_prompt, after_card.get_slice("\n", 0)])
	ok_idle = ok_idle and modal_ok and copy_ok and after_prompt == "Pick a Movie" and after_card.begins_with("No movie playing")
	# sit in the middle of a row; the seat opens the cinema screen
	var seat: SeatSpot = null
	for n in room.get_children():
		if n is SeatSpot and n.kit == "cinema":
			seat = n
	me.call("sit_down", seat, seat.seat_point, seat.face_yaw, seat.seat_point + Vector3(0, 0, 1))
	Activities.request("cinema", seat, me)
	await get_tree().create_timer(1.0).timeout
	var ui: Control = UIRouter.top()
	var src = ui.get("source")
	var signin_shown: bool = src.status in ["connected", "empty"]  # already signed in: straight to the library
	await _until(func() -> bool: return not src.items.is_empty(), 15.0)
	var films: Array = src.items.filter(func(f: Dictionary) -> bool: return float(f.get("duration_s", 0)) > 3000)
	ui.set("_sel", films[0]["id"])
	ui.call("_build")
	_press(ui, "Play for Group")
	await _until(func() -> bool: return ui.get("mode") == "watch" and bool(src.snapshot.get("playing", false)), 30.0)
	var first := str(src.snapshot.get("media_id", ""))
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cinema_theatre_watch.png")
	var change_ok := _press(ui, "Change movie")
	await get_tree().process_frame
	var browsing: bool = ui.get("mode") == "library"
	ui.set("_sel", films[1]["id"])
	ui.call("_build")
	_press(ui, "Play for Group")
	await _until(func() -> bool: return ui.get("mode") == "watch" and str(src.snapshot.get("media_id", "")) == str(films[1]["id"]) and bool(src.snapshot.get("playing", false)), 30.0)
	var second := str(src.snapshot.get("media_id", ""))
	await get_tree().create_timer(2.0).timeout
	notes.append("films %s -> %s" % [first, second])
	ui.call("close")  # back in the seat, no UI: the pill offers Change Movie; F reopens the picker
	await get_tree().create_timer(1.0).timeout
	var seated_prompt := spot.prompt_text()
	var seated_pill := spot.can_interact() and bool(me.call("is_sitting"))
	spot.interact(me)
	await get_tree().create_timer(0.5).timeout
	var reopened: Control = UIRouter.top()
	var reopened_ok := reopened != null and reopened.get("source") is GatewaySource
	var card_hidden := not card.visible
	if reopened:
		reopened.call("close")
	notes.append("seated pill=%s '%s' reopened=%s card_hidden=%s" % [seated_pill, seated_prompt, reopened_ok, card_hidden])
	var ok: bool = ok_idle and signin_shown and first != "" and change_ok and browsing and second == str(films[1]["id"]) \
		and seated_pill and seated_prompt == "Change Movie" and reopened_ok and card_hidden
	await RenderingServer.frame_post_draw
	_finish(CinemaService.client, ok, "signin=%s change=%s browsing=%s | %s" % [signin_shown, change_ok, browsing, " | ".join(notes)])


func _press(ui: Control, text: String) -> bool:
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).text == text and not (b as Button).disabled:
			(b as Button).pressed.emit()
			return true
	return false
