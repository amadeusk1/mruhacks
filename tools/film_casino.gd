extends "res://tools/film_host.gd"

## Trailer shot: the five slide-look penguins seated around the casino's poker table. The host
## takes the poker seat nearest the table's middle (tools/seat_pilot.gd, kit "casino"); follow bots
## arrive and take the seats nearest it. Table games open as 2D screens, which Hide UI keeps off
## the film; the camera holds on the table from across it, facing the host. FILM READY once four bots are seated, FILM DONE later.
##   Godot --path . res://tools/film_casino.tscn -- --net-host --net-name=Host
## --bots=0 runs alone; --shots=DIR saves a frame every half second (framing checks).

const GAME := "poker"
const CAM_HEIGHT := 4.5
const CAM_DISTANCE := 5.0
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
	_w.call("travel_to", "casino", "Inside")
	while _w.call("current_location_id") != "casino" or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var me: CharacterBody3D = _w.get_node("Penguin")
	me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var table := Vector3.ZERO
	var seats := 0
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is SeatSpot and str(node.get("activity")) == GAME:
			table += node.get("seat_point")
			seats += 1
	table /= float(maxi(seats, 1))
	print("FILM %s table at %s (%d seats)" % [GAME, table, seats])
	if not _keep_ui:
		UIRouter.hide_ui()  # --ui: the poker screen opens over the table, as a player sees it
	var pilot := preload("res://tools/seat_pilot.gd").new()
	pilot.kit = "casino"
	pilot.near = table
	pilot.active = true
	add_child(pilot)
	add_child(preload("res://tools/poker_pilot.gd").new())  # --ui: the hands are played on the poker screen
	while not bool(me.call("is_sitting")):
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.5).timeout  # the table game may move the camera; take it back
	var rig: Node3D = _w.get("_camera_rig")
	if me.global_position.z > table.z:
		rig.rotation.y = PI  # film from across the table: the host faces the camera
	rig.call("pin_focus", Vector3(table.x, 0.0, table.z), CAM_HEIGHT, CAM_DISTANCE, 0.8)
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
		get_viewport().get_texture().get_image().save_jpg("%s/casino_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
