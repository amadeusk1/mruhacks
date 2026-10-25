extends "res://tools/film_host.gd"

## Trailer shot: the five slide-look penguins race each other down Sled Hill (tools/sled_pilot.gd
## rides the host and each follow bot). Everyone joins the race lobby from the start card; once all
## five are in, the host presses Start now. FILM READY as the start lights count down, FILM DONE
## when the host crosses the finish. --ui keeps the race HUD (placings, timer, next checkpoint).
##   Godot --path . res://tools/film_sled.tscn -- --net-host --net-name=Host --ui
## --bots=0 rides a time trial alone; --shots=DIR saves a frame every half second (framing checks).

const RENDER_SCALE := 0.75  # sledding is fast; a steady frame rate matters more than full res

var _bots := 4
var _shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bots="):
			_bots = int(a.trim_prefix("--bots="))
		elif a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	super._ready()
	get_viewport().scaling_3d_scale = RENDER_SCALE
	while not _w.is_inside_tree() or not _w.get("_in_game") or _w.get("_traveling"):
		await get_tree().create_timer(0.5).timeout
	while _bots_here() < _bots:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.0).timeout
	_w.call("travel_to", "sled_hill")
	while _w.call("current_location_id") != "sled_hill" or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	if not _keep_ui:
		UIRouter.hide_ui()
	var room: Node = _w.get_node("LocationHost").get_child(0)
	var styler := Timer.new()
	styler.wait_time = 0.5
	styler.autostart = true
	styler.timeout.connect(_style_sleds.bind(room))
	add_child(styler)
	if _bots == 0:
		SledRace.time_trial()
	else:
		var pilot := preload("res://tools/sled_pilot.gd").new()
		pilot.period = 1.5
		add_child(pilot)
		while ((room.get("_view") as Dictionary).get("lobby", []) as Array).size() < _bots + 1:
			await get_tree().create_timer(0.3).timeout
		await get_tree().create_timer(1.5).timeout  # the lobby card, everyone listed
		SledRace.start_now()
	if _bots == 0:
		add_child(preload("res://tools/sled_pilot.gd").new())  # steers only; trials need no lobby
	while str(room.get("_state")) != "countdown":
		await get_tree().physics_frame
	print("FILM READY")
	if _shots != "":
		_shoot()
	var sled: Node3D = room.get("sled")
	while str(room.get("_state")) in ["countdown", "running"]:
		await get_tree().physics_frame
	print("FILM DONE after %d m" % int(sled.get("course_s")))


## Sleds carry their own bird, so dress those like film_host dresses the walking penguins.
func _style_sleds(room: Node) -> void:
	_style(room.get("sled"), "Host")
	var names := {}
	for e in Net.roster():
		names[int(e.get("id", 0))] = str(e.get("name", ""))
	var ghosts: Dictionary = room.get("_ghosts")
	for id in ghosts:
		if is_instance_valid(ghosts[id]):
			_style(ghosts[id], names.get(int(id), ""))


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _shoot() -> void:
	for i in 40:
		get_viewport().get_texture().get_image().save_jpg("%s/sled_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
