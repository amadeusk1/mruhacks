extends SceneTree

## Loads the bus world, rides to Sled Hill, steers, crashes, finishes, and rides home.


func _initialize() -> void:
	var code := 0
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in 90:
		await physics_frame
		if world.current_location_id() != "" and not world._traveling:
			break
	print("start ", world.current_location_id(), " traveling ", world._traveling)
	if world.current_location_id() == "":
		push_error("no location loaded")
		code = 1
	if LocationCatalog.scene_path("sled_hill") != "res://scenes/sled_run.tscn":
		push_error("catalog does not point at the hill")
		code = 1

	world.travel_to("sled_hill")
	await physics_frame
	var run := world.get_node_or_null("LocationHost/SledRun")
	if run == null:
		push_error("sled room missing")
		quit(1)
		return
	var sled := run.get_node("Sled") as CharacterBody3D
	var penguin: Node3D = world.get_node("Penguin")
	var plaza_cam := world.get_node("CameraRig/Camera3D") as Camera3D
	var hill_cam := run.get_node("CameraRig/Camera3D") as Camera3D
	print("town penguin y ", penguin.global_position.y, " visible ", penguin.visible)
	if penguin.visible or penguin.global_position.y > -10.0:
		push_error("town penguin was left on the hill")
		code = 1
	if plaza_cam.current or not hill_cam.current:
		push_error("hill camera did not take over")
		code = 1

	Input.action_press("move_right")
	sled.begin()
	var x0 := sled.global_position.x
	for _i in 20:
		await physics_frame
	Input.action_release("move_right")
	var steered := sled.global_position.x - x0
	print("steered ", steered, " y ", sled.global_position.y)
	if steered < 0.8:
		push_error("steer did not move the sled")
		code = 1

	sled.global_position = Vector3(-3.6, 0.3, -13.2)
	for _i in 30:
		await physics_frame
		if sled._crashed:
			break
	print("crashed ", sled._crashed, " at ", sled.global_position)
	if not sled._crashed:
		push_error("tree did not wipe the sled out")
		code = 1

	sled.reset_run(Vector3(0.0, 0.4, -176.0))
	for _i in 3:
		await physics_frame
	sled.begin()
	sled.global_position = Vector3(0.0, 0.4, -179.9)
	for _i in 6:
		await physics_frame
		if sled._ended and not sled._crashed:
			break
	var panel: CanvasItem = run.get_node("HUD/Center/Result")
	print("finish ended ", sled._ended, " crashed ", sled._crashed, " panel ", panel.visible)
	if sled._crashed or not sled._ended or not panel.visible:
		push_error("finish line did not end the run")
		code = 1

	world.travel_to("plaza")
	for _i in 40:
		await physics_frame
		if world.current_location_id() == "plaza" and not world._traveling:
			break
	print("home ", world.current_location_id(), " penguin y ", penguin.global_position.y, " visible ", penguin.visible, " cam ", plaza_cam.current)
	if world.current_location_id() != "plaza" or not penguin.visible or not plaza_cam.current:
		push_error("ride home did not restore the plaza")
		code = 1
	if world.get_node_or_null("LocationHost/SledRun") != null:
		push_error("hill stayed loaded")
		code = 1

	print("SMOKE ", "ok" if code == 0 else "failed")
	quit(code)
