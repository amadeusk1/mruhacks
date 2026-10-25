extends "res://tools/film_host.gd"

## Trailer shot: the five slide-look penguins sitting together in the cinema auditorium. The host
## takes the seat nearest the hall's middle (tools/seat_pilot.gd); follow bots arrive and sit beside
## it. The screen stays off (the film needs the cinema service), so the camera sits on the screen
## side and looks back at the audience. FILM READY once four bots are seated, FILM DONE later.
##   Godot --path . res://tools/film_cinema.tscn -- --net-host --net-name=Host
## --bots=0 runs alone; --shots=DIR saves a frame every half second (framing checks).
## --film=QUERY plays the first library match on the screen (cinema service at PENGLOO_CINEMA_URL,
## host code from ~/.config/pengloo/cinema.env) from --seek=SECONDS, and films from behind the
## audience toward the screen instead.

const CAM_HEIGHT := 4.6
const CAM_DISTANCE := 4.2  # the screen wall is ~5.5 m in front of the middle seats
const UI_ZOOM := 1.3  # --ui: back off and slide the audience clear of the chat box, buttons and name labels
const UI_SHIFT := Vector3(0.8, 0.0, -0.2)  # world offset of the focus: +x is screen left here, -z is down the hall toward the camera
const LENGTH := 10.0
const POV_BACK := 4.5      # --film: camera metres behind the host
const POV_HEIGHT := 3.9    # above the floor: the screen clears the heads, which sit along the bottom
const ENV_FILE := "/.config/pengloo/cinema.env"

var _bots := 4
var _shots := ""
var _film := ""
var _seek := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bots="):
			_bots = int(a.trim_prefix("--bots="))
		elif a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
		elif a.begins_with("--film="):
			_film = a.trim_prefix("--film=")
		elif a.begins_with("--seek="):
			_seek = float(a.trim_prefix("--seek="))
	super._ready()
	while not _w.is_inside_tree() or not _w.get("_in_game") or _w.get("_traveling"):
		await get_tree().create_timer(0.5).timeout
	while _bots_here() < _bots:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.0).timeout
	_w.call("travel_to", "cinema", "InsideScreen")
	while _w.call("current_location_id") != "cinema" or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var room: Node = _w.get_node("LocationHost").get_child(0)
	var hall: Vector3 = room.get_meta("hall_center", Vector3(240, 0, 50))
	var me: CharacterBody3D = _w.get_node("Penguin")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var pilot := preload("res://tools/seat_pilot.gd").new()
	pilot.near = hall
	pilot.active = true
	add_child(pilot)
	while not bool(me.call("is_sitting")):
		await get_tree().create_timer(0.3).timeout
	var screen := Sockets.find(room.find_child("cinema_auditorium", true, false), "screen")
	var rig: Node3D = _w.get("_camera_rig")
	if _film != "":
		await _play_film()
		# from behind the audience: the focus sits toward the screen, the camera behind the host
		var ahead := Vector3(screen.global_position.x - me.global_position.x, 0.0, screen.global_position.z - me.global_position.z)
		rig.rotation.y = atan2(-ahead.x, -ahead.z)  # the rig's camera sits on its +Z side
		var focus := me.global_position + ahead * 0.5
		rig.call("pin_focus", Vector3(focus.x, me.global_position.y, focus.z), POV_HEIGHT, ahead.length() * 0.5 + POV_BACK, screen.global_position.y)  # a pinned focus aims from the floor
	else:
		# look back at the audience from the screen's side
		if screen != null and screen.global_position.z < me.global_position.z:
			rig.rotation.y = PI
		if _keep_ui:
			rig.call("pin_focus", me.global_position + UI_SHIFT, CAM_HEIGHT * UI_ZOOM, CAM_DISTANCE * UI_ZOOM, 0.6)
		else:
			rig.call("pin_focus", me.global_position, CAM_HEIGHT, CAM_DISTANCE, 0.6)
	if not _keep_ui:
		UIRouter.hide_ui()
	print("FILM host seated at %s, screen at %s" % [me.global_position, screen.global_position if screen else "?"])
	if _shots != "":
		_shoot()
	while _seated_bots() < _bots:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.5).timeout
	print("FILM READY")
	for i in 4:
		await get_tree().create_timer(LENGTH / 4.0).timeout
		print("FILM cinema frames shown: %d at %.0f s" % [CinemaService.player.frames_shown, CinemaService.player.position()])
	print("FILM DONE")


## Signs in with the host code, loads the film, seeks to the scene, and waits for its first frames.
func _play_film() -> void:
	var home := OS.get_environment("USERPROFILE") if OS.get_environment("HOME") == "" else OS.get_environment("HOME")
	var code := ""
	for line in FileAccess.get_file_as_string(home + ENV_FILE).split("
"):
		if line.begins_with("CINEMA_HOST_CODE="):
			code = line.trim_prefix("CINEMA_HOST_CODE=").strip_edges()
	var step := [false, null]
	var client: CinemaServiceClient = CinemaService.client
	client.log_line.connect(func(line: String) -> void:
		if line.begins_with("/api/segment"):
			print("FILM cinema %s" % line))
	CinemaService.sign_in(code, func(ok: bool, err: String) -> void:
		step[1] = ok if ok else err
		step[0] = true)
	while not step[0]:
		await get_tree().process_frame
	print("FILM cinema sign-in: %s" % step[1])
	step[0] = false
	client.library(_film, func(films: Variant) -> void:
		step[1] = films
		step[0] = true)
	while not step[0]:
		await get_tree().process_frame
	var film: Dictionary = (step[1] as Array)[0]
	print("FILM playing %s" % film.get("title", "?"))
	step[0] = false
	client.claim(func(_c: bool) -> void:
		client.control("load", {"id": str(film["id"])}, func(_ok: bool, _d: Variant) -> void:
			client.control("play", {}, func(_ok2: bool, _d2: Variant) -> void:
				client.control("seek", {"position": _seek}, func(ok3: bool, d3: Variant) -> void:
					print("FILM cinema seek %s: %s" % [ok3, d3.get("error", "") if d3 is Dictionary else d3])
					step[0] = true))))
	while not step[0]:
		await get_tree().process_frame
	# Each 10 s chunk is transcoded on request, and with the game and the recorder on the same machine
	# that takes longer than 10 s: the playhead outruns the downloads and the screen stays dark. So
	# hold the playhead on the first chunk (seeking back to it) until it and the next are in memory,
	# then start from it: 20 s of film play without waiting on the gateway.
	var first := int(_seek / CinemaScreenPlayer.SEG)
	var segs: Dictionary = CinemaService.player.get("_segs")
	var left := 120.0
	while left > 0.0 and not (_has_frames(segs, first) and _has_frames(segs, first + 1)):
		await _control("seek", {"position": first * CinemaScreenPlayer.SEG})
		await get_tree().create_timer(5.0).timeout
		left -= 5.0
	await _control("seek", {"position": first * CinemaScreenPlayer.SEG})
	await get_tree().create_timer(1.0).timeout
	print("FILM cinema frames shown: %d at %.0f s" % [CinemaService.player.frames_shown, CinemaService.player.position()])


func _has_frames(segs: Dictionary, i: int) -> bool:
	return segs.has(i) and (segs[i] as Dictionary).has("frames")


func _control(action: String, extra: Dictionary) -> void:
	var done := [false]
	CinemaService.client.control(action, extra, func(_ok: bool, _d: Variant) -> void: done[0] = true)
	while not done[0]:
		await get_tree().process_frame


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _seated_bots() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible and puppet.has_method("is_sitting") and bool(puppet.call("is_sitting")):
			n += 1
	return n


func _shoot() -> void:
	for i in 24:
		get_viewport().get_texture().get_image().save_jpg("%s/cine_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
