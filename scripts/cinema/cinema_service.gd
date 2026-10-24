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
	var env := OS.get_environment("PENGLOO_CINEMA_URL")
	if env != "":
		return env
	if OS.has_feature("web"):  # no JavaScript eval: the page CSP may forbid it
		return str(JavaScriptBridge.get_interface("location").origin) + "/cinema/"
	return str(ProjectSettings.get_setting("pengloo/cinema/service_url", "https://pengloo.party/cinema/"))


static func enabled(flag: String) -> bool:
	return bool(ProjectSettings.get_setting("pengloo/cinema/service_enabled", false)) \
		and bool(ProjectSettings.get_setting("pengloo/cinema/" + flag, false))
