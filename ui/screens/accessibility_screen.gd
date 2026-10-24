class_name AccessibilityScreen
extends UIModal
## Text size, reduce motion, high contrast, UI scale + live preview (Controls & Accessibility board).



func _init() -> void:
	setup("ACCESSIBILITY", "Make Pengloo Party comfortable for you.", 760, false, false)
	title_label.theme_type_variation = "Title"
	brand.visible = true
	body.add_child(page(false))
	var done := UIKit.button("Done", "primary")
	done.pressed.connect(close)
	body.add_child(done)


static func page(compact: bool) -> Control:
	var col := UIKit.vbox(14)
	var box: Control = col
	if compact:
		box = UIKit.card("Inset")
	if compact:
		box.add_child(col)
		col.add_child(UIKit.label("Accessibility", "Heading"))
	var size_row := UIKit.hbox(10)
	size_row.add_child(UIKit.label("Text size", "Strong" if not compact else "Body"))
	size_row.add_child(UIKit.spacer())
	var group := ButtonGroup.new()
	var labels: Array = ["A", "A", "A"] if compact else ["Small", "Medium", "Large"]
	for i in 3:
		var b := UIKit.button(labels[i], "tab", "", Vector2(54 if compact else 130, 56))
		b.button_group = group
		if compact:
			b.add_theme_font_size_override("font_size", [14, 18, 22][i])
		b.button_pressed = int(UIRouter.settings["text_size"]) == i
		b.pressed.connect(func() -> void: UIRouter.set_setting("text_size", i))
		size_row.add_child(b)
	col.add_child(size_row)
	col.add_child(UIKit.toggle_row("accessibility" if compact else "", "Reduce motion", bool(UIRouter.settings["reduce_motion"]),
		func(on: bool) -> void: UIRouter.set_setting("reduce_motion", on), "", "" if compact else "Limit camera and UI animations."))
	col.add_child(UIKit.toggle_row("eye" if compact else "", "High contrast", bool(UIRouter.settings["high_contrast"]),
		func(on: bool) -> void: UIRouter.set_setting("high_contrast", on), "", "" if compact else "Increase contrast for better visibility."))
	if not compact:
		var scale_row := UIKit.hbox(14)
		scale_row.add_child(UIKit.label("UI scale", "Strong"))
		var s := HSlider.new()
		s.min_value = 80
		s.max_value = 130
		s.step = 5
		s.value = float(UIRouter.settings["ui_scale"])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		scale_row.add_child(s)
		var pct := UIKit.label("%d%%" % int(s.value), "Strong")
		scale_row.add_child(pct)
		# apply on release so the panel doesn't rescale under the cursor mid-drag
		s.value_changed.connect(func(v: float) -> void: pct.text = "%d%%" % int(v))
		s.drag_ended.connect(func(_c: bool) -> void: UIRouter.set_setting("ui_scale", s.value))
		col.add_child(scale_row)
		var preview := UIKit.card("Inset")
		var pv := UIKit.vbox(4)
		pv.add_child(UIKit.label("Preview text", "Heading", HORIZONTAL_ALIGNMENT_CENTER))
		pv.add_child(UIKit.label("This is how UI text will look in game.", "Subtitle", HORIZONTAL_ALIGNMENT_CENTER))
		preview.add_child(pv)
		col.add_child(preview)
	return box
