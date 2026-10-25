extends Node
## CinemaService autoload: the game's one shared gateway client (cinema port 3/5).
## Does no network work until something signs in (the host-pick UI, port 4/5).
## `player` is the one shared CinemaScreenPlayer: the 3D screen and the close-up overlay both show
## its frames, so reopening a view never refetches chunks.
## Service URL: env PENGLOO_CINEMA_URL (local dev), else the web build's own origin + /cinema/
## (same-origin on pengloo.party: the browser handles cookies and Origin), else the project setting
## pengloo/cinema/service_url (native builds: https://pengloo.party/cinema/). Unreachable -> the cinema
## UI shows the labelled Demo library.

signal signed_in_changed(signed_in: bool)

const SIGN_IN := preload("res://ui/activities/cinema/cinema_sign_in.gd")

var client: CinemaServiceClient
var player: CinemaScreenPlayer


func _ready() -> void:
	client = CinemaServiceClient.new()
	add_child(client)
	client.set_service(service_url())
	player = CinemaScreenPlayer.new()
	player.client = client
	add_child(player)
	if enabled("service_enabled"):
		client.restore(_on_restore)  # web: the browser may still hold this session's cookie
	Net.session_started.connect(retarget)


## Each server has its own cinema (community servers run their own gateway behind the relay), and a
## session on one never authorizes another: switching servers starts a fresh client session.
func retarget() -> void:
	var url := service_url()
	if client.base == url.strip_edges().trim_suffix("/"):
		return
	player.stop()
	client.set_service(url)
	signed_in_changed.emit(false)
	if enabled("service_enabled"):
		client.restore(_on_restore)


func _on_restore(ok: bool) -> void:
	if ok:
		signed_in_changed.emit(true)


## Signs in with an invite code (never stored); the session lasts for this game session, across rooms.
## done(ok: bool, error: String)
func sign_in(code: String, done: Callable) -> void:
	client.login(str(Net.local_profile().get("name", "Penguin")), code, func(ok: bool, err: String) -> void:
		if ok:
			signed_in_changed.emit(true)
		if done.is_valid():
			done.call(ok, err))


## The one sign-in screen; every "sign in needed" place opens this.
func open_sign_in() -> Control:
	for c in UIRouter.get_children():
		if c.get_script() == SIGN_IN:
			return c
	var ui: Control = SIGN_IN.new()
	UIRouter.push(ui)
	return ui


static func service_url() -> String:
	if Net.local_cinema_url != "":
		return Net.local_cinema_url
	var env := OS.get_environment("PENGLOO_CINEMA_URL")
	if env != "":
		return env
	if Net.community:  # this server's own gateway, through the relay: <lobby>/s/<id>/cinema/
		var base := Net.server_url
		if base == "" and Net.has_node("LobbyLink"):  # hosting it ourselves
			var id := str(Net.get_node("LobbyLink").listed_id)
			base = Net.lobby_base() + "/s/" + id if id != "" else ""
		if base != "":
			return base.replace("wss://", "https://").replace("ws://", "http://") + "/cinema/"
	if OS.has_feature("web"):  # no JavaScript eval: the page CSP may forbid it
		return str(JavaScriptBridge.get_interface("location").origin) + "/cinema/"
	return str(ProjectSettings.get_setting("pengloo/cinema/service_url", "https://pengloo.party/cinema/"))


static func enabled(flag: String) -> bool:
	if Net.community and not Net.community_cinema:  # a community server without its own cinema
		return false
	return bool(ProjectSettings.get_setting("pengloo/cinema/service_enabled", false)) \
		and bool(ProjectSettings.get_setting("pengloo/cinema/" + flag, false))
