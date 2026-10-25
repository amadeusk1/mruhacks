extends Node
## Review shots of the stream, falls, cove, houseboat, fishing docks and string-light poles: gameplay-camera angle and a
## low close angle per spot, plus a penguin fishing from every FishingSpot marker (bobber visible).
## Run (windowed, it renders): Godot --path . res://tools/water_capture.tscn -- --out=/abs/dir/ --tag=before
const SPOTS := {
	"spring": Vector3(15.4, 0.6, -31.0), "stream_north": Vector3(16.6, 0, -19.0), "stream_bend": Vector3(17.0, 0, -9.0),
	"bridge": Vector3(13.3, 0, 0.2), "stream_south": Vector3(9.0, 0, 14.0), "mouth": Vector3(7.8, -0.5, 25.0),
	"houseboat": Vector3(-21.0, 0, 30.6), "docks": Vector3(-18.0, 0, 21.0),
	"lights_west": Vector3(-10.1, 1.2, 0.0), "lights_cinema": Vector3(0.0, 1.2, -19.3),   # string-light spans on their poles
}


func _ready() -> void:
	var out := "user://"
	var tag := "now"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=")  # comma list of spot names, or "fish"
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	var cam: Camera3D = w.get_node("CameraRig/Camera3D")
	(w.get_node("CameraRig") as Node3D).set_process(false)
	for c in w.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam.far = 300.0
	for k in SPOTS:
		if only != "" and not only.split(",").has(k):
			continue
		var t: Vector3 = SPOTS[k]
		for v in [["game", Vector3(0, 13, 13)], ["low", Vector3(-4, 4.5, 7)], ["top", Vector3(0, 24, 0.5)]]:
			cam.global_position = t + v[1]
			cam.look_at(t, Vector3.UP)
			await _save("%swater_%s_%s_%s.png" % [out, k, v[0], tag])
	# fishing: plant the penguin at each rail, cast, and look over its shoulder at the bobber
	var p: Node3D = w.get_node("Penguin")
	var i := 0
	if only != "" and not only.split(",").has("fish"):
		get_tree().quit()
		return
	for spot in get_tree().get_nodes_in_group("fish_spot"):
		if not spot.is_inside_tree() or not spot.get_parent().is_visible_in_tree():
			continue
		get_viewport().gui_release_focus()  # a focused chat box or the intro lock blocks plant_fish
		p.set("_input_locked", false)
		p.set("_typing_locked", false)
		if not p.call("plant_fish", spot, spot.call("stand_point"), spot.global_rotation.y + PI * 0.5):
			print("PLANT FAILED ", spot.name)
		p.call("set_fish_phase", "wait")
		await get_tree().create_timer(0.6).timeout
		var fwd := -p.global_basis.z
		cam.global_position = p.global_position - fwd * 3.0 + Vector3(1.2, 2.6, 0)
		cam.look_at(p.global_position + fwd * 1.8 + Vector3(0, -0.3, 0), Vector3.UP)
		await _save("%swater_fish%d_%s.png" % [out, i, tag])
		p.call("set_fish_phase", "")
		i += 1
	get_tree().quit()


func _save(path: String) -> void:
	for f in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SAVED ", path.get_file())
