extends Node

## Screenshots the living town (noon / dusk / night) and the dance floor with a penguin on it,
## and prints a few checks. Needs a window (not --headless).
##   Godot --path . res://tools/living_shot.tscn -- --out=C:/some/dir

var _w: Node
var _p: CharacterBody3D


func _ready() -> void:
	var out := OS.get_environment("TEMP")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	await _w.travel_to("town", "BusArrival")
	await get_tree().create_timer(3.0).timeout
	var living: Node = get_tree().root.find_child("LivingTown", true, false)
	var floor_node: Node3D = null  # the layout also has a "DanceFloor" Marker3D: find the floor by class
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is DanceFloor:
			floor_node = n
	print("LIVING lamps=%d halos=%d lights=%d" % [living.get("_lamps").size(), living.get("_halos").size(), living.get("_pool").size()])
	print("LIVING dance floor at %s" % floor_node.global_position)
	var rect := living.get_node("AuroraLayer").get_child(0) as ColorRect
	print("LIVING aurora rect size=%s visible=%s" % [rect.size, rect.is_visible_in_tree()])
	for t in [0.5, 0.7, 0.745, 0.0]:
		LivingTown.hour_override = t
		await get_tree().create_timer(1.0).timeout
		print("LIVING hour=%.3f phase=%s aurora=%s" % [t, LivingTown.phase_name(t), (rect.material as ShaderMaterial).get_shader_parameter("strength")])
		_shot("%s/living_%03d.png" % [out, int(t * 1000)])
	# dancing: walk onto the floor and stand still
	_p.global_position = Vector3(floor_node.global_position.x - 4.0, floor_node.global_position.y + 0.1, floor_node.global_position.z)
	await get_tree().create_timer(0.5).timeout
	_p.global_position = Vector3(floor_node.global_position.x + 0.4, floor_node.global_position.y + 0.1, floor_node.global_position.z + 0.3)
	await get_tree().create_timer(1.6).timeout
	print("LIVING dancing=%s count=%d anim=%s music=%.2f" % [_p.call("is_dancing"), floor_node.call("dancer_count"), _p.get("_clips").current_animation, floor_node.get("_music").progress() if floor_node.get("_music") else 1.0])
	var dj := floor_node.get_node("DanceMusic") as AudioStreamPlayer
	var song: Array = DanceFloor.song_at(DanceFloor.clock()) if DanceFloor.songs_on else [-1, 0.0]
	print("LIVING dance songs=%s song=%d playing=%s stream=%s pos=%.2f clock_pos=%.2f beat=%.2f beat_s=%.3f vol=%.1f" % [DanceFloor.songs_on, song[0], dj.playing,
		dj.stream.resource_path.get_file() if dj.stream else "-", dj.get_playback_position(), song[1], DanceFloor.beat(), DanceFloor.beat_len(), dj.volume_db])
	LivingTown.hour_override = 0.0
	await get_tree().create_timer(0.6).timeout
	_shot("%s/dance_night.png" % out)
	LivingTown.hour_override = 0.5
	await get_tree().create_timer(0.6).timeout
	_shot("%s/dance_day.png" % out)
	# the dance clip stays locked to the shared beat
	var anim: Animation = _p.get("_clips").get_animation(_p.get("_clips").current_animation)
	var want := fposmod(DanceFloor.beat(), 4.0) / 4.0 * anim.length
	var have: float = _p.get("_clips").current_animation_position
	print("LIVING clip pos %.2f want %.2f (len %.2f)" % [have, want, anim.length])
	_p.global_position += Vector3(5.0, 0, 0)
	await get_tree().create_timer(0.6).timeout
	print("LIVING after leaving: dancing=%s count=%d" % [_p.call("is_dancing"), floor_node.call("dancer_count")])
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw  # otherwise a stale frame comes back
	get_viewport().get_texture().get_image().save_png(path)
