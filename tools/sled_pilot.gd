extends Node

## Steers the local sled on Sled Hill like a player would, for follow bots and film hosts: it
## presses the same move_left / move_right actions as A and D (with partial strength), carving a
## slalom around its start lane and swerving around the trees and rocks ahead. When a run ends it
## asks for the next race, like the Retry button.

const SWING := 2.2      # metres either side of the lane: wide enough to read on camera
const LOOK := 12.0      # how far ahead it watches for obstacles
const CLEAR := 1.7      # obstacle half-width plus the sled's
const EDGE := 7.0       # stay inside the treelines at +-9.7
const RETRY_AFTER := 1.5

var period := 1.6       # seconds per swing; give each pilot its own
var phase := 0.0        # radians; so pilots don't swing in step

var _lane_x := 0.0
var _t := 0.0
var _over_for := 0.0


func _physics_process(delta: float) -> void:
	var room := get_tree().get_first_node_in_group("activity")
	if room == null or room.get("sled") == null:
		_steer(0.0)
		return
	var sled: Node3D = room.get("sled")
	if bool(room.get("_over")):
		_steer(0.0)
		_over_for += delta
		if _over_for >= RETRY_AFTER and Net.is_online():
			_over_for = -INF  # once per run
			Net.sled_retry()
		return
	_over_for = 0.0
	var x := sled.global_position.x
	if not bool(sled.get("running")):
		_steer(0.0)
		_lane_x = x
		_t = 0.0
		return
	_t += delta
	var target := clampf(_lane_x + SWING * sin(_t * TAU / period + phase), -EDGE, EDGE)
	var obstacles := room.get_node_or_null("Obstacles")
	if obstacles != null:
		for o in obstacles.get_children():
			var at := (o as Node3D).global_position
			var ahead := sled.global_position.z - at.z
			if ahead > 0.0 and ahead < LOOK and absf(at.x - target) < CLEAR:
				# pass on the roomier side; flip if that side runs into the treeline
				var side := -1.0 if at.x > 0.0 else 1.0
				target = at.x + side * (CLEAR + 0.4)
				if absf(target) > EDGE:
					target = at.x - side * (CLEAR + 0.4)
	_steer(clampf((target - x) / 1.2, -1.0, 1.0))


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
