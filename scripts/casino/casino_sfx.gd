class_name CasinoSfx
extends RefCounted
## Small synthesized casino sounds (the repo has no sfx files yet): chip clack, card flick,
## wheel tick, ball drop, lever ratchet, win jingle, lose blip. Generated once, then cached.

const RATE := 22050
static var _cache := {}


static func play(host: Node, kind: String, volume_db := -6.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream(kind)
	p.volume_db = volume_db
	if AudioServer.get_bus_index("SFX") >= 0:
		p.bus = "SFX"
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _make(kind)
	return _cache[kind]


static func _make(kind: String) -> AudioStreamWAV:
	var s := []  # plain Array: shared by reference with the helpers below
	match kind:
		"chip":   # two quick ceramic clacks
			_click(s, 0.0, 0.035, 3200.0, 0.8)
			_click(s, 0.05, 0.03, 2700.0, 0.55)
		"card":   # papery flick: short filtered noise
			_noise(s, 0.0, 0.06, 0.45, 0.35)
		"tick":
			_click(s, 0.0, 0.012, 4200.0, 0.35)
		"drop":   # ball settling into a pocket
			_click(s, 0.0, 0.03, 1800.0, 0.6)
			_click(s, 0.07, 0.025, 1500.0, 0.4)
			_click(s, 0.12, 0.02, 1300.0, 0.25)
		"lever":
			for i in 6:
				_click(s, i * 0.045, 0.02, 1100.0 + i * 120.0, 0.5)
		"reel_stop":
			_click(s, 0.0, 0.05, 520.0, 0.7)
		"win":    # rising major arpeggio
			for i in 4:
				_tone(s, i * 0.09, 0.22, [523.25, 659.25, 783.99, 1046.5][i], 0.35)
		"big_win":
			for r in 2:
				for i in 4:
					_tone(s, r * 0.38 + i * 0.08, 0.2, [523.25, 659.25, 783.99, 1046.5][i] * (1.0 + r * 0.5), 0.32)
		"lose":
			_tone(s, 0.0, 0.18, 392.0, 0.3)
			_tone(s, 0.16, 0.28, 329.63, 0.3)
		_:
			_click(s, 0.0, 0.02, 2000.0, 0.4)
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _grow(s: Array, end_s: float) -> void:
	var n := int(end_s * RATE) + 1
	if s.size() < n:
		var old := s.size()
		s.resize(n)
		for i in range(old, n):
			s[i] = 0.0


static func _click(s: Array, at: float, dur: float, freq: float, amp: float) -> void:
	_grow(s, at + dur)
	var start := int(at * RATE)
	var n := int(dur * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 90.0)
		s[start + i] += (sin(TAU * freq * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * env * amp


static func _noise(s: Array, at: float, dur: float, amp: float, smooth: float) -> void:
	_grow(s, at + dur)
	var start := int(at * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		y = lerpf(randf() * 2.0 - 1.0, y, smooth)
		s[start + i] += y * amp * sin(PI * float(i) / n)


static func _tone(s: Array, at: float, dur: float, freq: float, amp: float) -> void:
	_grow(s, at + dur)
	var start := int(at * RATE)
	var n := int(dur * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 80.0) * exp(-t * 7.0)
		s[start + i] += (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * env * amp
