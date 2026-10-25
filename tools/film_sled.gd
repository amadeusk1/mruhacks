extends "res://tools/film_host.gd"

## Trailer shot: the five slide-look penguins race down Sled Hill, swinging side to side
## (tools/sled_pilot.gd steers the host and each follow bot). The first race starts as soon as the
## host arrives, before the bots, so this sits it out and films the next one with everyone on the
## line: FILM READY on its Go, FILM DONE when the host's run ends.
##   Godot --path . res://tools/film_sled.tscn -- --net-host --net-name=Host
## --bots=0 films the first race alone; --shots=DIR saves a frame every half second (framing checks).

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
	var pilot := preload("res://tools/sled_pilot.gd").new()
	pilot.period = 1.5
	add_child(pilot)
	while not _w.is_inside_tree() or not _w.get("_in_game") or _w.get("_traveling"):
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.0).timeout
	_w.call("travel_to", "sled_hill")
	while _w.call("current_location_id") != "sled_hill" or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	UIRouter.hide_ui()
	var room: Node = _w.get_node("LocationHost").get_child(0)
	var styler := Timer.new()
	styler.wait_time = 0.5
	styler.autostart = true
	styler.timeout.connect(_style_sleds.bind(room))
	add_child(styler)
	var sled: Node3D = room.get("sled")
	# wait for a start with every bot racing beside the host
	while true:
		while bool(sled.get("running")):
			await get_tree().physics_frame
		while not bool(sled.get("running")):
			await get_tree().physics_frame
		if (room.get("_ghosts") as Dictionary).size() >= _bots:
			break
		print("FILM skipping a race with %d bots" % (room.get("_ghosts") as Dictionary).size())
	print("FILM READY")
	if _shots != "":
		_shoot()
	while bool(sled.get("running")):
		await get_tree().physics_frame
	print("FILM DONE after %d m, crashed=%s" % [int(sled.get("distance")), sled.get("_crashed")])


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


func _shoot() -> void:
	for i in 24:
		get_viewport().get_texture().get_image().save_jpg("%s/sled_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
