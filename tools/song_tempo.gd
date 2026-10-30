extends SceneTree

## Beat-tracks the dance floor songs and writes scripts/world/dance_tracks.gd (song lengths and
## every beat time), so the floor lights and the penguins' dance follow the real music.
## Decodes each song offline, builds a kick-band onset envelope, finds the tempo from the
## autocorrelation four bars out, then places each beat with dynamic programming (Ellis 2007),
## which follows small drifts and keeps the grid through drumless intros.
##   Godot --headless --path . -s res://tools/song_tempo.gd                 report every candidate
##   Godot --headless --path . -s res://tools/song_tempo.gd -- --write A1 A2  write those songs
## A song whose candidate tempos score close together (a 4:3 or half-time feel) needs a listen
## before it goes in: the report prints the scores.

const DIR := "res://audio/music/"
const OUT := "res://scripts/world/dance_tracks.gd"
const PREFIX := "dance floor "
const HOP := 256
const MIN_BPM := 85.0
const MAX_BPM := 170.0
const TIGHTNESS := 100.0  # how hard the beat tracker holds the tempo against stray onsets


func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var write := args.has("--write")
	args.erase("--write")
	var names := []
	if args.is_empty():
		for f in DirAccess.get_files_at(DIR):
			if f.begins_with(PREFIX) and f.ends_with(".mp3"):
				names.append(f)
	else:
		for a in args:
			names.append("%s%s.mp3" % [PREFIX, a])
	var rows := []
	for n in names:
		var row := _measure(str(n))
		if not row.is_empty():
			rows.append(row)
	if write:
		_write(rows)
	quit()


func _measure(name: String) -> Dictionary:
	var stream := load(DIR + name) as AudioStream
	if stream == null:
		print("TEMPO %s: can't load" % name)
		return {}
	var rate := AudioServer.get_mix_rate()
	var fps := rate / HOP
	var on := _onsets(stream, rate)
	var best_lag := 0
	var best := -1.0
	for lag in range(int(fps * 60.0 / MAX_BPM), int(fps * 60.0 / MIN_BPM) + 1):
		var s := _ac(on, lag)
		if s > best:
			best = s
			best_lag = lag
	var coarse := 60.0 * fps / best_lag
	var cands := []
	var pick := [coarse, 0.0, -1.0]
	for c in [coarse * 0.75, coarse, coarse * 4.0 / 3.0]:
		var f := _fine(on, c, fps)
		cands.append("%.1f:%.3f" % [f[0], f[2]])
		if f[2] > pick[2]:
			pick = f
	var beats := _track(on, fps * 60.0 / pick[0])
	var times := []
	for b in beats:
		times.append(snappedf(b / fps, 0.001))
	print("TEMPO %s: bpm=%.2f beats=%d first=%.3f s length=%.2f s  candidates %s" % [
		name, pick[0], times.size(), times[0] if not times.is_empty() else -1.0, stream.get_length(), " ".join(cands)])
	return {"file": name, "length": snappedf(stream.get_length(), 0.001), "bpm": snappedf(pick[0], 0.01), "beats": times}


## Kick-band onset strength per HOP frames: the rise in log energy, minus its mean.
func _onsets(stream: AudioStream, rate: float) -> PackedFloat32Array:
	var pb := stream.instantiate_playback()
	pb.start(0.0)
	var env := PackedFloat32Array()
	var total := int(stream.get_length() * rate)
	var done := 0
	var lp := 0.0
	var k := 1.0 - exp(-TAU * 150.0 / rate)
	while done < total:
		var chunk: PackedVector2Array = pb.mix_audio(1.0, HOP)
		if chunk.is_empty():
			break
		var e := 0.0
		for f in chunk:
			lp += k * ((f.x + f.y) * 0.5 - lp)
			e += lp * lp
		env.append(log(1e-6 + e / chunk.size()))
		done += chunk.size()
	var on := PackedFloat32Array()
	on.resize(env.size())
	for i in range(1, env.size()):
		on[i] = maxf(0.0, env[i] - env[i - 1])
	var mean := 0.0
	for v in on:
		mean += v
	mean /= maxf(1.0, on.size())
	var sd := 0.0
	for i in on.size():
		on[i] = maxf(0.0, on[i] - mean)
		sd += on[i] * on[i]
	sd = sqrt(sd / maxf(1.0, on.size()))
	for i in on.size():
		on[i] /= maxf(sd, 1e-6)
	return on


func _ac(on: PackedFloat32Array, lag: int) -> float:
	var s := 0.0
	for i in range(lag, on.size()):
		s += on[i] * on[i - lag]
	return s / (on.size() - lag)


## Tempo from the autocorrelation peak 16 beats out (four bars), which pins the period 16x finer
## than the one-beat lag, and how well a beat grid at that tempo lands on onsets: [bpm, phase s, score].
func _fine(on: PackedFloat32Array, bpm: float, fps: float) -> Array:
	var lag := fps * 60.0 / bpm * 16.0
	var lo := int(lag * 0.97)
	var hi := int(lag * 1.03) + 1
	var scores := {}
	var peak := lo
	for l in range(lo - 1, hi + 2):
		scores[l] = _ac(on, l)
		if l >= lo and l <= hi and float(scores[l]) > float(scores[peak]):
			peak = l
	var a: float = scores[peak - 1]
	var b: float = scores[peak]
	var c: float = scores[peak + 1]
	var shift := 0.5 * (a - c) / (a - 2.0 * b + c) if absf(a - 2.0 * b + c) > 1e-9 else 0.0
	var period := (peak + shift) / 16.0
	var r := _best_phase(on, period)
	return [60.0 * fps / period, r[0] / fps, r[1]]


## [phase in envelope frames, mean onset on the grid] for a beat grid of `period` frames.
func _best_phase(on: PackedFloat32Array, period: float) -> Array:
	var best := [0.0, -1.0]
	for p in 32:
		var phase := period * p / 32.0
		var s := 0.0
		var t := phase
		var n := 0
		while t < on.size() - 1:
			var i := int(t)
			s += maxf(on[i], on[i + 1])
			t += period
			n += 1
		s /= maxf(1, n)
		if s > best[1]:
			best = [phase, s]
	return best


## Dynamic-programming beat tracker: each frame's best score is its onset plus the best earlier
## beat 0.5-2 periods back, penalised by how far that gap is from the period. Beats in frames.
func _track(on: PackedFloat32Array, period: float) -> Array:
	var n := on.size()
	var score := PackedFloat32Array()
	score.resize(n)
	var back := PackedInt32Array()
	back.resize(n)
	for t in n:
		var best := 0.0
		var from := -1
		for p in range(maxi(0, t - int(period * 2.0)), maxi(0, t - int(period * 0.5)) + 1):
			if p >= t:
				break
			var gap := log(float(t - p) / period)
			var s := score[p] - TIGHTNESS * gap * gap
			if from < 0 or s > best:
				best = s
				from = p
		score[t] = on[t] + (best if from >= 0 else 0.0)
		back[t] = from
	var end := n - 1
	for t in range(maxi(0, n - int(period)), n):
		if score[t] > score[end]:
			end = t
	var beats := []
	var t := end
	while t >= 0:
		beats.push_front(t)
		t = back[t]
	return beats


func _write(rows: Array) -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_line("class_name DanceTracks")
	f.store_line("extends RefCounted")
	f.store_line("")
	f.store_line("## The dance floor songs in play order: file in audio/music, length and every beat time")
	f.store_line("## (seconds). Generated by tools/song_tempo.gd -- --write; do not edit by hand.")
	f.store_line("")
	f.store_line("const TRACKS := [")
	for r in rows:
		var beats := ", ".join((r["beats"] as Array).map(func(b): return "%.3f" % b))
		f.store_line("\t{\"file\": \"%s\", \"length\": %.3f, \"bpm\": %.2f, \"beats\": [%s]}," % [r["file"], r["length"], r["bpm"], beats])
	f.store_line("]")
	print("WROTE %s (%d songs)" % [OUT, rows.size()])
