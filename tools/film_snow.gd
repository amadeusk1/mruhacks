extends "res://tools/film_host.gd"

## Trailer shot: a 2v2 snowball fight in the town arena with the slide-look penguins. The host
## and one follow bot take coral, two bots take teal, the fifth watches (tools/snow_pilot.gd).
## The camera holds on the whole field. FILM READY when the match goes live, FILM DONE later.
##   Godot --path . res://tools/film_snow.tscn -- --net-host --net-name=Host --tod=0.70
## --bots=0 runs alone (no match starts); --shots=DIR saves a frame every half second.

const CAM_HEIGHT := 9.0
const CAM_DISTANCE := 9.0
const UI_CAM_HEIGHT := 11.5  # --ui: back off a little so the scoreboard and the buttons leave the far lane and the gate lane clear
const UI_CAM_DISTANCE := 11.5
const UI_FOCUS_SHIFT := 0.5  # metres up-field, so the far lane clears the scoreboard
const LENGTH := 14.0

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
	var arena: Node = null
	while arena == null:
		arena = get_tree().get_first_node_in_group("snow_arena")
		await get_tree().create_timer(0.5).timeout
	var me: CharacterBody3D = _w.get_node("Penguin")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var field: Rect2 = arena.get("_field")
	var floor_y := float(arena.get("_floor"))
	var pads: Dictionary = arena.get("_pads")
	var gate: Vector2 = (pads["coral"] + pads["teal"]) * 0.5
	me.global_position = Vector3(gate.x, floor_y + 0.1, gate.y + 2.2)
	me.call("halt")
	var middle := field.get_center()
	_w.get("_camera_rig").call("pin_focus", Vector3(middle.x, floor_y, middle.y - (UI_FOCUS_SHIFT if _keep_ui else 0.0)), UI_CAM_HEIGHT if _keep_ui else CAM_HEIGHT, UI_CAM_DISTANCE if _keep_ui else CAM_DISTANCE, 0.4)
	print("FILM field %s pads %s" % [field, pads])
	while _bots_here() < _bots:
		await get_tree().create_timer(0.5).timeout
	var pilot := preload("res://tools/snow_pilot.gd").new()
	pilot.team = "coral"
	pilot.active = true
	add_child(pilot)
	if not _keep_ui:
		UIRouter.hide_ui()
	if _shots != "":
		_shoot()
	# --ui: the host's own scoreboard only shows when it plays, so wait for a match with the host in it
	while str(Net.snow_view().get("phase", "")) != "live" or (_keep_ui and Net.snow_team() == ""):
		await get_tree().create_timer(0.2).timeout
	print("FILM READY")
	await get_tree().create_timer(LENGTH).timeout
	print("FILM DONE %s" % [Net.snow_view().get("text", "")])


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _shoot() -> void:
	for i in 24:
		get_viewport().get_texture().get_image().save_jpg("%s/snow_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
