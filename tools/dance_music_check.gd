extends SceneTree

## Renders the dance track and reports timing, level and loop seam. Godot -s res://tools/dance_music_check.gd --headless

func _init() -> void:
	var m := DanceMusic.new()
	var t0 := Time.get_ticks_msec()
	var slices := 0
	while not m.step(3000):
		slices += 1
	var ms := Time.get_ticks_msec() - t0
	var s := m.stream()
	var d := s.data
	var peak := 0
	var sq := 0.0
	var n := d.size() / 2
	for i in n:
		var v := d.decode_s16(i * 2)
		peak = maxi(peak, absi(v))
		sq += float(v) * float(v)
	print("MUSIC frames=%d len=%.2fs render=%d ms in %d slices (3 ms each)" % [n, float(n) / DanceMusic.RATE, ms, slices])
	print("MUSIC peak=%d (%.2f of full scale) rms=%.0f seam first=%d last=%d" % [peak, peak / 32767.0, sqrt(sq / n), d.decode_s16(0), d.decode_s16((n - 1) * 2)])
	quit()
