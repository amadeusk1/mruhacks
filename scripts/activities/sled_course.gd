class_name SledCourse
extends RefCounted
## The Sled Hill race course as data: a downhill spline with S-bends, sampled every metre.
## Shared by the scene (mesh, props) and the server (progress / checkpoint checks), so both agree
## on where the course is without loading any scene. Course space = the sled_run room's space.

const WIDTH := 10.0          ## groomed track, banks rise beyond +-WIDTH/2
const GRADE := 0.15          ## drop per metre along the course
const STEP := 1.0
## Hand-placed centreline (x, z). The start gate sits at s ~ 8, the run-out is flat.
const POINTS := [Vector2(0, 26), Vector2(0, 6), Vector2(3, -34), Vector2(14, -74), Vector2(11, -112),
	Vector2(-7, -150), Vector2(-15, -190), Vector2(-5, -230), Vector2(9, -268), Vector2(8, -306),
	Vector2(0, -340), Vector2(0, -372)]
const START_S := 22.0        ## start line; the grid lines up just behind it
const RUNOUT := 34.0         ## flat stretch after the finish
const CHECKPOINTS := [80.0, 150.0, 220.0, 290.0]
## Features: [s, lateral, kind]. Kinds: boost pad, ramp (full width), tree / rock hazards.
const FEATURES := [
	[48.0, 2.6, "rock"], [62.0, -1.8, "boost"], [96.0, -2.9, "tree"], [112.0, 0.0, "ramp"],
	[132.0, 2.4, "boost"], [140.0, 3.1, "tree"], [168.0, -0.6, "rock"], [186.0, -2.6, "boost"],
	[204.0, 3.0, "rock"], [236.0, 0.0, "ramp"], [258.0, -3.0, "tree"], [270.0, 2.2, "boost"],
	[304.0, 0.8, "rock"], [318.0, -2.0, "boost"],
]

static var _pts: PackedVector3Array
static var _len := 0.0


## Every-metre samples of the centreline, y included (built once).
static func samples() -> PackedVector3Array:
	if _pts.is_empty():
		_build()
	return _pts


static func length() -> float:
	samples()
	return _len


static func finish_s() -> float:
	return length() - RUNOUT


static func height_at(s: float) -> float:
	var flat_from := length() - RUNOUT + 6.0
	return -GRADE * minf(s, flat_from) - GRADE * 0.25 * maxf(0.0, s - flat_from)


## Centreline point at distance s (lateral metres to the course's right).
static func point(s: float, lateral := 0.0) -> Vector3:
	var p := samples()
	var f := clampf(s / STEP, 0.0, float(p.size() - 1))
	var i := mini(int(f), p.size() - 2)
	var c := p[i].lerp(p[i + 1], f - float(i))
	return c + right(s) * lateral + Vector3.UP * dish(lateral)


static func forward(s: float) -> Vector3:
	var p := samples()
	var i := clampi(int(s / STEP), 0, p.size() - 2)
	var d := p[i + 1] - p[i]
	d.y = 0.0
	return d.normalized()


static func right(s: float) -> Vector3:
	var f := forward(s)
	return Vector3(-f.z, 0.0, f.x)


## Yaw that faces down the course (Godot: -Z forward).
static func yaw(s: float) -> float:
	var f := forward(s)
	return atan2(-f.x, -f.z)


## Slight half-pipe: the track edges sit a little higher than the middle.
static func dish(lateral: float) -> float:
	var u := clampf(absf(lateral) / (WIDTH * 0.5), 0.0, 1.0)
	return 0.3 * u * u


## Distance along the course of the nearest centreline sample, and the signed lateral offset.
## hint narrows the search to around the last known s (server: per racer).
static func locate(at: Vector3, hint := -1.0) -> Vector2:
	var p := samples()
	var lo := 0
	var hi := p.size() - 1
	if hint >= 0.0:
		lo = clampi(int(hint / STEP) - 30, 0, p.size() - 1)
		hi = clampi(int(hint / STEP) + 30, 0, p.size() - 1)
	var best := lo
	var best_d := INF
	for i in range(lo, hi + 1):
		var d := Vector2(p[i].x - at.x, p[i].z - at.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	var s := float(best) * STEP
	var off := at - p[best]
	return Vector2(s, off.dot(right(s)))


static func _build() -> void:
	var dense: Array[Vector2] = []
	for i in POINTS.size() - 1:
		var p0: Vector2 = POINTS[maxi(i - 1, 0)]
		var p1: Vector2 = POINTS[i]
		var p2: Vector2 = POINTS[i + 1]
		var p3: Vector2 = POINTS[mini(i + 2, POINTS.size() - 1)]
		for k in 40:
			var t := float(k) / 40.0
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	dense.append(POINTS[-1])
	# resample by arc length
	var out := PackedVector3Array()
	var acc := 0.0
	var next := 0.0
	for i in dense.size() - 1:
		var a: Vector2 = dense[i]
		var b: Vector2 = dense[i + 1]
		var seg := a.distance_to(b)
		while next <= acc + seg:
			var q := a.lerp(b, (next - acc) / maxf(seg, 0.0001))
			out.append(Vector3(q.x, 0.0, q.y))
			next += STEP
		acc += seg
	_len = float(out.size() - 1) * STEP
	_pts = out
	for i in _pts.size():
		_pts[i].y = height_at(float(i) * STEP)
