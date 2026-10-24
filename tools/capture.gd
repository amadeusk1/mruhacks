extends Node
## Dev screenshot harness: starts the world solo, waits for the town, then saves the gameplay
## view plus two overviews. Run: Godot --path . res://tools/capture.tscn -- --out=/abs/dir/
func _ready() -> void:
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var cam: Camera3D = w.get_node("CameraRig/Camera3D")
	print("CAPTURE loc=", w.call("current_location_id"), " penguin=", w.get_node("Penguin").global_position)
	await _shot(out + "game_play.png")
	var rig: Node3D = w.get_node("CameraRig")
	rig.set_process(false)
	for v in [["game_overview.png", Vector3(0, 0, 4), Vector3(0, 30, 26)], ["game_side.png", Vector3(0, 0, -2), Vector3(-22, 14, 14)]]:
		cam.global_position = v[1] + v[2]
		cam.look_at(v[1], Vector3.UP)
		await _shot(out + v[0])
	get_tree().quit()
func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SAVED ", path)
