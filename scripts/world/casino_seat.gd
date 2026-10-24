class_name CasinoSeat
extends Interactable

## One seat at a casino table or slot machine. F sits the penguin (hop_onto_seat, then the
## seated idle loop) and asks the UI to open the game via Activities.requested(game, self, player).
## Moving away stands up (the teammate's seat flow); leave_seat plays on the way out.

var seat_point := Vector3.ZERO   # world, where the penguin's origin sits
var stand_point := Vector3.ZERO  # world, where it stands back up
var face_yaw := 0.0


func approach_point() -> Vector3:
	return stand_point


func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null or (player.has_method("is_sitting") and bool(player.call("is_sitting"))):
		return false
	var d := Vector2(player.global_position.x - stand_point.x, player.global_position.z - stand_point.z)
	return d.length() < 1.4 and not Net.bench_held_by_other(bench_key())


func bench_key() -> String:
	return "casino:%s" % name


func interact(player: Node) -> bool:
	if not player.has_method("sit_down") or not Net.claim_bench(bench_key()):
		return false
	player.call("sit_down", self, seat_point, face_yaw, stand_point)
	if player.has_method("set_seat_clip"):
		player.call("set_seat_clip", "casino")
	Activities.request(activity, self, player)  # no listener yet: the penguin still just sits
	return true
