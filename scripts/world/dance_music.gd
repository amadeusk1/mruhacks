class_name DanceMusic
extends RefCounted

## The dance floor's soundtrack, synthesised in code (no audio files, nothing to license):
## four-on-the-floor kick, off-beat hats, claps, a rolling bass and a chord arpeggio over
## Am - F - C - G. It renders a few milliseconds per frame so the town never hitches, then
## loops seamlessly. 120 BPM, 16 beats = exactly 8 s, so `fmod(unix_time, LOOP_S)` is the
## same song position on every client.

const RATE := 22050
const BPM := 120.0
const BEATS := 16
const BEAT_S := 60.0 / BPM
const LOOP_S := BEATS * BEAT_S

const ROOTS := [55.0, 43.65, 65.41, 49.0]
const CHORDS := [
	[220.0, 261.63, 329.63, 440.0],
	[174.61, 220.0, 261.63, 349.23],
	[261.63, 329.63, 392.0, 523.25],
	[196.0, 246.94, 293.66, 392.0],
]
const ARP := [0, 1, 2, 3, 2, 3, 1, 2]

var _frames := int(LOOP_S * RATE)
var _data := PackedByteArray()
var _i := 0
var _rng := 2463534242


func _init() -> void:
	_data.resize(_frames * 2)


func progress() -> float:
	return float(_i) / float(_frames)


func done() -> bool:
	return _i >= _frames


## Renders until `budget_us` microseconds have passed. True once the loop is complete.
func step(budget_us: int) -> bool:
	var deadline := Time.get_ticks_usec() + budget_us
	while _i < _frames:
		var end := mini(_i + 256, _frames)
		while _i < end:
			_data.encode_s16(_i * 2, int(clampf(_sample(_i), -1.0, 1.0) * 30000.0))
			_i += 1
		if Time.get_ticks_usec() >= deadline:
			break
	return done()


func stream() -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = _data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = _frames
	return s


func _noise() -> float:
	_rng ^= (_rng << 13) & 0xFFFFFFFF
	_rng ^= _rng >> 17
	_rng ^= (_rng << 5) & 0xFFFFFFFF
	return float(_rng) / 2147483648.0 - 1.0


func _sample(i: int) -> float:
	var pos := float(i) / float(RATE) / BEAT_S  # beats since the loop began
	var b := int(pos)
	var tb := (pos - float(b)) * BEAT_S
	var bar := (b >> 2) & 3
	var v := 0.0

	# kick: a sine that falls from ~160 Hz to 50 Hz, on every beat
	v += sin(TAU * (50.0 * tb + 3.6 * (1.0 - exp(-30.0 * tb)))) * exp(-tb * 13.0) * 0.85

	# eighth-note grid (bass and hats)
	var e8 := int(pos * 2.0)
	var te := (pos * 2.0 - float(e8)) * BEAT_S * 0.5
	if e8 % 2 == 1:
		v += _noise() * exp(-te * 70.0) * 0.16  # closed hat on the off-beat
	else:
		v += _noise() * exp(-te * 160.0) * 0.04
	var f: float = ROOTS[bar] * (2.0 if e8 % 2 == 1 else 1.0)
	var bass := (sin(TAU * f * te) * 0.6 + sin(TAU * f * 2.0 * te) * 0.18) * exp(-te * 6.5) * minf(te * 500.0, 1.0)
	v += bass * clampf(tb * 9.0, 0.3, 1.0) * 0.5  # ducks under the kick

	# clap on beats 2 and 4
	if b % 2 == 1:
		v += _noise() * exp(-tb * 24.0) * 0.28 * minf(tb * 900.0, 1.0)

	# arpeggio in sixteenths
	var s16 := int(pos * 4.0)
	var tl := (pos * 4.0 - float(s16)) * BEAT_S * 0.25
	var note: float = CHORDS[bar][ARP[s16 % 8]]
	var duty := 0.35 + 0.1 * sin(float(s16) * 0.7)
	var pulse := 1.0 if fposmod(note * tl, 1.0) < duty else -1.0
	v += pulse * exp(-tl * 10.0) * minf(tl * 400.0, 1.0) * 0.1

	return v * 0.7
