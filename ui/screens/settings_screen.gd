class_name SettingsScreen
extends UIModal
## Settings: Audio / Controls / Accessibility tabs (board "Settings Pause and Connection States", panel 2).

var _pages: Array[Control] = []


func _init() -> void:
	setup("Settings", "", 1080, false, true)
	title_label.theme_type_variation = "Title"
	body.add_child(UIKit.tab_bar([["Audio", "speaker"], ["Controls", "gamepad"], ["Accessibility", "accessibility"]], _show))
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 500)
	body.add_child(stack)
	_pages = [_audio_page(), ControlsScreen.page(), AccessibilityScreen.page(false)]
	for p in _pages:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)
	_show(0)


func _show(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i


func _audio_page() -> Control:
	var row := UIKit.hbox(16)
	var audio := UIKit.card("Inset")
	audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio.size_flags_stretch_ratio = 1.6
	var a := UIKit.vbox(10)
	audio.add_child(a)
	a.add_child(UIKit.label("Audio", "Heading"))
	for it in [["music", "Music", "music"], ["speaker", "Effects", "effects"], ["mic", "Voice", "voice"], ["film", "Movie", "movie"]]:
		var key: String = it[2]
		a.add_child(UIKit.slider_row(it[0], it[1], float(UIRouter.settings[key]), func(v: float) -> void: UIRouter.set_setting(key, v)))
	a.add_child(HSeparator.new())
	var mic := UIKit.toggle_row("mic", "Microphone", bool(UIRouter.settings["mic"]), func(on: bool) -> void:
		UIRouter.set_setting("mic", on), "Muted" if not UIRouter.settings["mic"] else "On")
	a.add_child(mic)
	var ptt_key := ControlsScreen.key_text("push_to_talk")
	a.add_child(UIKit.toggle_row("gamepad", "Push to talk", bool(UIRouter.settings["push_to_talk"]),
		func(on: bool) -> void: UIRouter.set_setting("push_to_talk", on), "Hold to talk (%s)" % ptt_key))
	a.add_child(UIKit.toggle_row("speaker", "Deafen", Voice.deafened,
		func(on: bool) -> void: Voice.set_deafened(on), "Hearing nobody" if Voice.deafened else "Hearing nearby penguins"))
	row.add_child(audio)
	var acc := AccessibilityScreen.page(true)
	acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(acc)
	return row
