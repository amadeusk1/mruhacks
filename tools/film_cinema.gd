extends "res://tools/film_host.gd"

## Trailer shot: the five slide-look penguins sitting together in the cinema auditorium. The host
## takes the seat nearest the hall's middle (tools/seat_pilot.gd); follow bots arrive and sit beside
## it. The screen stays off (the film needs the cinema service), so the camera sits on the screen
## side and looks back at the audience. FILM READY once four bots are seated, FILM DONE later.
##   Godot --path . res://tools/film_cinema.tscn -- --net-host --net-name=Host
## --bots=0 runs alone; --shots=DIR saves a frame every half second (framing checks).

const CAM_HEIGHT := 4.6
const CAM_DISTANCE := 4.2  # the screen wall is ~5.5 m in front of the middle seats
const LENGTH := 10.0

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
	me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var pilot := preload("res://tools/seat_pilot.gd").new()
	pilot.near = hall
	pilot.active = true
	add_child(pilot)
	while not bool(me.call("is_sitting")):
		await get_tree().create_timer(0.3).timeout
	# look back at the audience from the screen's side
	var screen := Sockets.find(room.find_child("cinema_auditorium", true, false), "screen")
	var rig: Node3D = _w.get("_camera_rig")
	if screen != null and screen.global_position.z < me.global_position.z:
		rig.rotation.y = PI
	rig.call("pin_focus", me.global_position, CAM_HEIGHT, CAM_DISTANCE, 0.6)
	UIRouter.hide_ui()
	print("FILM host seated at %s, screen at %s" % [me.global_position, screen.global_position if screen else "?"])
	if _shots != "":
		_shoot()
	while _seated_bots() < _bots:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.5).timeout
	print("FILM READY")
	await get_tree().create_timer(LENGTH).timeout
	print("FILM DONE")


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
