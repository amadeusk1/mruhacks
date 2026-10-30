extends Node

## Writes the activity songs into audio/music. Same family as the town tracks:
## instrumental, major, plucky FM / soft bells / muted-guitar tones, light bit-crush, a short room.
## Two tunes each, so the playlist can move on without repeating.
## Rebuild: godot --path . res://tools/song_build.tscn -- --songs

const RATE := 22050
const BARS := 16
const STEPS := [0, 2, 4, 5, 7, 9, 11]
const PROG := [[0, 2, 4], [4, 6, 8], [5, 7, 9], [3, 5, 7]]
const SPECS := [
	{"id": "fishing", "bpm": 90, "root": 146.83, "drums": "sway", "lead": "bell", "pad": true, "oct": 2,
		"a": [0, 2, 4, 7, 4, 2, 0, 4], "b": [7, 4, 2, 0, 2, 4, 2, 0]},
	{"id": "sled", "bpm": 128, "root": 196.0, "drums": "rush", "lead": "pluck", "pad": false, "oct": 1,
		"a": [0, 0, 4, 7, 9, 7, 4, 2], "b": [7, 9, 7, 4, 2, 4, 0, 0]},
	{"id": "basketball", "bpm": 114, "root": 130.81, "drums": "bounce", "lead": "pluck", "pad": false, "oct": 1,
		"a": [4, 4, 2, 4, 7, 4, 2, 0], "b": [0, 2, 4, 7, 4, 7, 9, 7]},
	{"id": "sketch", "bpm": 82, "root": 174.61, "drums": "none", "lead": "guitar", "pad": true, "oct": 1,
		"a": [0, -1, 2, -1, 4, -1, 2, -1], "b": [4, -1, 5, -1, 4, -1, 2, 0]},
	{"id": "cinema", "bpm": 76, "root": 116.54, "drums": "soft", "lead": "bell", "pad": true, "oct": 2,
		"a": [0, -1, 2, -1, 4, -1, 2, -1], "b": [4, -1, 5, -1, 4, -1, 0, -1]},
	{"id": "casino", "bpm": 118, "root": 220.0, "drums": "bounce", "lead": "bell", "pad": false, "oct": 1,
		"a": [4, 7, 4, 2, 4, 9, 7, 4], "b": [7, 4, 2, 0, 2, 4, 7, 4]},
	{"id": "cafe", "bpm": 96, "root": 164.81, "drums": "soft", "lead": "guitar", "pad": true, "oct": 1,
		"a": [0, 2, 4, 5, 4, 2, 0, 2], "b": [4, 2, 0, -1, 2, 4, 5, 4]},
	{"id": "home", "bpm": 74, "root": 130.81, "drums": "none", "lead": "bell", "pad": true, "oct": 2,
		"a": [0, -1, 4, -1, 2, -1, 0, -1], "b": [4, -1, 5, -1, 4, -1, 0, -1]},
]

var _rng := 2463534242


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--songs"):
		return
	for spec in SPECS:
		for variant in 2:
			var file := "%s.wav" % spec["id"] if variant == 0 else "%s 2.wav" % spec["id"]
			var path := ProjectSettings.globalize_path("res://audio/music/%s" % file)
			_write(path, _mix(spec, variant))
			print("SONG %s" % file)
	get_tree().quit(0)


func _mix(spec: Dictionary, variant: int) -> PackedFloat32Array:
	var bpm := float(spec["bpm"])
	var beat := 60.0 / bpm
	var eighth := beat * 0.5
	var root := float(spec["root"]) * (1.5 if variant == 1 else 1.0)
	var buf := PackedFloat32Array()
	buf.resize(int(BARS * 4.0 * beat * RATE))
	var motif_a: Array = (spec["b"] if variant == 1 else spec["a"]).duplicate()
	var motif_b: Array = (spec["a"] if variant == 1 else spec["b"]).duplicate()
	if variant == 1:
		motif_a.reverse()
		motif_b.reverse()
	var swing := 0.16 if spec["lead"] == "guitar" or spec["drums"] == "sway" else 0.0
	var lead_amp := 0.2 if spec["lead"] == "bell" else 0.24
	for bar in BARS:
		var chord: Array = PROG[(bar + (2 if variant == 1 else 0)) % 4]
		var tbar := bar * 4.0 * beat
		if spec["pad"]:
			for degree in chord:
				_add(buf, tbar, beat * 4.0, 0.045, "pad", _hz(root, int(degree)))
		_add(buf, tbar, 0.28, 0.34, "bass", _hz(root, int(chord[0]) - 7))
		if spec["drums"] in ["bounce", "rush"]:
			_add(buf, tbar + beat * 2.0, 0.22, 0.22, "bass", _hz(root, int(chord[0]) - 7))
		else:
			_add(buf, tbar + beat * 2.0, 0.26, 0.2, "bass", _hz(root, int(chord[0]) - 7))
		var motif: Array = motif_a if (bar / 2) % 2 == 0 else motif_b
		for k in motif.size():
			var degree := int(motif[k])
			if degree < 0:
				continue
			var when := tbar + k * eighth
			if k % 2 == 1:
				when += eighth * swing
			var dur := eighth * (1.7 if spec["lead"] == "bell" else 1.25)
			_add(buf, when, dur, lead_amp, str(spec["lead"]), _hz(root, degree + int(spec["oct"]) * 7))
	_drums(buf, beat, str(spec["drums"]))
	_room(buf, 0.1 if spec["pad"] else 0.16)
	_fade(buf)
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := 0.82 / peak
	for i in buf.size():
		buf[i] *= gain
	return buf


func _drums(buf: PackedFloat32Array, beat: float, kind: String) -> void:
	if kind == "none":
		return
	var beats := BARS * 4
	for b in beats:
		var t := b * beat
		match kind:
			"sway":
				if b % 4 == 0:
					_add(buf, t, 0.16, 0.28, "kick", 0.0)
				if b % 2 == 1:
					_add(buf, t, 0.04, 0.05, "hat", 0.0)
			"soft":
				if b % 4 == 0:
					_add(buf, t, 0.14, 0.16, "kick", 0.0)
				if b % 2 == 1:
					_add(buf, t, 0.04, 0.035, "hat", 0.0)
			"bounce":
				_add(buf, t, 0.14, 0.4, "kick", 0.0)
				if b % 2 == 1:
					_add(buf, t, 0.08, 0.16, "clap", 0.0)
				_add(buf, t + beat * 0.5, 0.03, 0.06, "hat", 0.0)
			"rush":
				_add(buf, t, 0.12, 0.36, "kick", 0.0)
				if b % 2 == 1:
					_add(buf, t, 0.07, 0.12, "clap", 0.0)
				_add(buf, t + beat * 0.25, 0.02, 0.04, "hat", 0.0)
				_add(buf, t + beat * 0.5, 0.02, 0.045, "hat", 0.0)
				_add(buf, t + beat * 0.75, 0.02, 0.04, "hat", 0.0)


func _add(buf: PackedFloat32Array, t: float, dur: float, amp: float, kind: String, hz: float) -> void:
	var i0 := int(t * RATE)
	if i0 >= buf.size():
		return
	var n := mini(int(dur * RATE), buf.size() - i0)
	var hold := 0.0
	var crush := 3 if kind == "pluck" else 1
	for i in n:
		if i % crush == 0:
			hold = _voice(kind, hz, float(i) / float(RATE), dur)
		buf[i0 + i] += hold * amp


func _voice(kind: String, hz: float, te: float, dur: float) -> float:
	match kind:
		"kick":
			return sin(TAU * (52.0 * te + 3.4 * (1.0 - exp(-26.0 * te)))) * exp(-te * 11.0)
		"hat":
			return _noise() * exp(-te * 70.0)
		"clap":
			return _noise() * exp(-te * 22.0) * minf(te * 800.0, 1.0)
		"bass":
			var env := exp(-te * 4.2) * minf(te * 400.0, 1.0)
			return (sin(TAU * hz * te) * 0.75 + sin(TAU * hz * 2.0 * te) * 0.2) * env
		"pluck":
			var mod := sin(TAU * hz * 2.0 * te) * exp(-te * 8.0) * 2.4
			return sin(TAU * hz * te + mod) * exp(-te * 5.5) * minf(te * 500.0, 1.0)
		"guitar":
			var gmod := sin(TAU * hz * te) * exp(-te * 6.0) * 1.1
			return sin(TAU * hz * te + gmod) * exp(-te * 3.4) * minf(te * 350.0, 1.0)
		"bell":
			var s := sin(TAU * hz * te) * exp(-te * 2.2)
			s += sin(TAU * hz * 2.01 * te) * exp(-te * 3.0) * 0.28
			return s * minf(te * 400.0, 1.0)
		"pad":
			var attack := clampf(te / 0.4, 0.0, 1.0)
			var release := clampf((dur - te) / 0.45, 0.0, 1.0)
			return (sin(TAU * hz * te) + sin(TAU * hz * 1.004 * te)) * 0.5 * attack * release
	return 0.0


func _room(buf: PackedFloat32Array, mix: float) -> void:
	var dry := buf.duplicate()
	for tap in [[0.09, 0.2], [0.15, 0.12], [0.21, 0.07]]:
		var delay := int(float(tap[0]) * RATE)
		var gain := float(tap[1]) * mix / 0.16
		for i in range(delay, buf.size()):
			buf[i] += dry[i - delay] * gain


func _fade(buf: PackedFloat32Array) -> void:
	var n := mini(int(0.02 * RATE), buf.size() / 2)
	for i in n:
		var g := float(i) / float(n)
		buf[i] *= g
		buf[buf.size() - 1 - i] *= g


func _hz(root: float, degree: int) -> float:
	var oct := 0
	var d := degree
	while d < 0:
		d += 7
		oct -= 1
	while d >= 7:
		d -= 7
		oct += 1
	return root * pow(2.0, (float(STEPS[d]) + 12.0 * float(oct)) / 12.0)


func _noise() -> float:
	_rng ^= (_rng << 13) & 0xFFFFFFFF
	_rng ^= _rng >> 17
	_rng ^= (_rng << 5) & 0xFFFFFFFF
	return float(_rng) / 2147483648.0 - 1.0


func _write(path: String, samples: PackedFloat32Array) -> void:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		pcm.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_utf8_buffer())
	f.store_32(36 + pcm.size())
	f.store_buffer("WAVE".to_utf8_buffer())
	f.store_buffer("fmt ".to_utf8_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_utf8_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()
