extends Node

## Rides Sled Hill like a player would, for follow bots and film hosts: at the start card it joins
## the race lobby (the Race button), and while racing it presses the same move_left / move_right
## actions as A and D (with partial strength), holding its grid lane with a slalom weave, taking
## the boost pads near its line and swerving around the trees and rocks ahead (SledCourse).
## After the podium it joins the next race.

const SWING := 1.3      # metres either side of the lane: wide enough to read on camera
const LOOK := 14.0      # metres of course it watches ahead
const CLEAR := 1.8      # hazard half-width plus the sled's
const PAD_REACH := 2.4  # leaves its lane for a boost pad this close to it
const EDGE := 3.9       # stay off the banks (the groomed track is +-5)
const JOIN_AFTER := 1.5

var period := 1.6       # seconds per swing; give each pilot its own
var phase := 0.0        # radians; so pilots don't swing in step

var _lane := 0.0
var _t := 0.0
var _idle_for := 0.0
var _last_lat := 0.0


func _physics_process(delta: float) -> void:
	var room := get_tree().get_first_node_in_group("activity")
	if room == null or room.get("sled") == null or room.get("_state") == null:
		_steer(0.0)
		return
	var sled: Node3D = room.get("sled")
	var state := str(room.get("_state"))
	if state in ["menu", "results"]:
		_steer(0.0)
		_idle_for += delta
		if _idle_for >= JOIN_AFTER:
			_idle_for = -2.0  # ask again later if the lobby didn't take us
			SledRace.join_race()
		return
	_idle_for = 0.0
	var at := SledCourse.locate(sled.global_position, float(sled.get("course_s")))
	if state != "running" or not bool(sled.get("running")):
		_steer(0.0)
		_lane = at.y
		_last_lat = at.y
		_t = 0.0
		return
	_t += delta
	var target := _lane + SWING * sin(_t * TAU / period + phase)
	for f in SledCourse.FEATURES:
		var ahead := float(f[0]) - at.x
		if ahead < 0.0 or ahead > LOOK:
			continue
		var lat := float(f[1])
		if f[2] == "boost" and absf(lat - _lane) < PAD_REACH:
			target = lat
		elif f[2] in ["tree", "rock"] and absf(lat - target) < CLEAR:
			target = lat + (CLEAR + 0.4) * (-1.0 if lat > 0.0 else 1.0)  # pass on the roomier side
	target = clampf(target, -EDGE, EDGE)
	# steer on the lateral error, damped by how fast it is already drifting across
	var drift := (at.y - _last_lat) / maxf(delta, 0.001)
	_last_lat = at.y
	_steer(clampf((target - at.y) * 0.7 - drift * 0.3, -1.0, 1.0))


func _steer(amount: float) -> void:
	if amount > 0.05:
		Input.action_release("move_left")
		Input.action_press("move_right", amount)
	elif amount < -0.05:
		Input.action_release("move_right")
		Input.action_press("move_left", -amount)
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
