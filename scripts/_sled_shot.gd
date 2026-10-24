extends SceneTree


func _initialize() -> void:
	var run := (load("res://scenes/sled_run.tscn") as PackedScene).instantiate()
	root.add_child(run)
	root.size = Vector2i(1280, 720)
	for _i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("c:/Users/User/Desktop/mruhacks/sled_preview.png")
	print("saved ", image.get_width(), "x", image.get_height())
	quit()
