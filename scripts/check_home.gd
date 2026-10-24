extends SceneTree

func _initialize() -> void:
	var packed := load("res://scenes/world.tscn") as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	for _i in 12:
		await process_frame
		await physics_frame
	var penguin := world.get_node("Penguin") as Node3D
	print("BOOT ", _fmt(penguin), " loc ", world.current_location_id(), " traveling ", world.is_traveling())
	await _shot("c:/Users/User/Desktop/mruhacks/shot_inside.png")
	world.shift_to_marker("OutsideSpawn")
	for _i in 40:
		await physics_frame
	print("YARD ", _fmt(penguin), " traveling ", world.is_traveling())
	var agent := penguin.get_node("NavigationAgent3D") as NavigationAgent3D
	var map := agent.get_navigation_map()
	var from := NavigationServer3D.map_get_closest_point(map, Vector3(-0.2, 0.2, 2.25))
	var to := NavigationServer3D.map_get_closest_point(map, Vector3(-1.7, 0.2, 0.5))
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	print("DOOR PATH ", path.size(), " end ", (path[path.size() - 1] if path.size() else Vector3.ZERO))
	var bus := NavigationServer3D.map_get_closest_point(map, Vector3(2.15, 0.2, 1.05))
	var bus_path := NavigationServer3D.map_get_path(map, from, bus, true)
	print("BUS PATH ", bus_path.size())
	await _shot("c:/Users/User/Desktop/mruhacks/shot_yard.png")
	world.shift_to_marker("InsideReturn")
	for _i in 40:
		await physics_frame
	print("BACK ", _fmt(penguin), " traveling ", world.is_traveling())
	await _shot("c:/Users/User/Desktop/mruhacks/shot_return.png")
	quit()


func _shot(path: String) -> void:
	for _i in 3:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path, " ", img.get_width(), "x", img.get_height())


func _fmt(body: Node3D) -> String:
	return "(%.2f, %.2f, %.2f) yaw %.2f" % [body.global_position.x, body.global_position.y, body.global_position.z, body.rotation.y]
