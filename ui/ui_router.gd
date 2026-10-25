extends CanvasLayer
## UIRouter: one overlay layer for menus/modals, a back stack, and world-input suppression.
## - push(control): show on top; Escape (ui_cancel) closes the top entry via its close()/back.
## - While anything blocking is open, or a text field has focus, the local penguin ignores
##   movement keys and clicks (penguin_movement.set_typing_locked).
## - open_pause() is the default Escape action when nothing is open and a world is running.
## - hide_ui() (Settings > Hide UI) clears the screen for filming; Escape brings it back.

signal stack_changed

const EFFECT_LAYER := 1 << 19  # canvas items that stay drawn while the UI is hidden
const UI_LABELS := ["NameLabel", "SpeakIcon", "SitPrompt"]

var _stack: Array[Control] = []
var _locked := false
var ui_hidden := false
var _hidden_labels: Array[Label3D] = []
var settings := {
	"music": 70.0, "effects": 80.0, "voice": 60.0, "movie": 50.0,
	"mic": false, "push_to_talk": false, "text_size": 1, "reduce_motion": false,
	"high_contrast": false, "ui_scale": 100.0, "fullscreen": false, "chat_minimized": false,
	"mic_device": "Default",
}
const SETTINGS_PATH := "user://settings.cfg"
const TEXT_SCALES := [0.9, 1.0, 1.15]


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_audio()
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply_ui_scale)
	call_deferred("_apply_ui_scale")
	call_deferred("_apply_fullscreen")
	call_deferred("_apply_contrast")
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: _refresh_lock())


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var f11 := key.keycode == KEY_F11 or key.physical_keycode == KEY_F11
	var enter := key.keycode in [KEY_ENTER, KEY_KP_ENTER] or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	var alt_enter := key.alt_pressed and enter
	if not f11 and not alt_enter:
		return
	set_setting("fullscreen", not bool(settings.get("fullscreen", false)))
	get_viewport().set_input_as_handled()


func push(c: Control) -> void:
	if c.get_parent() == null:
		add_child(c)
	_stack.append(c)
	stack_changed.emit()
	_refresh_lock()
	var first := _first_focusable(c)
	if first:
		first.grab_focus.call_deferred()


func remove(c: Control) -> void:
	_stack.erase(c)
	stack_changed.emit()
	_refresh_lock.call_deferred()


func top() -> Control:
	return _stack.back() if not _stack.is_empty() else null


func is_open() -> bool:
	return not _stack.is_empty()


## True while an open screen should stop the penguin (the same test _refresh_lock uses).
func blocks_world() -> bool:
	return _stack.any(func(c): return is_instance_valid(c) and (not ("blocks_world" in c) or bool(c.get("blocks_world"))))


func close_all() -> void:
	for c in _stack.duplicate():
		if c.has_method("close"):
			c.call("close")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if ui_hidden:
		show_ui()
		if _in_world():
			open_pause()
		get_viewport().set_input_as_handled()
		return
	var t := top()
	if t != null:
		if t.has_method("close"):
			t.call("close")
		get_viewport().set_input_as_handled()
	elif _in_world() and get_viewport().gui_get_focus_owner() == null:
		open_pause()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	push(PauseMenu.new())


## Hides every 2D HUD/menu (viewport canvas cull mask) and the floating 3D name tags and prompts
## (render layers 0). Background canvas effects (CanvasLayer.layer <= 0, e.g. the aurora) stay.
## Not saved: a restart always shows the UI.
func hide_ui() -> void:
	close_all()
	ui_hidden = true
	get_viewport().canvas_cull_mask = EFFECT_LAYER
	_hide_world_ui()
	var t := Timer.new()  # new name tags, prompts and effects appear as players arrive or travel
	t.name = "HiddenUiScan"
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(_hide_world_ui)
	add_child(t)


func show_ui() -> void:
	ui_hidden = false
	get_viewport().canvas_cull_mask = 0xFFFFF
	var t := get_node_or_null("HiddenUiScan")
	if t:
		t.queue_free()
	for l in _hidden_labels:
		if is_instance_valid(l):
			l.layers = int(l.get_meta("ui_layers", 1))
	_hidden_labels.clear()


func _hide_world_ui() -> void:
	var root := get_tree().root
	for n in root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).layer <= 0:
			for c in n.find_children("*", "CanvasItem", true, false):
				(c as CanvasItem).visibility_layer |= EFFECT_LAYER
	for n in root.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		var parent := l.get_parent()
		var is_ui: bool = String(l.name) in UI_LABELS or parent.get("_prompt") == l or parent.get("_label") == l
		if is_ui and l.layers != 0:
			l.set_meta("ui_layers", l.layers)
			l.layers = 0
			_hidden_labels.append(l)


func _in_world() -> bool:
	var w := get_tree().get_first_node_in_group("world")
	return w != null and w.has_method("current_location_id") and str(w.call("current_location_id")) != ""


func _refresh_lock() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	var blocking := _stack.any(func(c): return not ("blocks_world" in c) or bool(c.get("blocks_world")))
	var want := typing or blocking
	if want == _locked:
		return
	_locked = want
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_typing_locked"):
		player.call("set_typing_locked", want)


func _first_focusable(c: Control) -> Control:
	for n in c.find_children("*", "BaseButton", true, false) + c.find_children("*", "LineEdit", true, false):
		var cc := n as Control
		if cc.visible and cc.focus_mode != Control.FOCUS_NONE and not (cc is Button and (cc as Button).disabled) \
				and cc.theme_type_variation != "IconButton":
			return cc
	return null


# ---- settings (persisted; applied where the game reads them) ---------------------
func set_setting(key: String, value) -> void:
	settings[key] = value
	_save_settings()
	if key in ["text_size", "ui_scale"]:
		_apply_ui_scale()
	if key in ["music", "effects", "voice", "movie"]:
		_apply_bus(key)
	if key == "fullscreen":
		_apply_fullscreen()
	if key == "high_contrast":
		_apply_contrast()
	if key == "mic_device":
		var voice := get_node_or_null("/root/Voice")
		if voice and voice.has_method("apply_input_device"):
			voice.call("apply_input_device")


func text_scale() -> float:
	return TEXT_SCALES[clampi(int(settings["text_size"]), 0, 2)] * float(settings["ui_scale"]) / 100.0


func _apply_ui_scale() -> void:
	var window := get_window()
	if window:
		Mobile.apply(window, text_scale())


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func _apply_audio() -> void:
	for key in ["music", "effects", "voice", "movie"]:
		_apply_bus(key)


func _apply_contrast() -> void:
	var root := get_tree().root
	if root == null:
		return
	for n in root.find_children("*", "WorldEnvironment", true, false):
		_style_environment(n as WorldEnvironment)


func _style_environment(world: WorldEnvironment) -> void:
	var on := bool(settings.get("high_contrast", false))
	var env := world.environment
	if not on:
		if world.has_meta("contrast_base") and env != null:
			var base: Array = world.get_meta("contrast_base")
			env.adjustment_enabled = bool(base[0])
			env.adjustment_contrast = float(base[1])
			env.adjustment_brightness = float(base[2])
		return
	if env == null:
		return
	if not world.has_meta("contrast_ready"):
		world.environment = env.duplicate(true)
		env = world.environment
		world.set_meta("contrast_base", [env.adjustment_enabled, env.adjustment_contrast, env.adjustment_brightness])
		world.set_meta("contrast_ready", true)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.35
	env.adjustment_brightness = 1.06


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment:
		_style_environment(n)


func _apply_bus(key: String) -> void:
	var names := {"music": "Music", "effects": "SFX", "voice": "Voice", "movie": "Movie"}
	var bus := _ensure_bus(names[key])
	var lin := float(settings[key]) / 100.0
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(lin, 0.0001)))


func _apply_fullscreen() -> void:
	var on := bool(settings.get("fullscreen", false))
	if not on:
		var mode := DisplayServer.window_get_mode()
		var borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		if mode != DisplayServer.WINDOW_MODE_WINDOWED or borderless:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_sync_fullscreen_toggles()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_confirm_fullscreen.call_deferred()
	_sync_fullscreen_toggles()


func _confirm_fullscreen() -> void:
	if not bool(settings.get("fullscreen", false)):
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_cover_screen.call_deferred()


func _cover_screen() -> void:
	if not bool(settings.get("fullscreen", false)):
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return
	var screen := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
	DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))


func _sync_fullscreen_toggles() -> void:
	var on := bool(settings.get("fullscreen", false))
	var root := get_tree().root
	if root:
		_sync_fullscreen_node(root, on)


func _sync_fullscreen_node(node: Node, on: bool) -> void:
	if node is CheckButton and node.has_meta("fullscreen_toggle"):
		var box := node as CheckButton
		box.set_block_signals(true)
		box.button_pressed = on
		box.set_block_signals(false)
	for child in node.get_children():
		_sync_fullscreen_node(child, on)


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cf.get_value("ui", k, settings[k])


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("ui", k, settings[k])
	cf.save(SETTINGS_PATH)
