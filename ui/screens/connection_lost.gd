class_name ConnectionLost
extends UIModal
## Shown when the host drops. Reconnect retries the last join once (bounded); Back to menu exits.

var _retry: Callable
var _status: Label


static func show_lost(message: String, retry: Callable) -> ConnectionLost:
	var d := ConnectionLost.new()
	d._retry = retry
	d.setup("", "", 560, false, false)
	var pic := TextureRect.new()
	pic.texture = UIKit.icon("wifi_off")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0, 110)
	d.body.add_child(pic)
	d.body.add_child(UIKit.label("Connection lost", "Title", HORIZONTAL_ALIGNMENT_CENTER))
	d._status = UIKit.wrap_label(message if message != "" else "We can't reach Pengloo Party right now.\nCheck your connection and try again.", "Subtitle", 480, HORIZONTAL_ALIGNMENT_CENTER)
	d.body.add_child(d._status)
	if retry.is_valid():
		var r := UIKit.button("Reconnect", "primary", "refresh")
		r.pressed.connect(func() -> void:
			d.close()
			retry.call())
		d.body.add_child(r)
	var back := UIKit.button("Back to menu", "secondary", "home")
	back.pressed.connect(func() -> void:
		UIRouter.close_all()
		Net.shutdown()
		d.get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn"))
	d.body.add_child(back)
	UIRouter.push(d)
	return d
