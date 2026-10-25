extends "res://tools/film_host.gd"

## Trailer shot: the five slide-look penguins stand together in the plaza, then walk east past
## the dance floor and over the bridge while the four follow bots keep pace. Hosts like
## film_host, waits for the bots, hides the UI, then prints FILM READY (tools/film_shot.sh
## starts recording on it) and FILM DONE when the route ends.
##   Godot --path . res://tools/film_walk.tscn -- --net-host --net-name=Host --tod=0.70
## --bots=0 runs without waiting for bots; --shots=DIR saves a frame every second (framing checks).

const HOLD := 2.0  # seconds standing still before the walk: the trailer's landing moment
const START := Vector3(2.2, 0, 5.2)  # the plaza's bus stop
const ROUTE := [Vector3(8.5, 0, 4.5), Vector3(15.0, 0, 0.5)]  # side-on to the camera: faces show, no trees in front
const ARRIVE := 0.6
const CAM_HEIGHT := 6.0  # closer and lower than the town's overview camera
const CAM_DISTANCE := 7.0

var _bots := 4
var _shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bots="):
			_bots = int(a.trim_prefix("--bots="))
		elif a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	super._ready()
	while not _w.is_inside_tree() or not _w.get("_in_game") or _w.get("_traveling"):
		await get_tree().create_timer(0.5).timeout
	var me: CharacterBody3D = _w.get_node("Penguin")
	print("FILM host at %s in %s" % [me.global_position, _w.call("current_location_id")])
	me.global_position = START + Vector3(0, 0.1, 0)
	me.call("halt")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var rig: Node3D = _w.get("_camera_rig")
	rig.global_position = me.global_position  # set_frame aims once, from where the rig is now
	rig.call("set_frame", Vector3.ZERO, 100.0, 100.0, CAM_HEIGHT, CAM_DISTANCE)
	while _bots_here() < _bots:
		await get_tree().create_timer(0.5).timeout
	if not _keep_ui:
		UIRouter.hide_ui()
	await get_tree().create_timer(5.0).timeout  # bots walk to their places beside the host
	print("FILM READY")
	if _shots != "":
		_shoot()
	await get_tree().create_timer(HOLD + (2.0 if _keep_ui else 0.0)).timeout  # --ui: the recorder starts about a second late, keep the standing beat
	for point in ROUTE:
		me.call("command_walk_to", point)
		if not _keep_ui:
			me.get("marker").visible = false
		var left := 10.0
		while left > 0.0 and Vector2(me.global_position.x - point.x, me.global_position.z - point.z).length() > ARRIVE:
			await get_tree().create_timer(0.1).timeout
			left -= 0.1
		print("FILM at %s (wanted %s)" % [me.global_position, point])
	await get_tree().create_timer(2.0).timeout  # the bots catch up and settle
	print("FILM DONE")


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _shoot() -> void:
	for i in 20:
		get_viewport().get_texture().get_image().save_jpg("%s/shot_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(1.0).timeout
