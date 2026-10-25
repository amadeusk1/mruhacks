extends "res://tools/film_host.gd"

## Feature shot: the five slide-look penguins sitting together in the café. The host takes a seat in
## the café's tightest group of five seats (tools/seat_pilot.gd, any plain seat); the follow bots
## walk in and sit beside it. The camera holds on the group. FILM READY once four bots are seated,
## FILM DONE later.
##   Godot --path . res://tools/film_cafe.tscn -- --net-host --net-name=Host --ui
## --bots=0 runs alone; --shots=DIR saves a frame every half second (framing checks).

const CAM_HEIGHT := 4.2
const CAM_DISTANCE := 4.8
const LENGTH := 12.0

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
	_w.call("travel_to", "cafe", "Inside")
	while _w.call("current_location_id") != "cafe" or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var me: CharacterBody3D = _w.get_node("Penguin")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
		UIRouter.hide_ui()
	var seat := _group_seat()
	print("FILM café group around %s" % seat)
	var pilot := preload("res://tools/seat_pilot.gd").new()
	pilot.kit = "*"
	pilot.near = seat
	pilot.active = true
	add_child(pilot)
	while not bool(me.call("is_sitting")):
		await get_tree().create_timer(0.3).timeout
	while _seated_bots() < _bots:
		await get_tree().create_timer(0.5).timeout
	var middle := me.global_position
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			middle += (puppet as Node3D).global_position
	middle /= float(_bots + 1)
	var rig: Node3D = _w.get("_camera_rig")
	rig.call("pin_focus", middle, CAM_HEIGHT, CAM_DISTANCE, 0.6)
	await get_tree().create_timer(1.5).timeout
	print("FILM READY")
	if _shots != "":
		_shoot()
	await get_tree().create_timer(LENGTH).timeout
	print("FILM DONE")


## The plain seat whose four nearest plain seats are closest: one table's worth of friends.
func _group_seat() -> Vector3:
	var points: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is SeatSpot and str(node.get("activity")) == "":
			points.append(node.get("seat_point"))
	var best := Vector3.ZERO
	var best_spread := INF
	for p in points:
		var near: Array[float] = []
		for q in points:
			near.append(p.distance_to(q))
		near.sort()
		var spread := 0.0
		for i in range(1, mini(5, near.size())):
			spread += near[i]
		if spread < best_spread:
			best_spread = spread
			best = p
	return best


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
		get_viewport().get_texture().get_image().save_jpg("%s/cafe_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
