extends Node

## One-shot: walk the local penguin to every town activity and record what opens.
## Godot ... -- --net-solo --walk-activities

const REPORT := "user://walk_activities.txt"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var lines: PackedStringArray = []
	var world := get_parent()
	var penguin: Node3D = await _wait_player(world)
	if penguin == null:
		_finish(lines, "never reached town")
		return
	await get_tree().create_timer(1.5).timeout
	var stops := _stops()
	lines.append("stops %d from %s" % [stops.size(), world.call("current_location_id")])
	for stop in stops:
		if str(world.call("current_location_id")) != "town":
			await world.travel_to("town", "BusArrival")
			await _until_town(world)
		penguin = await _wait_player(world)
		if penguin == null:
			lines.append("%s | walk lost | player missing after travel" % stop["name"])
			print("WALK ", lines[lines.size() - 1])
			continue
		_dismiss(penguin)
		var target := _fresh(stop)
		var at: Vector3 = stop["at"]
		var close := 2.0
		if target != null and target.has_method("approach_point"):
			at = target.call("approach_point")
		if target != null and target.get("reach") != null:
			close = maxf(float(target.get("reach")) - 0.25, 1.2)
		penguin.call("command_walk_to", at)
		var arrived := await _until_near(penguin, at, close, 22.0)
		var here: Vector3 = penguin.global_position
		var note := ""
		if str(stop["kind"]) == "fish" and target != null and target.has_method("try_fish"):
			var fished := bool(target.call("try_fish", true))
			note = "fishing %s" % ("started" if fished else "refused")
		elif str(stop["kind"]) == "interact":
			if target == null:
				note = "marker gone after rebuild"
			elif target.has_method("can_interact") and bool(target.call("can_interact")):
				var opened := bool(target.call("interact", penguin))
				note = "interact %s" % ("opened" if opened else "refused")
			else:
				var gap := Vector2(here.x - at.x, here.z - at.z).length()
				note = "prompt hidden, %.1fm away" % gap
		elif str(stop["name"]) == "Basketball":
			note = "on court" if Net.court_here(here) else "not on the court"
		elif str(stop["name"]) == "Dance floor":
			await get_tree().create_timer(1.2).timeout
			note = _dance_note()
		else:
			note = "no action"
		await get_tree().create_timer(0.8).timeout
		var where := str(world.call("current_location_id"))
		var ui := ""
		if UIRouter.is_open():
			var top := UIRouter.top()
			ui = top.get_script().resource_path.get_file() if top != null and top.get_script() != null else "open"
		var sat: bool = penguin.has_method("is_sitting") and bool(penguin.call("is_sitting"))
		lines.append("%s | walk %s | at (%.1f, %.1f) | %s | place %s | ui %s | sitting %s" % [
			stop["name"], "ok" if arrived else "short", here.x, here.z, note, where, ui if ui != "" else "-", sat,
		])
		print("WALK ", lines[lines.size() - 1])
		_dismiss(penguin)
	_finish(lines, "done")


func _stops() -> Array:
	var out: Array = []
	var seen := {}
	for node in get_tree().get_nodes_in_group("interactables"):
		var activity := str(node.get("activity"))
		var location := str(node.get("location"))
		var key := activity if activity != "" else location
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		var title := ""
		if node is Interactable:
			title = (node as Interactable).title
		if title == "":
			title = key
		out.append({
			"name": title,
			"kind": "interact",
			"activity": activity,
			"location": location,
			"at": node.global_position,
		})
	var fish := get_tree().get_first_node_in_group("fish_spot")
	if fish != null:
		out.append({
			"name": "Fishing",
			"kind": "fish",
			"activity": "",
			"location": "",
			"at": fish.call("approach_point"),
		})
	out.append({"name": "Basketball", "kind": "court", "activity": "", "location": "", "at": Vector3(25.5, 0.2, 19.2)})
	out.append({"name": "Dance floor", "kind": "floor", "activity": "", "location": "", "at": Vector3(6.6, 0.2, 0.0)})
	return out


func _fresh(stop: Dictionary) -> Node:
	if str(stop["kind"]) == "fish":
		return get_tree().get_first_node_in_group("fish_spot")
	if str(stop["kind"]) != "interact":
		return null
	for node in get_tree().get_nodes_in_group("interactables"):
		if str(node.get("activity")) == str(stop["activity"]) and str(node.get("location")) == str(stop["location"]):
			return node
	return null


func _wait_player(world: Node) -> Node3D:
	for _i in 60:
		var penguin := get_tree().get_first_node_in_group("local_player")
		if penguin != null and str(world.call("current_location_id")) == "town" and penguin.visible:
			var agent: NavigationAgent3D = penguin.get_node_or_null("NavigationAgent3D")
			if agent != null and agent.get_navigation_map().is_valid():
				return penguin as Node3D
		await get_tree().create_timer(0.5).timeout
	return null


func _until_town(world: Node) -> void:
	for _i in 40:
		if str(world.call("current_location_id")) == "town":
			await get_tree().create_timer(1.0).timeout
			return
		await get_tree().create_timer(0.25).timeout


func _until_near(penguin: Node3D, at: Vector3, reach: float, limit: float) -> bool:
	var left := limit
	while left > 0.0:
		var flat := Vector2(penguin.global_position.x - at.x, penguin.global_position.z - at.z)
		if flat.length() <= reach:
			return true
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	return false


func _dance_note() -> String:
	for node in get_tree().get_nodes_in_group("dance_floor"):
		return "floor present"
	var named := get_tree().root.find_child("DanceFloor", true, false)
	return "dancing area" if named != null else "floor missing"


func _dismiss(penguin: Node) -> void:
	if penguin != null and penguin.has_method("stand_up"):
		penguin.call("stand_up")
	if UIRouter.is_open():
		UIRouter.close_all()


func _finish(lines: PackedStringArray, tail: String) -> void:
	lines.append(tail)
	var text := "\n".join(lines)
	print(text)
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file:
		file.store_string(text)
	get_tree().quit()
