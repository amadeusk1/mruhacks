extends Node

## Screenshots the shot-aim guide: puts the penguin on the town court holding the ball, once at
## the default loft and once at a high one. Needs a window (not --headless).
##   Godot --path . res://tools/court_aim_shot.tscn -- --out=C:/some/dir

var _w: Node
var _p: CharacterBody3D


func _ready() -> void:
	var out := OS.get_environment("TEMP")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	await _w.travel_to("town", "BusArrival")
	await get_tree().create_timer(3.0).timeout
	var court: Node
	for n in get_tree().root.find_children("*", "Node", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("town_court.gd"):
			court = n
	if court == null:
		print("AIMSHOT no court")
		get_tree().quit(1)
		return
	var ball: Node3D = court.get("_ball")
	var spot := ball.global_position
	spot.y = 0.1
	_p.global_position = spot + Vector3(-2.5, 0.0, 0.0)  # inside the pickup radius soon after walking in
	_p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	_p.global_position = spot
	for i in 120:
		await get_tree().physics_frame
		if Net.court_carrying():
			break
	print("AIMSHOT carrying=%s here=%s" % [Net.court_carrying(), Net.court_here(_p.global_position)])
	for loft in [0.5, 0.95]:
		Net.court_loft = loft
		await get_tree().create_timer(0.8).timeout
		var aim: Node3D = court.get("_aim")
		print("AIMSHOT loft=%.2f guide_visible=%s hint=%s" % [loft, aim.visible, (court.get("_hint") as Label).text])
		get_viewport().get_texture().get_image().save_png("%s/court_aim_%d.png" % [out, int(loft * 100)])
	# Green arc, real click path (Net.court_action): five shots from the middle must all score.
	var Match := load("res://scripts/court_match.gd")
	var made := 0
	for shot in 5:
		var st: Dictionary = Net.court_view()
		for i in 240:  # stand on the loose ball, wherever the last shot left it
			st = Net.court_view()
			_p.global_position = Vector3(float(st.get("bx", spot.x)), 0.1, float(st.get("bz", spot.z)))
			await get_tree().physics_frame
			if Net.court_carrying():
				break
		_p.global_position = Vector3(spot.x + (shot - 2) * 1.2, 0.1, spot.z + (shot - 2) * 0.7)  # vary the distance
		await get_tree().physics_frame
		var rim: Vector3 = court.call("_attack_rim", Net.court_view(), _p)
		var from: Vector3 = court.call("_carry", _p)
		Net.court_loft = Match.ideal_loft(Vector2(from.x - rim.x, from.z - rim.z).length())
		var before := int(Net.court_view().get("coral", 0))
		Net.court_action("shoot")
		await get_tree().create_timer(2.0).timeout
		var after := int(Net.court_view().get("coral", 0))
		made += 1 if after > before else 0
		print("AIMSHOT shot %d loft=%.2f score %d -> %d" % [shot + 1, Net.court_loft, before, after])
	print("AIMSHOT green shots made %d of 5" % made)
	get_tree().quit()
