class_name UIWidgets
## Larger reusable pieces built on UIKit: state panel, toast, item card, side panel, result rows.

const T := preload("res://ui/theme/ui_tokens.gd")


## Loading / empty / error panel. kind: "loading" | "empty" | "error".
## actions: Array of [text, kind, Callable] buttons (e.g. Retry, Back).
static func state_panel(kind: String, title: String, message: String, actions: Array = []) -> PanelContainer:
	var p := UIKit.card("ErrorBox" if kind == "error" else "Inset")
	var row := UIKit.hbox(14)
	p.add_child(row)
	if kind == "loading":
		row.add_child(Spinner.new())
	else:
		var badge := UIKit.glyph("close" if kind == "error" else "sparkle", 22, Color.WHITE)
		var circle := PanelContainer.new()
		var b := StyleBoxFlat.new()
		b.bg_color = Color("#E2534A") if kind == "error" else T.TEAL
		b.set_corner_radius_all(99)
		b.content_margin_left = 8
		b.content_margin_right = 8
		b.content_margin_top = 8
		b.content_margin_bottom = 8
		circle.add_theme_stylebox_override("panel", b)
		circle.add_child(badge)
		circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(circle)
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(title, "Strong"))
	col.add_child(UIKit.wrap_label(message, "Muted", 220))
	for a in actions:
		var btn := UIKit.button(str(a[0]), str(a[1]), "", Vector2(0, 40))
		btn.pressed.connect(a[2])
		col.add_child(btn)
	row.add_child(col)
	return p


## Short message at the top centre that fades out. Truthful feedback only.
static func toast(host: Node, text: String, icon_name := "check", seconds := 2.6) -> void:
	var layer: Node = UIRouter
	var chip := UIKit.chip(text, icon_name, 18)
	chip.theme = UIKit.THEME
	chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	chip.position = Vector2(-140, 22)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(chip)
	chip.position.x = (chip.get_viewport_rect().size.x - chip.get_combined_minimum_size().x) * 0.5
	var tw := chip.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(chip, "modulate:a", 0.0, 0.35)
	tw.tween_callback(chip.queue_free)


## Square card with a thumbnail and caption (emotes, wardrobe, inventory).
static func item_card(texture: Texture2D, caption: String, on_pick: Callable, size := Vector2(92, 104)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.theme_type_variation = "OutlineButton"
	b.toggle_mode = false
	var col := UIKit.vbox(2)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var pic := TextureRect.new()
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(size.x - 18, size.y - 34)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var cap := UIKit.label(caption, "Body", HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_size_override("font_size", 15)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)
	b.add_child(col)
	b.pressed.connect(on_pick)
	return b


## Panel docked to one side of the screen (Friends list).
static func side_panel(title: String, icon_name: String, width := 440.0) -> Dictionary:
	var root := UIModal.new()
	root.setup("", "", width, false, false)
	root.dim.color = Color(0, 0, 0, 0)
	root.blocks_world = false
	var center: Control = root.card.get_parent()
	center.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	center.offset_left = 22
	center.offset_top = 22
	center.offset_bottom = -22
	center.offset_right = 22 + width
	var head := UIKit.hbox(10)
	head.add_child(UIKit.glyph(icon_name, 28, T.NAVY_TITLE))
	head.add_child(UIKit.label(title, "Heading"))
	head.add_child(UIKit.spacer())
	var x := UIKit.icon_button("close", "Close", 40)
	x.pressed.connect(root.close)
	head.add_child(x)
	root.body.add_child(head)
	return {"root": root, "body": root.body}


## Coral/teal score row used by the shared results screen.
static func score_row(name: String, score: int, team_color: Color, portrait: Texture2D = null) -> PanelContainer:
	var p := PanelContainer.new()
	var b := StyleBoxFlat.new()
	b.bg_color = team_color
	b.set_corner_radius_all(18)
	b.content_margin_left = 14
	b.content_margin_right = 8
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", b)
	var row := UIKit.hbox(14)
	p.add_child(row)
	row.add_child(Portrait.make(portrait, team_color.lightened(0.5), 66))
	var n := UIKit.label(name, "Heading")
	n.add_theme_color_override("font_color", Color.WHITE)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var sbox := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = team_color.lightened(0.82)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sbox.add_theme_stylebox_override("panel", sb)
	var s := UIKit.label(str(score), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	s.add_theme_font_size_override("font_size", 46)
	sbox.add_child(s)
	row.add_child(sbox)
	return p
