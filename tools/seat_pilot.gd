extends Node

## Takes a seat like a player, for follow bots and film hosts: while `active` it walks to the
## free seat of `kit` nearest `near` and sits down (SeatSpot.interact claims it through the host,
## so everyone sees it seated). If the walk doesn't get there, it steps over the way a doorway would.

const GIVE_UP := 8.0  # seconds of walking before stepping over

var kit := "cinema"  # "*": any plain seat (benches, stools, chairs), not game seats
var near := Vector3.ZERO
var active := false

var _seat: Node3D
var _walked := 0.0
var _wait := 0.0


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	if not active or me == null or bool(me.call("is_sitting")):
		_seat = null
		_walked = 0.0
		return
	_walked += delta
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.4
	me.call("set_typing_locked", false)  # see fish_pilot: the chat box's lock can linger
	if _seat == null or Net.bench_held_by_other(str(_seat.call("bench_key"))):
		_seat = _free_seat()
		if _seat == null:
			return
	var at: Vector3 = _seat.get("seat_point")
	if Vector2(me.global_position.x - at.x, me.global_position.z - at.z).length() > float(_seat.get("reach")) * 0.8:
		if _walked > GIVE_UP:
			me.global_position = at + Vector3(0.0, 0.1, 0.0)
		else:
			me.call("command_walk_to", at)
		return
	_seat.call("interact", me)


func _free_seat() -> Node3D:
	var best: Node3D = null
	for node in get_tree().get_nodes_in_group("interactables"):
		if not node is SeatSpot or Net.bench_held_by_other(str(node.call("bench_key"))):
			continue
		if (kit == "*" and str(node.get("activity")) != "") or (kit != "*" and str(node.get("kit")) != kit):
			continue
		var d := (node.get("seat_point") as Vector3).distance_to(near)
		if best == null or d < (best.get("seat_point") as Vector3).distance_to(near):
			best = node
	return best
