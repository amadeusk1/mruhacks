class_name CinemaMovieSpot
extends Interactable
## "Pick a Movie" inside the auditorium: a podium (cinema_lobby/movie_kiosk) at the back by the door,
## but usable from anywhere in the hall, seated or standing; the HUD pill and F open the same
## library / host-pick flow as the lobby kiosk. The prompt follows the movie night's state.

const HALF := Vector2(7.0, 6.2)   ## the hall floor, local half extents (x, z)

var hall_root: Node3D
var half := HALF                  ## area this spot covers around hall_root (the lobby uses its own)
var lobby_only_sign_in := false   ## lobby instance: only offers "Sign in to cinema"


## Podium + spot + a nav blocker, placed before the cinema rebakes its navmesh.
static func place(room: Node3D, root: Node3D) -> CinemaMovieSpot:
	var at := Vector3(-5.4, 0.0, 1.8)  # left aisle, beside the door, clear of the seat rows
	var podium := AssetPack.spawn("cinema_lobby", "movie_kiosk")
	if podium:
		root.add_child(podium)
		podium.rotation.y = PI * 0.5  # face into the hall
		var box := AssetPack._model_aabb(podium)  # the standalone kiosk asset spawns small: size it to 1.1 m wide
		var wide := maxf(box.size.x, box.size.z)
		if wide > 0.01:
			podium.scale = Vector3.ONE * (1.1 / wide)
		box = AssetPack._model_aabb(podium)
		podium.position = at - Vector3(0, box.position.y, 0)  # stand on the floor
	var block := StaticBody3D.new()
	block.collision_layer = 2       # room_nav carves layer-2 bodies out of the walkable mesh
	block.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.75, 1.0, 1.15)
	block.add_child(shape)
	var nav := room.get_node_or_null("NavigationRegion3D")  # room_nav only carves bodies under the region
	(nav if nav else root).add_child(block)
	block.global_position = root.to_global(at + Vector3(0, 0.5, 0))
	block.global_rotation.y = root.global_rotation.y + PI * 0.5
	var spot := CinemaMovieSpot.new()
	spot.name = "CinemaPickMovie"
	spot.hall_root = root
	spot.activity = "cinema"
	spot.title = "a Movie"
	spot.verb = "Pick"
	room.add_child(spot)
	spot.global_position = root.to_global(at + Vector3(0.9, 0, 0))
	return spot


func prompt_text() -> String:
	var c := CinemaService.client
	if not c.signed_in:
		return "Sign in to cinema"
	var host := c.signed_in and bool(c.me.get("eligible", false))
	if c.signed_in and not host:
		return "Suggest a Movie"
	if CinemaService.player.has_film():
		return "Change Movie" if host else "Pick a Movie"
	return "Pick a Movie"


## Anywhere on the hall floor, seated or not (so the pill is always there in the auditorium).
func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null or hall_root == null:
		return false
	var l := hall_root.to_local(player.global_position)
	if lobby_only_sign_in and CinemaService.client.signed_in:
		return false
	return absf(l.x) < half.x and absf(l.z) < half.y


## Opens the cinema library directly, even from a seat (no walk to the podium needed).
func interact(player: Node) -> bool:
	if not CinemaService.client.signed_in:
		CinemaService.open_sign_in()
	else:
		Activities.request("cinema", self, player)
	return true



## Lobby: "Sign in to cinema" pill anywhere in the lobby while signed out (the kiosk does the rest).
static func place_lobby(room: Node3D, lobby_root: Node3D) -> CinemaMovieSpot:
	var spot := CinemaMovieSpot.new()
	spot.name = "CinemaSignInLobby"
	spot.hall_root = lobby_root
	spot.half = Vector2(5.0, 4.0)
	spot.lobby_only_sign_in = true
	spot.activity = "cinema"
	room.add_child(spot)
	spot.global_position = lobby_root.global_position + Vector3(0, 0, 2.5)  # mid-lobby, so doors/kiosk win when closer
	return spot
