class_name MicrophoneScreen
extends UIModal
## Microphone picker. Rows stay outline-style; the chosen one is a soft teal row with a check.
## Enable is the only solid action, so it doesn't get mistaken for a device.

const ROW_H := 52
const ROW_GAP := 8
const VISIBLE_ROWS := 5

var _scroll: ScrollContainer


func _init() -> void:
	setup("Microphone", "Pick the one you want to use.", 720, true, false)
	title_label.theme_type_variation = "Title"
	brand.visible = true
	body.add_theme_constant_override("separation", 12)
	var devs := AudioServer.get_input_device_list()
	var current := current_device()
	if devs.is_empty():
		body.add_child(UIKit.label("No microphones found. Plug one in, then reopen this menu.", "Muted"))
	else:
		var scroll := ScrollContainer.new()
		_scroll = scroll
		scroll.custom_minimum_size = Vector2(0, VISIBLE_ROWS * ROW_H + (VISIBLE_ROWS - 1) * ROW_GAP)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := UIKit.vbox(ROW_GAP)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for d in devs:
			var name := str(d)
			var label := "System default" if name == "Default" else name
			var row := _device_row(label, name == current)
			row.pressed.connect(_pick.bind(name))
			list.add_child(row)
		body.add_child(scroll)
	var actions := UIKit.hbox(12)
	var enable := UIKit.button("Enable microphone" if not UIRouter.settings["mic"] else "Mute microphone", "primary" if not UIRouter.settings["mic"] else "secondary", "mic", Vector2(0, 56))
	enable.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable.pressed.connect(func() -> void:
		UIRouter.set_setting("mic", not bool(UIRouter.settings["mic"]))
		_reopen())
	actions.add_child(enable)
	var done := UIKit.button("Done", "secondary", "", Vector2(160, 56))
	done.pressed.connect(close)
	actions.add_child(done)
	body.add_child(actions)


static func current_device() -> String:
	var devs := AudioServer.get_input_device_list()
	var want := str(UIRouter.settings.get("mic_device", "Default"))
	if devs.has(want):
		return want
	if devs.has("Default"):
		return "Default"
	return str(devs[0]) if not devs.is_empty() else "Default"


## Settings uses this: a full-width row, device name under the title, chevron on the right.
static func choice_row(title: String, detail: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "OutlineButton"
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_ALL
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var heading := UIKit.label(title, "Strong")
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(heading)
	var sub := UIKit.label(detail, "Muted")
	sub.name = "Detail"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.add_theme_font_size_override("font_size", 18)
	text.add_child(sub)
	row.add_child(text)
	row.add_child(UIKit.glyph("chevron_right", 18, UITokens.MUTED))
	b.add_child(row)
	return b


func _device_row(label: String, selected: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "OutlineButton"
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = UITokens.TEAL_SOFT if state != "normal" and state != "focus" else UITokens.TEAL_SELECT
			box.set_corner_radius_all(16)
			box.set_border_width_all(3)
			box.border_color = UITokens.TEAL
			b.add_theme_stylebox_override(state, box)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := UIKit.label(label, "Strong")
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 22)
	row.add_child(name)
	if selected:
		row.add_child(UIKit.glyph("check", 20, UITokens.TEAL))
	b.add_child(row)
	return b


func _pick(name: String) -> void:
	UIRouter.set_setting("mic_device", name)
	_reopen()


func _reopen() -> void:
	close()
	UIRouter.push(MicrophoneScreen.new())
