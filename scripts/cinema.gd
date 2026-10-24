extends Node3D

## Cinema lot, lobby, and auditorium.
## The lobby and the screen sit far east so the forecourt camera never sees them.
## InsideLobby and ScreenReturn use the lobby camera. InsideScreen uses the auditorium.


func _ready() -> void:
	AssetPack.dress_cinema(self)
	# floors, tiers, steps and the stage collide where they're drawn (the dressing only adds a
	# flat floor at y = 0, so the penguin walked inside the tiers); then rebake the navmesh
	var nav := get_node_or_null("NavigationRegion3D")
	for model_name in ["cinema_lobby", "cinema_auditorium", "cinema_exterior"]:
		var model: Node3D = null  # the dressed instance under PackProps, not its inner mesh node
		for n in find_children(model_name + "*", "Node3D", true, false):
			if n.get_parent().name == "PackProps":
				model = n
		if model and nav:
			WalkSurface.build(model, nav, model.global_position.y - 0.3, model_name + "_walk")
	if nav and nav.has_method("rebake"):
		nav.call("rebake")
	var hall := find_child("cinema_auditorium", true, false) as Node3D  # claimable, net-safe seats
	if hall:
		var screen := Sockets.find(hall, "screen")
		SeatSpot.from_sockets(self, hall, "cinema", screen.global_position if screen else hall.global_position)
		if CinemaService.enabled("screen_video"):
			var big := CinemaScreen.attach(hall, CinemaService.player)
			if big and CinemaService.enabled("ambience"):
				CinemaAmbience.attach(hall, big)
	var lobby := find_child("cinema_lobby", true, false) as Node3D
	if lobby:
		SeatSpot.from_sockets(self, lobby, "stool")


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
			"limit_x": 6.0,
			"limit_z": 5.0,
			"height": 11.0,
			"distance": 7.5,
		}
	if spawn_name.begins_with("Inside") or spawn_name == "ScreenReturn":
		return {
			"center": get_meta("lobby_center", Vector3(240.0, 0.0, 0.0)),
			"limit_x": 5.0,
			"limit_z": 4.0,
			"height": 10.0,
			"distance": 7.0,
		}
	return {
		"center": Vector3(0.0, 0.0, 0.6),
		"limit_x": 7.2,
		"limit_z": 6.2,
		"height": 13.0,
		"distance": 10.0,
	}
