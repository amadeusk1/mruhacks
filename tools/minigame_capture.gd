extends Node
## Screenshots of the sled hill and the arcade for review (windowed, it renders):
##   Godot --path . res://tools/minigame_capture.tscn -- --out=/abs/dir/ --what=sled|arcade
var out := "/tmp/"
var what := "sled"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--what="): what = a.trim_prefix("--what=")
	if what == "sled":
		await _sled()
	get_tree().quit()


func _sled() -> void:
	var run: Node = load("res://scenes/sled_run.tscn").instantiate()
	add_child(run)
	await get_tree().create_timer(1.0).timeout
	await _save("sled_start")
	await get_tree().create_timer(4.5).timeout
	await _save("sled_run_a")
	await get_tree().create_timer(4.0).timeout
	await _save("sled_run_b")


func _save(name: String) -> void:
	for f in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("SAVED ", name)
