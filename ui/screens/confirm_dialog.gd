class_name ConfirmDialog
extends UIModal
## "Leave this activity?" style confirmation: safe choice is the primary button.

signal confirmed


static func ask(title: String, message: String, stay_text := "Stay", go_text := "Leave", go_icon := "leave") -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.setup(title, message, 420, true, false)
	d.title_label.theme_type_variation = "TitleSmall"
	var stay := UIKit.button(stay_text, "primary")
	stay.pressed.connect(d.close)
	d.body.add_child(stay)
	var go := UIKit.button(go_text, "secondary", go_icon)
	go.pressed.connect(func() -> void:
		d.confirmed.emit()
		d.close())
	d.body.add_child(go)
	UIRouter.push(d)
	return d
