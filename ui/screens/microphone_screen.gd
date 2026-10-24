class_name MicrophoneScreen
extends UIModal
## Mic permission/device panel. Voice isn't implemented yet: "Enable microphone" records the
## preference and lists real input devices, but never claims voice is live.

func _init() -> void:
	setup("MICROPHONE", "Voice chat helps you waddle together.", 700, true, false)
	title_label.theme_type_variation = "Title"
	brand.visible = true
	var badge := TextureRect.new()
	badge.texture = UIKit.icon("mic_off_badge")
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(0, 110)
	body.add_child(badge)
	var on := bool(UIRouter.settings["mic"])
	body.add_child(UIKit.label("Microphone access is %s." % ("on" if on else "off"), "Heading", HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UIKit.label("You can still play without voice.", "Subtitle", HORIZONTAL_ALIGNMENT_CENTER))
	var enable := UIKit.button("Enable microphone", "primary")
	enable.pressed.connect(func() -> void:
		UIRouter.set_setting("mic", true)
		UIWidgets.toast(self, "Saved. Voice chat is coming soon.", "mic")
		close())
	body.add_child(enable)
	var keep := UIKit.button("Keep muted", "secondary")
	keep.pressed.connect(func() -> void:
		UIRouter.set_setting("mic", false)
		close())
	body.add_child(keep)
	body.add_child(HSeparator.new())
	body.add_child(UIKit.label("Input device", "Strong"))
	var dev := OptionButton.new()
	dev.custom_minimum_size.y = 62
	for d in AudioServer.get_input_device_list():
		dev.add_item("Default device" if d == "Default" else d)
	body.add_child(dev)
