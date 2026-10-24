extends Node3D

## Cinema lot, lobby, and auditorium.
## The lobby and the screen sit far east so the forecourt camera never sees them.
## InsideLobby and ScreenReturn use the lobby camera. InsideScreen uses the auditorium.


func _ready() -> void:
	AssetPack.dress_cinema(self)
	var hall := find_child("cinema_auditorium", true, false) as Node3D  # claimable, net-safe seats
	if hall:
		var screen := Sockets.find(hall, "screen")
		SeatSpot.from_sockets(self, hall, "cinema", screen.global_position if screen else hall.global_position)
	var lobby := find_child("cinema_lobby", true, false) as Node3D
	if lobby:
		SeatSpot.from_sockets(self, lobby, "stool")
		var kiosk := Interactable.new()
		kiosk.name = "CinemaLibraryKiosk"
		kiosk.title = "movie library"
		kiosk.verb = "Browse"
		kiosk.activity = "cinema"
		add_child(kiosk)
		kiosk.global_position = lobby.to_global(Vector3(1.0, 0.0, 0.15))
	for node in get_children():
		if node is SeatSpot and node.kit == "cinema":
			node.activity = "cinema"
			node.verb = "Watch"



## Voice/presence room inside this one location (GAME_DESIGN_CONTEXT §8: the auditorium is
## its own audio room). Lobby and hall sit at the lobby_center / hall_center offsets.
func voice_room_at(pos: Vector3) -> String:
	if pos.distance_to(get_meta("hall_center", Vector3(240, 0, 50))) < 12.0:
		return "cinema_hall"
	if pos.distance_to(get_meta("lobby_center", Vector3(240, 0, 0))) < 12.0:
		return "cinema_lobby"
	return "cinema_front"


func camera_for_spawn(spawn_name: String) -> Dictionary:
	if spawn_name == "InsideScreen":
		return {
			"center": get_meta("hall_center", Vector3(240.0, 0.0, 50.0)),
			"limit_x": 2.2,
			"limit_z": 3.0,
			"height": 8.6,
			"distance": 5.6,
		}
	if spawn_name.begins_with("Inside") or spawn_name == "ScreenReturn":
		return {
			"center": get_meta("lobby_center", Vector3(240.0, 0.0, 0.0)),
			"limit_x": 3.4,
			"limit_z": 2.4,
			"height": 8.2,
			"distance": 5.4,
		}
	return {
		"center": Vector3(0.0, 0.0, 0.6),
		"limit_x": 7.2,
		"limit_z": 6.2,
		"height": 13.0,
		"distance": 10.0,
	}
