extends Node
## Renders the eight emote picker thumbnails (res://ui/emotes/<clip>.png) from the real
## anim_emotes clips, frozen at each clip's most readable moment.
const PEAK := {"emote_wave": 0.45, "emote_cheer": 0.5, "emote_laugh": 0.3, "emote_dance": 0.25, "emote_shy": 0.55,
	"emote_sleepy": 0.5, "emote_surprised": 0.3, "emote_happy_bounce": 0.45}


func _ready() -> void:
	for clip in PEAK:
		var p := PenguinPreview.new(Vector2i(240, 240), Color("#2B4C8C"))
		p.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(p)
		p._camera.look_at_from_position(Vector3(0.0, 0.6, 2.35), Vector3(0, 0.45, 0), Vector3.UP)
		p.bird.rotation.y = deg_to_rad(-12)
		AssetPack.add_emotes(p.player)
		if p.player.has_animation(clip):
			p.player.play(clip)
			p.player.seek(p.player.current_animation_length * PEAK[clip], true)
			p.player.pause()
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		p.viewport.get_texture().get_image().save_png("res://ui/emotes/%s.png" % clip)
		print("EMOTE ", clip)
		p.queue_free()
	get_tree().quit()
