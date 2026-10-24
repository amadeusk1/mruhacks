extends Node
## See-through check. Walks the penguin (click-to-walk) along the town's paths past benches,
## lamps, fences and signs, then behind the cinema, the cafe and a fir grove, and counts the
## frames where the outline shows and where the see-through circle is open. Saves a frame every
## 0.5 s of the "behind" walks. Run windowed: Godot --path . res://tools/occlusion_check.tscn -- --out=/abs/dir/

const PATHS := [["BusArrival", "CafeDoor"], ["BusArrival", "ArcadeDoor"], ["BusArrival", "HomesGate"], ["BusArrival", "SketchEntry"],
	["BusArrival", "CourtEntry"], ["BusArrival", "LighthouseDoor"]]
const BEHIND := [["behind_cinema", Vector3(0.0, 0.0, -27.0)], ["behind_cafe", Vector3(-9.0, 0.0, -17.0)], ["fir_grove", Vector3(13.6, 0.0, 26.0)]]


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
	var fader := w.find_child("*Occlusion*", true, false)
	if fader == null:
		for n in w.get_node("CameraRig").get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("occlusion_fader.gd"):
				fader = n
	var town: Node = w.get_node("LocationHost").get_child(0)
	var map := p.get_world_3d().navigation_map
	var total := 0
	var shown := 0
	for r in PATHS:
		await w.shift_to_marker(r[0])
		await get_tree().create_timer(0.3).timeout
		var goal := NavigationServer3D.map_get_closest_point(map, (town.find_child(r[1], true, false) as Node3D).global_position)
		p.command_walk_to(goal)
		var t := 0.0
		while t < 20.0 and p.get("_click_active"):
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			total += 1
			if float(fader.get("_sil_alpha")) > 0.0:
				shown += 1
	print("OCCLUSION paths: outline on %d of %d frames" % [shown, total])
	for b in BEHIND:
		await w.shift_to_marker("BusArrival")
		await get_tree().create_timer(0.3).timeout
		p.command_walk_to(NavigationServer3D.map_get_closest_point(map, b[1]))
		var t := 0.0
		var frames := 0
		var open := 0
		var sil := 0
		var next_shot := 0.0
		var k := 0
		while t < 25.0 and p.get("_click_active"):
			await get_tree().process_frame
			t += get_process_delta_time()
			frames += 1
			if not (fader.get("_fading") as Dictionary).is_empty():
				open += 1
			if float(fader.get("_sil_alpha")) > 0.0:
				sil += 1
			if t >= next_shot and t > 2.0:
				next_shot = t + 0.5
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out + "occlusion_%s_%02d.png" % [b[0], k])
				k += 1
		print("OCCLUSION %s: see-through open %d of %d frames, outline %d" % [b[0], open, frames, sil])
	get_tree().quit()
