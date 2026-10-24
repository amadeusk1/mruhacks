extends Node

## Water rescue check: walk the penguin off the shore into the sea in small steps (like a fall,
## not a teleport) and expect it back on the navmesh within 3 s. Then press the unstuck key.
##   Godot --headless --path . res://tools/rescue_check.tscn

var _w: Node
var _p: CharacterBody3D


func _ready() -> void:
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	await _w.travel_to("town", "BusArrival")
	await get_tree().create_timer(3.0).timeout
	var room: Node = _w.get_node("LocationHost").get_child(0)
	var water := float(room.get("_layout").get("water_level", 0.0))
	var space := _p.get_world_3d().direct_space_state
	var wet := Vector3.INF
	var start := _p.global_position
	for k in 32:  # nearest shore: march out from the spawn until the floor is under the water line
		var dir := Vector3(cos(TAU * k / 32.0), 0, sin(TAU * k / 32.0))
		var last := _p.global_position
		for s in range(1, 120):
			var q := _p.global_position + dir * s * 0.5
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 20, q + Vector3.DOWN * 20, 1))
			if hit.is_empty() or hit.position.y < water - 0.05:
				if wet == Vector3.INF or q.distance_to(_p.global_position) < wet.distance_to(_p.global_position):
					wet = Vector3(q.x + dir.x, water - 1.0, q.z + dir.z)
					start = last
				break
			last = hit.position
	print("RESCUE start=%s water=%.2f wet=%s spots=%d" % [start, water, wet, (_p.get("_safe_spots") as Array).size()])
	_p.call("command_walk_to", start)  # walk to the shore so the trail ends there
	for i in 900:
		await get_tree().physics_frame
		if not _p.get("_click_active"):
			break
	start = _p.global_position
	var steps := int(start.distance_to(wet) / 0.5) + 1
	for i in steps:
		_p.global_position = start.lerp(wet, float(i + 1) / steps)
		await get_tree().physics_frame
	_p.velocity = Vector3.ZERO
	print("RESCUE in water at %s" % _p.global_position)
	var map := _p.get_world_3d().navigation_map
	var t := 0.0
	var back := false
	while t < 4.0 and not back:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var near := NavigationServer3D.map_get_closest_point(map, _p.global_position)
		back = _p.global_position.y > water and near.distance_to(_p.global_position) < 0.5
	print("RESCUE auto %s after %.2fs at %s" % ["OK" if back else "FAIL", t, _p.global_position])
	var before := _p.global_position
	var ev := InputEventAction.new()
	ev.action = "unstuck"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("RESCUE key moved %.2fm to %s" % [before.distance_to(_p.global_position), _p.global_position])
	get_tree().quit()
