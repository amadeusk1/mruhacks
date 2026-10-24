extends Node
## CinemaService autoload: the game's one shared gateway client (cinema port 3/5).
## Does no network work until something signs in (the host-pick UI, port 4/5).
## `player` is the one shared CinemaScreenPlayer: the 3D screen and the close-up overlay both show
## its frames, so reopening a view never refetches chunks.
## Service URL: env PENGLOO_CINEMA_URL, else project setting pengloo/cinema/service_url.

var client: CinemaServiceClient
var player: CinemaScreenPlayer


func _ready() -> void:
	client = CinemaServiceClient.new()
	add_child(client)
	var url := OS.get_environment("PENGLOO_CINEMA_URL")
	client.set_service(url if url != "" else str(ProjectSettings.get_setting("pengloo/cinema/service_url", "")))
	# shortcut: the player streams whenever this client is signed in and a film is loaded, even with no
	# screen or overlay open; add a viewer count before signing in outside the cinema.
	player = CinemaScreenPlayer.new()
	player.client = client
	add_child(player)


static func enabled(flag: String) -> bool:
	return bool(ProjectSettings.get_setting("pengloo/cinema/service_enabled", false)) \
		and bool(ProjectSettings.get_setting("pengloo/cinema/" + flag, false))
