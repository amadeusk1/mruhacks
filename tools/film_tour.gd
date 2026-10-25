extends "res://tools/film_host.gd"

## Feature shot: the five slide-look penguins walk into one place together. Indoors the host
## arrives at the door with the follow bots, then walks into the room (across it, side-on, in the café);
## at the court it starts beside it and walks onto the paint. FILM READY just before the walk,
## FILM DONE once everyone has settled.
##   Godot --path . res://tools/film_tour.tscn -- --net-host --net-name=Host --place=cafe --ui
## --place: cafe | arcade | casino | cinema | court. --bots=0 runs alone; --shots=DIR saves a frame
## every half second (framing checks).

const SPAWNS := {"cafe": "Inside", "arcade": "Inside", "casino": "Inside", "cinema": "InsideScreen"}
const SIDE_ON := ["cafe"]  # walk across the room; elsewhere toward the middle of its seats
const WALK := 6.0           # metres into the room
const COURT_START := Vector3(0.0, 0.0, 9.0)  # from the court's centre
const ARRIVE := 0.6

var _place := "cafe"
var _bots := 4
var _shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="):
			_place = a.trim_prefix("--place=")
		elif a.begins_with("--bots="):
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
	var goal: Vector3
	if _place == "court":
		var court := _w.find_child("TownCourt", true, false)
		var center: Vector3 = court.get("_center")
		me.global_position = _on_nav(center + COURT_START) + Vector3(0, 0.1, 0)
		me.call("halt")
		var rig: Node3D = _w.get("_camera_rig")
		rig.global_position = me.global_position
		goal = _on_nav(center)
		await get_tree().create_timer(4.0).timeout  # the bots walk over from where they were
	else:
		_w.call("travel_to", _place, SPAWNS[_place])
		while _w.call("current_location_id") != _place or _w.get("_traveling"):
			await get_tree().create_timer(0.2).timeout
		if _place in SIDE_ON:
			# across the room, side-on to the camera so faces show: whichever side has more floor
			var side: Vector3 = (_w.get("_camera_rig") as Node3D).global_transform.basis.x
			var one := _on_nav(me.global_position - side * WALK)
			var other := _on_nav(me.global_position + side * WALK)
			goal = one if one.distance_to(me.global_position) > other.distance_to(me.global_position) else other
		else:
			var middle := Vector3.ZERO
			var seats := 0
			for node in get_tree().get_nodes_in_group("interactables"):
				if node is SeatSpot:
					middle += node.get("seat_point")
					seats += 1
			middle /= float(maxi(seats, 1))
			var way := Vector3(middle.x - me.global_position.x, 0.0, middle.z - me.global_position.z)
			goal = _on_nav(me.global_position + way.limit_length(WALK))
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
		UIRouter.hide_ui()
	while _bots_here() < _bots or _bots_in(str(_w.call("current_location_id"))) < _bots:
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(3.0).timeout  # bots step to their places beside the host
	print("FILM READY host at %s" % me.global_position)
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			print("FILM bot at %s" % (puppet as Node3D).global_position)
	if _shots != "":
		_shoot()
	await get_tree().create_timer(1.5).timeout  # the recorder starts a beat late
	me.call("command_walk_to", goal)
	if not _keep_ui:
		me.get("marker").visible = false
	var left := 8.0
	while left > 0.0 and Vector2(me.global_position.x - goal.x, me.global_position.z - goal.z).length() > ARRIVE:
		await get_tree().create_timer(0.1).timeout
		left -= 0.1
	print("FILM at %s (wanted %s)" % [me.global_position, goal])
	await get_tree().create_timer(2.0).timeout  # the bots catch up and settle
	print("FILM DONE")


func _on_nav(at: Vector3) -> Vector3:
	var map := (_w.get_node("Penguin").get("agent") as NavigationAgent3D).get_navigation_map()
	return NavigationServer3D.map_get_closest_point(map, at)


## Bots standing in the host's current place (puppets elsewhere are hidden).
func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


## Bots the roster says are in this place (puppets of bots still on their way may linger).
func _bots_in(place: String) -> int:
	var n := 0
	for e in Net.roster():
		if int(e.get("id", 0)) != Net.local_id() and str(e.get("location", "")) == place:
			n += 1
	return n


func _shoot() -> void:
	for i in 20:
		get_viewport().get_texture().get_image().save_jpg("%s/%s_%02d.jpg" % [_shots, _place, i])
		await get_tree().create_timer(0.5).timeout
