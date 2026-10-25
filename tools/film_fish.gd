extends "res://tools/film_host.gd"

## Trailer shot: the slide-look penguins fishing side by side on the pier. The host sits at a
## spot on the four-spot pier (tools/fish_pilot.gd); follow bots see it fishing and take the
## other spots there, the one left over stands by. The camera holds on that pier. FILM READY once
## three bots are fishing too, FILM DONE a few catches later.
##   Godot --path . res://tools/film_fish.tscn -- --net-host --net-name=Host --tod=0.70
## --bots=0 runs alone; --shots=DIR saves a frame every half second (framing checks).

const CAM_HEIGHT := 5.0
const CAM_DISTANCE := 6.5
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
	var me: CharacterBody3D = _w.get_node("Penguin")
	me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var spots := get_tree().get_nodes_in_group("fish_spot")
	# the host takes the spot with the most neighbours: the four-spot pier, framed whole
	var first: Node3D = null
	var group: Array = []
	for spot in spots:
		var near := spots.filter(func(o: Node3D) -> bool: return o.global_position.distance_to((spot as Node3D).global_position) < 4.0)
		if near.size() > group.size():
			first = spot
			group = near
	var pier := Vector3.ZERO
	for spot in group:
		pier += (spot as Node3D).global_position
	pier /= float(group.size())
	print("FILM pier at %s (%d spots)" % [pier, group.size()])
	me.global_position = first.call("stand_point")
	_w.get("_camera_rig").call("pin_focus", pier, CAM_HEIGHT, CAM_DISTANCE, 0.6)
	while _bots_here() < _bots:
		await get_tree().create_timer(0.5).timeout
	var pilot := preload("res://tools/fish_pilot.gd").new()
	pilot.active = true
	add_child(pilot)
	while _fishing_bots() < mini(_bots, group.size() - 1):
		await get_tree().create_timer(0.5).timeout
	UIRouter.hide_ui()
	await get_tree().create_timer(2.0).timeout  # everyone settles into a cast
	print("FILM READY host fishing=%s" % me.call("is_fishing"))
	if _shots != "":
		_shoot()
	await get_tree().create_timer(LENGTH).timeout
	print("FILM DONE")


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _fishing_bots() -> int:
	var n := 0
	for e in Net.roster():
		if int(e.get("id", 0)) != Net.local_id() and str(e.get("fisher", "")) != "":
			n += 1
	return n


func _shoot() -> void:
	for i in 24:
		get_viewport().get_texture().get_image().save_jpg("%s/fish_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
