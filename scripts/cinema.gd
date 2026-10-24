extends Node3D

## Cinema lot, lobby, and auditorium.
## The lobby and the screen sit far east so the forecourt camera never sees them.
## InsideLobby and ScreenReturn use the lobby camera. InsideScreen uses the auditorium.


## 13 Cinema Lobby / 14 Auditorium / Movie Night: warm sand floor and plaster, velvet reds, a
## warm brighter lobby; the auditorium is a real cinema: house lights down, the screen the main
## light, step and aisle lights and a dim exit glow.
const MOOD := {"background": "#2A1E1A", "ambient": "#FFD9B4", "sun": "#FFD6A6", "ambient_energy": 0.4}
const HALL_MOOD := {"background": "#07070B", "ambient": "#6E6A8A", "sun": "#000000", "ambient_energy": 0.07, "exposure": 1.05}
const PALETTE := {"paving": "#E8CFA6", "paving_b": "#DDBF94", "stone": "#D7BE9C"}
var _saved_mood := {}


func _exit_tree() -> void:
	InteriorMood.restore(get_tree(), _saved_mood)


func _ready() -> void:
	AssetPack.dress_cinema(self)
	InteriorMood.calm(self)
	for n in find_children("cinema_lobby*", "Node3D", true, false):
		if n.get_parent().name == "PackProps":
			InteriorMood.paint(n, {"wall": "#F1DCBC"}, PALETTE)
	if CinemaService.enabled("service_enabled"):  # "Pick a Movie" podium inside the auditorium (before the rebake)
		for n in find_children("cinema_auditorium*", "Node3D", true, false):
			if n.get_parent().name == "PackProps":
				CinemaMovieSpot.place(self, n)
		for n in find_children("cinema_lobby*", "Node3D", true, false):
			if n.get_parent().name == "PackProps":
				CinemaMovieSpot.place_lobby(self, n)
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
	var lobby_model: Node3D = null
	for n in find_children("cinema_lobby*", "Node3D", true, false):
		if n.get_parent().name == "PackProps":
			lobby_model = n
	if lobby_model and nav:
		await get_tree().physics_frame  # floors registered for the footprint's ground rays
		Footprint.blocker(nav, lobby_model, "cinema_lobby/cinema_lobby", 1.0, get_world_3d().direct_space_state)
	for n in find_children("cinema_auditorium*", "Node3D", true, false):
		if n.get_parent().name == "PackProps":  # the dressed instance, not its inner mesh node
			_dress_hall(n)
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
		var kiosk_socket := Sockets.find(lobby, "kiosk")
		if kiosk_socket:  # the library kiosk opens the host-pick UI (cinema_ui via ActivityScreens)
			var kiosk := Interactable.new()
			kiosk.name = "CinemaLibraryKiosk"
			kiosk.title = "Movies"
			kiosk.verb = "Browse"
			kiosk.activity = "cinema"
			add_child(kiosk)
			kiosk.global_position = kiosk_socket.global_position


## Voice/presence room inside this one location (GAME_DESIGN_CONTEXT §8: the auditorium is
## its own audio room). Lobby and hall sit at the lobby_center / hall_center offsets.
func voice_room_at(pos: Vector3) -> String:
	if pos.distance_to(get_meta("hall_center", Vector3(240, 0, 50))) < 12.0:
		return "cinema_hall"
	if pos.distance_to(get_meta("lobby_center", Vector3(240, 0, 0))) < 12.0:
		return "cinema_lobby"
	return "cinema_front"


## Indoor light only while the player is inside: the yard / forecourt keep the town's sky and sun.
func _set_indoor(on: bool, mood: Dictionary = MOOD) -> void:
	if not _saved_mood.is_empty():  # lobby <-> auditorium swaps the mood too
		InteriorMood.restore(get_tree(), _saved_mood)
		_saved_mood = {}
	if on:
		_saved_mood = InteriorMood.apply(get_tree(), mood)


func camera_for_spawn(spawn_name: String) -> Dictionary:
	_set_indoor(spawn_name.begins_with("Inside") or spawn_name == "ScreenReturn", HALL_MOOD if spawn_name == "InsideScreen" else MOOD)
	if spawn_name == "InsideScreen":
		return {
			"center": get_meta("hall_center", Vector3(240.0, 0.0, 50.0)),
			"limit_x": 5.0,
			"limit_z": 3.5,
			"height": 6.2,  # Movie Night: low over the back rows, the screen and curtains filling the top half
			"distance": 9.5,
			"yaw_deg": 25.0,
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


## Movie Night Scene: warm lanterns down the side wall of the dark auditorium. Wall-mounted, so
## nothing new to walk round.
func _dress_hall(hall: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in hall.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	for l in hall.find_children("*", "OmniLight3D", true, false):  # house lights down
		(l as OmniLight3D).light_energy *= 0.3
	# the screen is the main light: a cool wash from the screen over the rows
	var screen := Sockets.find(hall, "screen")
	if screen:
		var wash := SpotLight3D.new()
		wash.light_color = Color("#BFD3FF")
		wash.light_energy = 2.2
		wash.spot_range = 16.0
		wash.spot_angle = 55.0
		wash.spot_attenuation = 0.8
		hall.get_parent().add_child(wash)
		wash.global_position = screen.global_position + Vector3(0, 0.6, 0.8)
		wash.look_at(screen.global_position + Vector3(0, -1.2, 8.0), Vector3.UP)
	var exit := Sockets.find(hall, "exit")
	if exit:
		var glow := OmniLight3D.new()  # dim exit glow by the lobby door
		glow.light_color = Color("#FFC27A")
		glow.light_energy = 0.6
		glow.omni_range = 2.0
		hall.get_parent().add_child(glow)
		glow.global_position = exit.global_position + Vector3(0.6, 2.0, 0)
	# dark stepped floor in warm browns with glowing step and aisle lights, as in the concept
	InteriorMood.paint(hall, {}, {"floor_dark": "#3A2A25", "floor_dark_b": "#2F221E", "aisle_light": "glow:#FFB347"})
	for z in [0.3, 0.55, 0.8]:  # the left (teal) wall; the right side is open to the camera
		var at := Vector3(box.position.x + 0.12, 1.9, lerpf(box.position.z, box.end.z, z))
		AssetPack.place(hall.get_parent(), "plaza", "wall_lantern", hall.get_parent().to_local(at), deg_to_rad(90.0))
		var pool := OmniLight3D.new()  # a dim warm pool round each wall lantern
		pool.light_color = Color("#FFB866")
		pool.light_energy = 0.45
		pool.omni_range = 2.2
		hall.get_parent().add_child(pool)
		pool.global_position = at + Vector3(0.5, 0.0, 0.0)
