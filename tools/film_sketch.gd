extends "res://tools/film_host.gd"

## Minigame shot: the host sits at the Sketch Club table, opens "just draw on your own" and draws
## the canvas's demo picture (a penguin on a crescent moon, without its scribbled night sky) stroke
## by stroke through the canvas's own input, with each stroke's colour and width, as a player would.
## FILM READY as the first stroke starts, FILM DONE when the picture is finished.
##   BOTS=0 tools/film_shot.sh film_sketch out.mkv 14 --ui --bots=0
## --shots=DIR saves a frame every half second (framing checks).

const POINTS_PER_SECOND := 30.0
const SKY_STROKES := 26  # the demo's scribbled night sky: on a wide canvas it reads as a blot

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
	var me: CharacterBody3D = _w.get_node("Penguin")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var seat: SeatSpot
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is SeatSpot and str(node.get("kit")) == "sketch":
			seat = node
			break
	me.global_position = seat.get("seat_point") + Vector3(0, 0.1, 1.5)  # beside the table, then sit like a player
	(_w.get("_camera_rig") as Node3D).global_position = me.global_position
	var pilot := preload("res://tools/seat_pilot.gd").new()
	pilot.kit = "sketch"
	pilot.near = seat.get("seat_point")
	pilot.active = true
	add_child(pilot)
	var ui: Control
	while ui == null:
		for c in UIRouter.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("sketch_ui.gd"):
				ui = c
		await get_tree().create_timer(0.3).timeout
	pilot.active = false
	await get_tree().create_timer(1.0).timeout
	ui.call("_start_free")
	await get_tree().create_timer(1.0).timeout
	var canvas: SketchCanvas = ui.get("_canvas")
	var picture := SketchCanvas.new()
	picture.demo()
	print("FILM READY")
	if _shots != "":
		_shoot()
	await get_tree().create_timer(1.0).timeout  # the recorder starts a beat late
	for s in picture.strokes.slice(SKY_STROKES):
		canvas.color = Color(str(s["c"]))
		canvas.width = float(s["w"]) * canvas.size.x / 1000.0
		var p: PackedVector2Array = s["p"]
		canvas._gui_input(_button(p[0] * canvas.size, true))
		for i in range(1, p.size()):
			var motion := InputEventMouseMotion.new()
			motion.position = p[i] * canvas.size
			canvas._gui_input(motion)
			await get_tree().create_timer(1.0 / POINTS_PER_SECOND).timeout
		canvas._gui_input(_button(p[p.size() - 1] * canvas.size, false))
		await get_tree().create_timer(0.08).timeout
	picture.free()
	await get_tree().create_timer(2.0).timeout
	print("FILM DONE")


func _button(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	return e


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _shoot() -> void:
	for i in 28:
		get_viewport().get_texture().get_image().save_jpg("%s/sketch_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
