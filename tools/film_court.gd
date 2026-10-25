extends "res://tools/film_host.gd"

## Minigame shot: shooting hoops on the town court. The host walks into the ball, carries it to a
## spot a few metres out from the hoop, sets the loft the aim guide shows green for that distance,
## and shoots, three times. The camera sits closer than the town's overview. FILM READY before the
## first pick-up, FILM DONE after the last shot lands.
##   BOTS=0 tools/film_shot.sh film_court out.mkv 20 --ui --bots=0
## --bots=N waits for N follow bots (they stand around); --shots=DIR saves a frame every half second.

const _Match := preload("res://scripts/court_match.gd")
const SHOTS := 3
const RANGE := 4.2         # metres from the rim's foot
const CAM_HEIGHT := 5.5
const CAM_DISTANCE := 6.5

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
	var court := _w.find_child("TownCourt", true, false)
	var center: Vector3 = court.get("_center")
	var me: CharacterBody3D = _w.get_node("Penguin")
	me.global_position = _on_nav(center + Vector3(0.0, 0.0, 3.0)) + Vector3(0, 0.1, 0)
	me.call("halt")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
		UIRouter.hide_ui()
	var rig: Node3D = _w.get("_camera_rig")
	rig.global_position = me.global_position
	await get_tree().create_timer(3.0).timeout  # the court sees the host arrive; practice opens
	print("FILM READY")
	if _shots != "":
		_shoot()
	await get_tree().create_timer(1.0).timeout  # the recorder starts a beat late
	for i in SHOTS:
		while not Net.court_carrying():  # walk into the loose ball
			var st: Dictionary = Net.court_view()
			me.call("command_walk_to", _on_nav(Vector3(float(st.get("bx", center.x)), 0.0, float(st.get("bz", center.z)))))
			_frame(rig, me.global_position)
			await get_tree().create_timer(0.3).timeout
		var rim: Vector3 = court.call("_attack_rim", Net.court_view(), me)
		var foot := Vector3(rim.x, center.y, rim.z)
		var spot := _on_nav(foot + (center - foot).normalized() * RANGE)
		me.call("command_walk_to", spot)
		var left := 5.0
		while left > 0.0 and Vector2(me.global_position.x - spot.x, me.global_position.z - spot.z).length() > 0.5:
			_frame(rig, me.global_position.lerp(foot, 0.4))
			await get_tree().create_timer(0.1).timeout
			left -= 0.1
		me.call("halt")
		var dist := Vector2(me.global_position.x - rim.x, me.global_position.z - rim.z).length()
		Net.court_loft = _Match.ideal_loft(dist)
		await get_tree().create_timer(0.7).timeout  # the green aim arc shows
		Net.court_action("shoot")
		var before := int(Net.court_view().get("coral", 0)) + int(Net.court_view().get("teal", 0))
		await get_tree().create_timer(1.8).timeout
		var after := int(Net.court_view().get("coral", 0)) + int(Net.court_view().get("teal", 0))
		print("FILM shot %d from %.1f m: %s" % [i + 1, dist, "in" if after > before else "miss"])
	print("FILM DONE")


func _frame(rig: Node3D, at: Vector3) -> void:
	rig.call("pin_focus", at, CAM_HEIGHT, CAM_DISTANCE, 1.0)


func _on_nav(at: Vector3) -> Vector3:
	var map := (_w.get_node("Penguin").get("agent") as NavigationAgent3D).get_navigation_map()
	return NavigationServer3D.map_get_closest_point(map, at)


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _shoot() -> void:
	for i in 30:
		get_viewport().get_texture().get_image().save_jpg("%s/court_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
