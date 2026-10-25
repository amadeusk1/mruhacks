class_name Sfx
extends RefCounted
## One-shot minigame sounds from audio/sfx (made by tools/gen_sfx.py), on the SFX bus so the
## Settings "effects" slider applies. Sfx.play(self, "coin"); Sfx.loop(self, "slide_loop").


static func play(owner: Node, sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if owner == null or not owner.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound)
	if p.stream == null:
		p.free()
		return
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	owner.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## A looping player the caller keeps (and frees with itself); volume/pitch are driven per frame.
static func loop(owner: Node, sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := _stream(sound)
	if s is AudioStreamWAV:
		s = (s as AudioStreamWAV).duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = (s as AudioStreamWAV).data.size() / 2
	p.stream = s
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	owner.add_child(p)
	return p


static func _stream(sound: String) -> AudioStream:
	var path := "res://audio/sfx/%s.wav" % sound
	return load(path) as AudioStream if ResourceLoader.exists(path) else null
