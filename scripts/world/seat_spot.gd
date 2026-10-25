class_name SeatSpot
extends Interactable

## A claimable seat or play station (cinema seat, café stool, arcade station, casino seat).
## Occupancy goes through the teammate's host-checked seat API (Net.claim_bench / release on
## stand), keyed like bench.gd so the host accepts it. `kit` picks the seated/station clips
## (PenguinAnims.SEATS), which replicate to other players. `activity` (optional) asks the UI
## to open a game via Activities.requested(activity, self, player).

@export var kit := ""
var seat_point := Vector3.ZERO   # world: where the penguin's origin goes
var face_yaw := 0.0              # world yaw the penguin faces (forward is -Z)
var stand_point := Vector3.INF   # world: where it stands back up (default: nearest walkable)


func _enter_tree() -> void:
	add_to_group("seats")


func approach_point() -> Vector3:
	return seat_point


## Click-walk arrival (penguin_movement._follow_path), same as the teammate's benches.
func try_sit(_force := false) -> bool:
	var player := get_tree().get_first_node_in_group("local_player")
	return player != null and interact(player)


func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null or (player.has_method("is_sitting") and bool(player.call("is_sitting"))):
		return false
	var d := Vector2(player.global_position.x - seat_point.x, player.global_position.z - seat_point.z)
	return d.length() < reach and not Net.bench_held_by_other(bench_key())


## Same scheme as bench.gd: "<location>:<path inside the room>" (the host checks the prefix).
func bench_key() -> String:
	var world := get_tree().get_first_node_in_group("world")
	var location := str(world.call("current_location_id")) if world and world.has_method("current_location_id") else ""
	if location == "home" and world.has_method("home_owner_id"):
		location = "home:%s" % int(world.call("home_owner_id"))
	var room: Node = self
	while room.get_parent() != null and room.get_parent().name != "LocationHost":
		room = room.get_parent()
	return "%s:%s" % [location, room.get_path_to(self)]


func interact(player: Node) -> bool:
	if not player.has_method("sit_down") or not can_interact() or not Net.claim_bench(bench_key()):
		return false
	var stand := stand_point
	if stand == Vector3.INF:  # nearest walkable spot, so standing up never lands inside furniture
		var map := (player as Node3D).get_world_3d().navigation_map
		stand = NavigationServer3D.map_get_closest_point(map, seat_point)
	player.call("sit_down", self, seat_point, face_yaw, stand)
	if player.has_method("set_seat_clip"):
		player.call("set_seat_clip", kit)
	if activity != "":
		Activities.request(activity, self, player)
	return true


## SeatSpots at every `socket_seat*` under `model` (seat-contact height), facing `face_point`,
## or (Vector3.INF) out of the front of whatever furniture owns the socket (sofas, armchairs).
static func from_sockets(room: Node3D, model: Node3D, seat_kit: String, face_point: Vector3 = Vector3.INF, seat_activity: String = "") -> int:
	var n := 0
	for s in model.find_children("socket_seat*", "Node3D", true, false):
		if _taken_spot(room, (s as Node3D).global_position):
			continue  # a table's seat socket and the stool placed on it are one seat
		var seat := SeatSpot.new()
		seat.name = "%s_%s" % [s.get_parent().name, s.name]
		if room.has_node(NodePath(seat.name)):  # 14 "bench"es: a position name, identical on every client (it is the claim key)
			var at := (s as Node3D).global_position
			seat.name = "%s_%d_%d" % [seat.name, roundi(at.x * 10.0), roundi(at.z * 10.0)]
		seat.kit = seat_kit
		seat.activity = seat_activity
		seat.verb = "Sit"
		if seat_kit == "cinema":
			seat.reach = 3.0  # mid-row theatre seats are taken from the aisle: the rows are too tight to walk along
		room.add_child(seat)
		seat.global_position = (s as Node3D).global_position
		seat.seat_point = seat.global_position
		if face_point == Vector3.INF:  # furniture fronts face +Z; the penguin's forward is -Z
			seat.face_yaw = (s.get_parent() as Node3D).global_rotation.y + PI
		else:
			var to := face_point - seat.seat_point
			seat.face_yaw = atan2(-to.x, -to.z)
		n += 1
	return n


## Seats for any placed furniture with socket_seat* (benches, stools, chairs, sofas, the cafe's
## window bench): new seat props work without code. Tables are skipped (the stools around them
## are the seats; a bare table socket would sit you on air), and so are vehicles and machines.
static func furnish(room: Node3D, model: Node3D, id: String, category: String) -> int:
	if not category in ["furniture", "seating", "seat", "building"] or id.contains("table") or id.contains("machine"):
		return 0
	var kit := ""  # the bench "sit"
	if id.contains("stool"):
		kit = "stool"
	elif ["chair", "sofa", "beanbag", "pouf", "cushion", "bed", "window_seat"].any(func(k): return id.contains(k)):
		kit = "armchair"
	return from_sockets(room, model, kit)


## The seat under the click (or the nearest free one on the same bench/table when that one is
## taken, so friends fill the slots beside each other). null when none is within `radius`.
static func pick(tree: SceneTree, at: Vector3, radius := 0.9) -> SeatSpot:
	var best: SeatSpot = null
	var best_d := radius
	for seat in tree.get_nodes_in_group("seats"):
		var d := Vector2(seat.seat_point.x - at.x, seat.seat_point.z - at.z).length()
		if d < best_d and not Net.bench_held_by_other(seat.bench_key()):
			best = seat
			best_d = d
	return best


static func _taken_spot(room: Node, at: Vector3) -> bool:
	for c in room.get_tree().get_nodes_in_group("seats"):
		if not c.is_queued_for_deletion() and c.seat_point.distance_to(at) < 0.3:
			return true
	return false
