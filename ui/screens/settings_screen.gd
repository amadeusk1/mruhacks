class_name SettingsScreen
extends UIModal
## Settings: Audio / Controls / Accessibility tabs (board "Settings Pause and Connection States", panel 2).

var _pages: Array[Control] = []
var _mic_button: Button


func _init() -> void:
	setup("Settings", "", 1080, false, true)
	title_label.theme_type_variation = "Title"
	var tabs := UIKit.tab_bar([["Audio", "speaker"], ["Controls", "gamepad"], ["Accessibility", "accessibility"]], _show)
	if UIRouter._in_world():
		# Hide UI sits beside the tabs: the panel already fills the screen's height.
		var top := UIKit.hbox(16)
		tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tabs)
		var hide_btn := UIKit.button("Hide UI", "secondary", "eye", Vector2(230, 76))
		hide_btn.name = "HideUi"
		hide_btn.tooltip_text = "Clears the screen for screenshots and filming. Press Esc to bring it back."
		hide_btn.pressed.connect(UIRouter.hide_ui)
		top.add_child(hide_btn)
		body.add_child(top)
	else:
		body.add_child(tabs)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 500)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.clip_contents = true
	body.add_child(stack)
	var controls := ScrollContainer.new()
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var keys := ControlsScreen.page()
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(keys)
	_pages = [_audio_page(), controls, AccessibilityScreen.page(false)]
	for p in _pages:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)
	_show(0)
	UIRouter.stack_changed.connect(_refresh_mic_label)


func _show(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i


func _audio_page() -> Control:
	var row := UIKit.hbox(16)
	var audio := UIKit.card("Inset")
	audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	audio.size_flags_stretch_ratio = 1.6
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var a := UIKit.vbox(10)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(a)
	audio.add_child(scroll)
	a.add_child(UIKit.label("Audio", "Heading"))
	for it in [["music", "Music", "music"], ["speaker", "Effects", "effects"], ["mic", "Voice", "voice"], ["film", "Movie", "movie"]]:
		var key: String = it[2]
		a.add_child(UIKit.slider_row(it[0], it[1], float(UIRouter.settings[key]), func(v: float) -> void: UIRouter.set_setting(key, v)))
	a.add_child(HSeparator.new())
	var mic_on := bool(UIRouter.settings["mic"])
	var mic := UIKit.toggle_row("mic", "Microphone", mic_on, func(on: bool) -> void:
		UIRouter.set_setting("mic", on), "On" if mic_on else "Muted")
	_watch(mic, "On", "Muted")
	a.add_child(mic)
	var ptt_key := ControlsScreen.key_text("push_to_talk")
	var ptt := UIKit.toggle_row("gamepad", "Push to talk", bool(UIRouter.settings["push_to_talk"]),
		func(on: bool) -> void: UIRouter.set_setting("push_to_talk", on),
		"Hold to talk (%s)" % ptt_key if UIRouter.settings["push_to_talk"] else "Always on")
	_watch(ptt, "Hold to talk (%s)" % ptt_key, "Always on")
	a.add_child(ptt)
	var deaf := UIKit.toggle_row("speaker", "Deafen", Voice.deafened,
		func(on: bool) -> void: Voice.set_deafened(on), "Hearing nobody" if Voice.deafened else "Hearing nearby penguins")
	_watch(deaf, "Hearing nobody", "Hearing nearby penguins")
	a.add_child(deaf)
	a.add_child(_mic_picker())
	row.add_child(audio)
	var acc := AccessibilityScreen.page(true)
	acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(acc)
	return row


func _watch(row: Node, on_text: String, off_text: String) -> void:
	var state := row.get_child(row.get_child_count() - 1) as Label
	var check := row.get_child(row.get_child_count() - 2) as BaseButton
	if state == null or check == null:
		return
	check.toggled.connect(func(on: bool) -> void: state.text = on_text if on else off_text)


func _mic_picker() -> Control:
	var current := MicrophoneScreen.current_device()
	var shown := "System default" if current == "Default" else current
	var choose := MicrophoneScreen.choice_row("Choose microphone", shown)
	_mic_button = choose
	choose.pressed.connect(func() -> void: UIRouter.push(MicrophoneScreen.new()))
	return choose


func _refresh_mic_label() -> void:
	if _mic_button == null:
		return
	var current := MicrophoneScreen.current_device()
	var shown := "System default" if current == "Default" else current
	var detail := _mic_button.find_child("Detail", true, false) as Label
	if detail:
		detail.text = shown
	_mic_button.tooltip_text = "Using %s" % shown
