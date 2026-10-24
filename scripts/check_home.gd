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
	var probe := Node3D.new()
	root.add_child(probe)
	probe.rotation.y = atan2(-0.89, 0.455)
	var b := probe.global_transform.basis
	print("BASIS yaw ", probe.rotation.y)
	print("X ", b.x, " Z ", b.z)
	world.shift_to_marker("OutsideSpawn")
	for _i in 40:
		await physics_frame
	print("YARD ", _fmt(penguin), " traveling ", world.is_traveling())
	world.shift_to_marker("InsideReturn")
	for _i in 40:
		await physics_frame
	print("BACK ", _fmt(penguin), " traveling ", world.is_traveling())
	quit()


func _fmt(body: Node3D) -> String:
	return "(%.2f, %.2f, %.2f) yaw %.2f" % [body.global_position.x, body.global_position.y, body.global_position.z, body.rotation.y]
