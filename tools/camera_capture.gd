extends Node
## Height-tracking camera check: the penguin at the sled stair foot, halfway up, on the hill top
## and on the arena plateau, then the sled run at the start, mid-run and near the bottom.
## Prints the penguin's screen position for each shot (it should hardly move).
## Run (windowed, it renders): Godot --path . res://tools/camera_capture.tscn -- --out=/abs/dir/

const SPOTS := [["foot", Vector3(-10.1, 0.1, -14.2)], ["stairs_mid", Vector3(-10.1, 2.4, -20.2)],
	["hill_top", Vector3(-13.2, 6.2, -30.4)], ["arena", Vector3(24.7, 1.6, -19.4)], ["plaza", Vector3(2.2, 0.1, 5.2)]]


func _ready() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(5.0).timeout
	await w.travel_to("town", "BusArrival")
	await get_tree().create_timer(3.0).timeout
	var p: CharacterBody3D = w.get_node("Penguin")
	for s in SPOTS:
		var space := p.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(s[1] + Vector3.UP * 2.0, s[1] + Vector3.DOWN * 3.0, 1))
		p.global_position = (hit.position if hit else s[1]) + Vector3.UP * 0.05
		p.velocity = Vector3.ZERO
		await get_tree().create_timer(2.5).timeout
		await _shot(w, p, out + "camera_town_%s.png" % s[0])
	await w.travel_to("sled_hill", "BusArrival")
	var t0 := Time.get_ticks_msec()
	for when in [[4.0, "start"], [8.0, "mid"], [13.0, "late"]]:
		while (Time.get_ticks_msec() - t0) / 1000.0 < when[0]:
			await get_tree().process_frame
		var room: Node = w.get_node("LocationHost").get_child(0)
		var rider := room.get_node_or_null("Sled") as Node3D
		await _shot(room, rider if rider else p, out + "camera_sled_%s.png" % when[1])
	get_tree().quit()


func _shot(root: Node, who: Node3D, path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var cam := get_viewport().get_camera_3d()
	var screen := cam.unproject_position(who.global_position) / Vector2(get_viewport().get_visible_rect().size)
	print("CAMERA %s penguin y=%.2f screen=(%.2f, %.2f)" % [path.get_file(), who.global_position.y, screen.x, screen.y])
	get_viewport().get_texture().get_image().save_png(path)
