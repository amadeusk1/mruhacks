class_name UIModal
extends Control
## Dimmed overlay with one centred card: title, optional subtitle, back/close buttons, body VBox.
## Registers with UIRouter so Escape closes the top modal and world input pauses while it is open.

signal closed

const T := preload("res://ui/theme/ui_tokens.gd")

var body: VBoxContainer
var card: PanelContainer
var title_label: Label
var subtitle_label: Label
var close_button: Button
var back_button: Button
var dim: ColorRect
var brand: HBoxContainer   # "🐧 PENGLOO PARTY" eyebrow some boards show above the title
var on_back: Callable
## Shown in the router stack; false keeps world movement running (e.g. non-blocking panels).
var blocks_world := true


func setup(title: String, subtitle := "", width := 520.0, closable := true, back := false) -> void:
	theme = UIKit.THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = T.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = UIKit.card()
	card.custom_minimum_size.x = width
	center.add_child(card)
	var col := UIKit.vbox(14)
	card.add_child(col)
	var head := Control.new()
	head.custom_minimum_size.y = 60 if (closable or back or title != "") else 0
	col.add_child(head)
	title_label = UIKit.label(title, "TitleSmall", HORIZONTAL_ALIGNMENT_CENTER)
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(title_label)
	if back:
		back_button = UIKit.icon_button("back", "Back")
		back_button.position = Vector2(-6, 0)
		back_button.pressed.connect(func() -> void:
			if on_back.is_valid(): on_back.call()
			else: close())
		head.add_child(back_button)
	if closable:
		close_button = UIKit.icon_button("close", "Close", 54)
		close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		close_button.position = Vector2(-48, 2)
		close_button.pressed.connect(close)
		head.add_child(close_button)
	brand = UIKit.hbox(8)
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	var face := PenguinFace.new()
	face.body = T.NAVY_TITLE
	face.custom_minimum_size = Vector2(30, 30)
	brand.add_child(face)
	brand.add_child(UIKit.label("PENGLOO PARTY", "Eyebrow"))
	brand.visible = false
	col.add_child(brand)
	col.move_child(brand, 0)
	subtitle_label = UIKit.label(subtitle, "Subtitle", HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.visible = subtitle != ""
	col.add_child(subtitle_label)
	body = UIKit.vbox(12)
	col.add_child(body)


## Show on the router's overlay layer.
func open() -> UIModal:
	UIRouter.push(self)
	return self


func close() -> void:
	UIRouter.remove(self)
	closed.emit()
	queue_free()
