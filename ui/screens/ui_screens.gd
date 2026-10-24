class_name UIScreens
## Entry points for HUD buttons and other builders. Other UI branches register screens here
## (UIScreens.register("wardrobe", func(): ...)) so the dock opens them when they exist.

static var _registry := {}


static func register(screen_name: String, opener: Callable) -> void:
	_registry[screen_name] = opener


static func open(screen_name: String) -> bool:
	if _registry.has(screen_name):
		_registry[screen_name].call()
		return true
	return false


## Opens a screen with sample data for the screenshot harness.
static func debug_open(s: String) -> Control:
	match s:
		"pause":
			UIRouter.open_pause()
		"settings":
			UIRouter.push(SettingsScreen.new())
		"controls":
			UIRouter.push(ControlsScreen.new())
		"accessibility":
			UIRouter.push(AccessibilityScreen.new())
		"microphone":
			UIRouter.push(MicrophoneScreen.new())
		"connection_lost":
			ConnectionLost.show_lost("", func() -> void: pass)
		"leave_confirm":
			ConfirmDialog.ask("Leave this activity?", "Your spot will be freed.")
		_:
			var hud: Node = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("town_hud")
			if hud and hud.has_method("debug_open"):
				hud.call("debug_open", s)
	return UIRouter.top()
