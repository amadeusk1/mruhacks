class_name ControlsScreen
extends UIModal
## Remappable controls. Rows read the live InputMap; a pencil starts "press a key" capture.
## Duplicate keys ask Replace / Cancel. Saved to user://controls.cfg.

const PATH := "user://controls.cfg"
const ROWS := [["Move", ["move_forward", "move_left", "move_back", "move_right"]], ["Interact", ["interact"]],
	["Map", ["open_map"]], ["Emotes", ["open_emotes"]], ["Push to talk", ["push_to_talk"]]]
const DEFAULTS := {"move_forward": KEY_W, "move_left": KEY_A, "move_back": KEY_S, "move_right": KEY_D,
	"interact": KEY_F, "open_map": KEY_M, "open_emotes": KEY_R, "push_to_talk": KEY_V}


func _init() -> void:
	setup("CONTROLS", "Customize your controls.", 520, false, false)
	title_label.theme_type_variation = "Title"
	body.add_child(page())
	var bottom := UIKit.hbox(12)
	var restore := UIKit.button("Restore defaults", "secondary")
	restore.pressed.connect(func() -> void:
		ControlsScreen.restore_defaults()
		close()
		UIRouter.push(ControlsScreen.new()))
	bottom.add_child(restore)
	var done := UIKit.button("Done", "primary")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(close)
	bottom.add_child(done)
	body.add_child(bottom)


static func ensure_actions() -> void:
	for action in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = DEFAULTS[action]
			InputMap.action_add_event(action, ev)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for action in DEFAULTS:
			if cf.has_section_key("keys", action):
				_set_key(action, int(cf.get_value("keys", action)))


static func key_text(action: String) -> String:
	for ev in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if ev.physical_keycode != 0 else code)
	return "—"


static func _set_key(action: String, code: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
			break
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


static func unbind(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)


static func _save() -> void:
	var cf := ConfigFile.new()
	for action in DEFAULTS:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				cf.set_value("keys", action, ev.physical_keycode)
				break
	cf.save(PATH)


static func restore_defaults() -> void:
	for action in DEFAULTS:
		_set_key(action, DEFAULTS[action])
	_save()


static func _owner_of(code: int, except: String) -> String:
	for action in DEFAULTS:
		if action == except:
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.physical_keycode == code:
				return action
	return ""


## The key table, reusable inside Settings.
static func page() -> Control:
	ensure_actions()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	for row in ROWS:
		var name := UIKit.label(row[0], "Strong")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		var keys := Button.new()
		keys.theme_type_variation = "OutlineButton"
		keys.custom_minimum_size = Vector2(150, 42)
		keys.focus_mode = Control.FOCUS_NONE
		var actions: Array = row[1]
		keys.text = "  ".join(actions.map(func(a): return ControlsScreen.key_text(a)))
		grid.add_child(keys)
		var edit := UIKit.icon_button("pencil", "Change %s" % row[0], 42)
		edit.pressed.connect(func() -> void: _capture(keys, actions))
		grid.add_child(edit)
	return grid


static func _capture(keys_btn: Button, actions: Array) -> void:
	var cap := KeyCapture.new()
	cap.actions = actions
	cap.target = keys_btn
	UIRouter.push(cap)
