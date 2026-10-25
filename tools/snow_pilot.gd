extends Node

## Plays the town snowball fight like a player, for follow bots and film hosts (the moves are
## tools/snow_mp.gd's): while `active` it walks onto its team's pad, and once the match is live it
## holds its lane, steps side to side between throws, and throws at the nearest opponent whenever
## the cooldown allows. A pilot with no team just stands by. A match starts as soon as one player
## stands on each pad, so pilots wait just behind their pad and all step on in the same wall-clock
## window (every process shares the system clock): the match starts 2v2.

const STEP := 0.7  # metres of side-step between throws

var team := ""  # "coral", "teal", or "" to watch
var active := false

var _lane := -1
var _wait := 0.0
var _side := 1.0


func _process(delta: float) -> void:
	var arena := get_tree().get_first_node_in_group("snow_arena")
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	if not active or team == "" or arena == null or me == null:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.3
	me.call("set_typing_locked", false)  # see fish_pilot: the chat box's lock can linger
	var floor_y := float(arena.get("_floor"))
	var state := Net.snow_view()
	if Net.snow_team() == "":
		var pad: Vector2 = arena.get("_pads")[team]
		if int(Time.get_unix_time_from_system()) % 20 >= 10:
			pad += Vector2(0.0, 1.6)  # wait behind the pad
		if Vector2(me.global_position.x, me.global_position.z).distance_to(pad) > 0.4:
			me.call("command_walk_to", Vector3(pad.x, floor_y, pad.y))
		return
	if str(state.get("phase", "")) != "live":
		return
	var mine: Array = (state.get("lives", {}) as Dictionary).get(Net.local_id(), [])
	if mine.size() < 6 or float(mine[1]) > 0.0:
		return  # knocked out: waiting to respawn
	if _lane < 0:
		_lane = int(mine[5])
	var field: Rect2 = arena.get("_field")
	var z := field.end.y - (1.0 if _lane == 0 else 7.0)  # the brief's lanes at Z=1 and Z=7
	var x := field.position.x + 3.5 if Net.snow_team() == "coral" else field.end.x - 3.5
	var target := _opponent(state, z)
	if target == null or float(mine[0]) > 0.0:
		return
	me.call("face_point", target.global_position)
	me.call("play_activity", "snow_throw")
	Net.snow_throw(target.global_position)
	print("SNOW_PILOT %s throws at %s" % [Net.snow_team(), target.name])
	_side = -_side
	me.call("command_walk_to", Vector3(x, floor_y, z + STEP * _side))
	_wait = 1.1


func _opponent(state: Dictionary, z: float) -> Node3D:
	var best: Node3D = null
	var teams: Dictionary = state.get("teams", {})
	for node in get_tree().get_nodes_in_group("remote_player"):
		var id := int(node.get_meta("remote_peer", 0))
		if not teams.has(id) or teams[id] == Net.snow_team():
			continue
		if best == null or absf((node as Node3D).global_position.z - z) < absf(best.global_position.z - z):
			best = node
	return best
