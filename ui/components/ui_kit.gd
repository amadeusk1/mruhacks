class_name UIKit
## Factory helpers for Pengloo Party UI. Every look comes from pengloo_theme.tres type variations,
## so screens stay consistent: build with these instead of styling nodes by hand.

const THEME := preload("res://ui/theme/pengloo_theme.tres")
const T := preload("res://ui/theme/ui_tokens.gd")


## Anchor a control to a point of its parent (0..1 each axis) with a pixel offset of its centre.
static func pin(c: Control, anchor: Vector2, centre_offset: Vector2, size: Vector2) -> Control:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = centre_offset.x - size.x * 0.5
	c.offset_right = centre_offset.x + size.x * 0.5
	c.offset_top = centre_offset.y - size.y * 0.5
	c.offset_bottom = centre_offset.y + size.y * 0.5
	return c


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func icon(name: String) -> Texture2D:
	return load("res://ui/icons/%s.svg" % name) as Texture2D


static func label(text: String, variation := "Body", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l


static func wrap_label(text: String, variation := "Body", width := 300.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, variation, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


## kind: "primary" | "secondary" | "quiet" | "outline" | "danger" | "tab" | "hero"
static func button(text: String, kind := "secondary", icon_name := "", min_size := Vector2(0, 76), icon_after := false) -> Button:
	var b: Button = IconTextButton.new(text, icon(icon_name), icon_after) if icon_name != "" and text != "" else Button.new()
	if not (b is IconTextButton):
		b.text = text
	b.theme_type_variation = {"primary": "PrimaryButton", "secondary": "", "quiet": "QuietButton", "outline": "OutlineButton",
		"danger": "DangerButton", "tab": "TabButton", "hero": "HeroButton"}.get(kind, "")
	if icon_name != "" and text == "":
		b.icon = icon(icon_name)
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	if kind == "tab":
		b.toggle_mode = true
	return b


static func icon_button(icon_name: String, tooltip := "", size := 58.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = "IconButton"
	b.icon = icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tooltip
	return b


## Icon over label, used by the HUD dock (Map / Outfit / Home / Friends / Emotes).
static func dock_button(text: String, icon_name: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "DockButton"
	b.text = text
	b.icon = icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = false
	b.custom_minimum_size = Vector2(150, 104)
	return b


## Segmented tabs: returns the HBox; children are toggle buttons sharing one ButtonGroup.
static func tab_bar(items: Array, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in items.size():
		var it = items[i]
		var b := button(str(it[0]), "tab", str(it[1]) if it.size() > 1 else "", Vector2(0, 64))
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	(row.get_child(0) as Button).button_pressed = true
	return row


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func gap(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	return c


static func card(variation := "Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


## Text field with an inline error line underneath. Returns {root, field, error}.
static func field(placeholder: String, value := "", edit_icon := true) -> Dictionary:
	var root := vbox(6)
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.text = value
	f.custom_minimum_size = Vector2(0, 64)
	if edit_icon:
		f.right_icon = icon("pencil")
		f.add_theme_color_override("clear_button_color", T.NAVY)
	root.add_child(f)
	var err := label("", "Muted")
	err.add_theme_color_override("font_color", Color("#D6453C"))
	err.visible = false
	root.add_child(err)
	return {"root": root, "field": f, "error": err}


static func set_field_error(f: Dictionary, message: String) -> void:
	(f["error"] as Label).text = message
	(f["error"] as Label).visible = message != ""
	(f["field"] as LineEdit).theme_type_variation = "LineEditError" if message != "" else ""


## Icon + name + slider + percentage, as on the Settings > Audio board.
static func slider_row(icon_name: String, text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := hbox(14)
	row.add_child(_glyph(icon_name, 28, T.NAVY))
	var name := label(text, "Body")
	name.custom_minimum_size.x = 110
	row.add_child(name)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(200, 30)
	row.add_child(s)
	var pct := label("%d%%" % int(value), "Muted", HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size.x = 64
	row.add_child(pct)
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(v)
		on_change.call(v))
	return row


## Icon + text + toggle (+ optional state text), as on Settings / Accessibility.
static func toggle_row(icon_name: String, text: String, on: bool, on_change: Callable, state_text := "", subtitle := "") -> HBoxContainer:
	var row := hbox(14)
	if icon_name != "":
		row.add_child(_glyph(icon_name, 28, T.NAVY))
	var col := vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(label(text, "Strong" if subtitle != "" else "Body"))
	if subtitle != "":
		col.add_child(label(subtitle, "Muted"))
	row.add_child(col)
	var t := CheckButton.new()
	t.button_pressed = on
	t.focus_mode = Control.FOCUS_ALL
	row.add_child(t)
	if state_text != "":
		var st := label(state_text, "Muted")
		st.custom_minimum_size.x = 120
		row.add_child(st)
	t.toggled.connect(on_change)
	return row


static func _glyph(icon_name: String, px: float, color: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = color
	return r


static func glyph(icon_name: String, px := 24.0, color := T.NAVY) -> TextureRect:
	return _glyph(icon_name, px, color)


## Round colour swatch (body colour picker). Selected = navy-teal ring like the mockup.
static func swatch(color: Color, on_pick: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 60)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.06) if s == "hover" else color
		box.set_corner_radius_all(99)
		box.anti_aliasing = true
		if s in ["pressed", "hover_pressed"]:
			box.set_border_width_all(4)
			box.border_color = Color.WHITE
			box.expand_margin_left = 5
			box.expand_margin_right = 5
			box.expand_margin_top = 5
			box.expand_margin_bottom = 5
			box.shadow_color = Color("#127F84")
			box.shadow_size = 5
		if s == "focus":
			box.draw_center = false
			box.set_border_width_all(3)
			box.border_color = T.TEAL
			box.expand_margin_left = 6
			box.expand_margin_right = 6
			box.expand_margin_top = 6
			box.expand_margin_bottom = 6
		b.add_theme_stylebox_override(s, box)
	b.pressed.connect(on_pick)
	return b


## Cream pill with optional leading icon (location chip, map labels).
static func chip(text: String, icon_name := "", font_size := 18) -> PanelContainer:
	var p := card("Chip")
	var row := hbox(8)
	if icon_name != "":
		row.add_child(_glyph(icon_name, font_size + 4, T.NAVY_TITLE))
	var l := label(text, "Strong")
	l.add_theme_font_size_override("font_size", font_size)
	row.add_child(l)
	p.add_child(row)
	return p


## Status dot + text, e.g. "● In town".
static func status(text: String, color: Color) -> HBoxContainer:
	var row := hbox(6)
	var dot := Panel.new()
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(99)
	dot.add_theme_stylebox_override("panel", b)
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	row.add_child(label(text, "Muted"))
	return row


## Centred modal card over a soft dim. Content goes in the returned "body" VBox.
static func modal(title: String, subtitle := "", width := 520.0, closable := true, back := false) -> UIModal:
	var m := UIModal.new()
	m.setup(title, subtitle, width, closable, back)
	return m
