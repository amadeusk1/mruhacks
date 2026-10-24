extends CanvasLayer
## UIRouter: one overlay layer for menus/modals, a back stack, and world-input suppression.
## - push(control): show on top; Escape (ui_cancel) closes the top entry via its close()/back.
## - While anything blocking is open, or a text field has focus, the local penguin ignores
##   movement keys and clicks (penguin_movement.set_typing_locked).
## - open_pause() is the default Escape action when nothing is open and a world is running.

signal stack_changed

var _stack: Array[Control] = []
var _locked := false
var settings := {
	"music": 70.0, "effects": 80.0, "voice": 60.0, "movie": 50.0,
	"mic": false, "push_to_talk": false, "text_size": 1, "reduce_motion": false,
	"high_contrast": false, "ui_scale": 100.0,
}
const SETTINGS_PATH := "user://settings.cfg"
const TEXT_SCALES := [0.9, 1.0, 1.15]


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: _refresh_lock())


func push(c: Control) -> void:
	if c.get_parent() == null:
		add_child(c)
	_stack.append(c)
	_apply_scale(c)
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


func close_all() -> void:
	for c in _stack.duplicate():
		if c.has_method("close"):
			c.call("close")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
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
		for c in _stack:
			_apply_scale(c)
	if key in ["music", "effects", "voice", "movie"]:
		_apply_bus(key)


func text_scale() -> float:
	return TEXT_SCALES[clampi(int(settings["text_size"]), 0, 2)] * float(settings["ui_scale"]) / 100.0


func _apply_scale(c: Control) -> void:
	# shortcut: scales whole panels around their centre; real per-font scaling needs a theme rebuild
	var s := text_scale()
	c.pivot_offset = c.get_viewport_rect().size * 0.5 if c.is_inside_tree() else Vector2(640, 360)
	c.scale = Vector2(s, s)


func _apply_bus(key: String) -> void:
	var bus := AudioServer.get_bus_index({"music": "Music", "effects": "SFX", "voice": "Voice", "movie": "Movie"}[key])
	var lin := float(settings[key]) / 100.0
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(lin, 0.0001)))
	elif key == "music":  # single-bus project: music drives Master
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(lin, 0.0001)))


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
