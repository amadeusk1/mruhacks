class_name ActStyle
extends RefCounted
## Builders for the activity/wardrobe/home screens, matching the Pengloo Party UI mockups
## (ivory panels, navy text, teal primary, coral accents, soft rounded corners).
## Thin layer over ui/core (UIKit + pengloo_theme): same tokens, fonts and button variations, plus the
## few activity-specific pieces (filled danger button, stat cards, timer chips, team colours).

# Colours alias ui/core's tokens so activity screens match the shared Pengloo theme exactly.
const T := preload("res://ui/theme/ui_tokens.gd")
const IVORY := T.PANEL
const IVORY_EDGE := T.LINE
const CARD := T.SECONDARY
const CARD_HOVER := T.SECONDARY_HOVER
const NAVY := T.NAVY_TITLE
const SUB := T.SUBTEXT
const MUTED := T.MUTED
const TEAL := T.TEAL
const TEAL_DARK := T.TEAL_PRESSED
const TEAL_SOFT := T.TEAL_SOFT
const CORAL := T.CORAL
const CORAL_DARK := Color("#D6453C")
const CORAL_SOFT := T.CORAL_SOFT
const GREY := T.SECONDARY
const GREY_DARK := T.SECONDARY_PRESSED
const WHITE := Color("#FFFFFF")
const TEAM := {"coral": Color("#EF7766"), "teal": Color("#2AA9A7")}

static var _title_font: Font
static var _body_font: Font
static var _icons := {}


static func title_font() -> Font:
	if _title_font == null:
		# The mockups' headings/buttons are heavy; core's variable-font "bold" renders light here, so use the static Bold.
		_title_font = load("res://fonts/Fredoka-Bold.ttf")
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = UIKit.THEME.get_font("font", "Body")
	return _body_font


static func icon_tex(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var p := "res://ui/icons/%s.svg" % icon_name
		_icons[icon_name] = load(p) if ResourceLoader.exists(p) else null
	return _icons[icon_name]


# ------------------------------------------------------------------ boxes --
static func box(bg: Color, radius := 22, border := 0, border_color := Color.TRANSPARENT, pad := 0, shadow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Color(0.08, 0.16, 0.24, 0.16)
		s.shadow_size = 14
		s.shadow_offset = Vector2(0, 5)
	return s


static func panel(pad := 26, radius := T.RADIUS_CARD) -> PanelContainer:
	var p := UIKit.card()
	var sb := (UIKit.THEME.get_stylebox("panel", "Card") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.set_content_margin_all(pad)
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func card_box(selected := false, radius := 16) -> StyleBoxFlat:
	return box(CARD, radius, 3 if selected else 0, TEAL if selected else Color.TRANSPARENT, 8)


# ------------------------------------------------------------------ text --
static func label(text: String, size := 18, color := NAVY, heading := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", title_font() if heading else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size := 34, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return label(text, size, NAVY, true, align)


# ------------------------------------------------------------------ icons --
static func icon(icon_name: String, size := 22, color := NAVY) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_tex(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# ------------------------------------------------------------------ buttons --
## kind: primary (teal), secondary (beige), danger (filled coral), light (white outline chip), ghost (quiet).
static func button(text: String, kind := "primary", icon_name := "", font_size := 22, min_size := Vector2(0, 52)) -> Button:
	var core_kind: String = {"primary": "primary", "secondary": "secondary", "light": "outline", "ghost": "quiet",
		"danger": "secondary"}.get(kind, "secondary")
	var b := UIKit.button(text, core_kind, "", min_size)
	if icon_name != "":
		b.icon = icon_tex(icon_name)
		b.expand_icon = false
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("icon_max_width", int(font_size * 1.1))
	if kind == "danger":   # mockups' Remove / Leave seat / Leave are solid coral
		var radius := T.RADIUS_BUTTON
		for st in [["normal", CORAL], ["hover", CORAL.lightened(0.08)], ["pressed", CORAL.darkened(0.08)]]:
			b.add_theme_stylebox_override(st[0], box(st[1], radius, 0, Color.TRANSPARENT, 14))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(c, WHITE)
	if kind == "light":    # white chips that sit directly on the 3D scene
		for st in ["normal", "hover", "pressed"]:
			var sb := (UIKit.THEME.get_stylebox(st, "OutlineButton") as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.bg_color = WHITE if st != "pressed" else T.SECONDARY
			sb.shadow_color = T.SHADOW
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(0, 2)
			b.add_theme_stylebox_override(st, sb)
	return b


## Bare navy close (X) glyph used at the top-right of every panel (soft circle on hover).
static func close_button(size := 44) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.icon = icon_tex("close")
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.flat = false
	b.tooltip_text = "Close"
	b.focus_mode = Control.FOCUS_ALL
	var clear := box(Color.TRANSPARENT, size / 2, 0, Color.TRANSPARENT, int(size * 0.22))
	var hover := box(Color(0.08, 0.19, 0.29, 0.08), size / 2, 0, Color.TRANSPARENT, int(size * 0.22))
	b.add_theme_stylebox_override("normal", clear)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, size / 2, 3, NAVY, 0))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, NAVY)
	return b


## Round white close button for panels that sit directly on the 3D scene (home/decorate boards).
static func close_disc(size := 52) -> Button:
	var b := close_button(size)
	b.add_theme_stylebox_override("normal", box(WHITE, size / 2, 0, Color.TRANSPARENT, int(size * 0.26), true))
	b.add_theme_stylebox_override("hover", box(Color("#F3EEE4"), size / 2, 0, Color.TRANSPARENT, int(size * 0.26), true))
	return b


## Small rounded white chip with an icon and label, e.g. "Rotate", "Undo", "Leave".
static func chip_button(text: String, icon_name := "", kind := "light", font_size := 17) -> Button:
	return button(text, kind, icon_name, font_size, Vector2(0, 46))


## Pill tab (Color / Hats / ...). Selected tabs are teal with white text.
static func tab(text: String, icon_name: String, selected: bool) -> Button:
	var b := button(text, "primary" if selected else "secondary", icon_name, 17, Vector2(0, 42))
	b.add_theme_constant_override("icon_max_width", 26)
	b.toggle_mode = true
	b.button_pressed = selected
	return b


# ------------------------------------------------------------------ chips --
static func chip(text: String, bg := WHITE, fg := NAVY, icon_name := "", size := 17, pad := Vector2(16, 8)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, 14, 0, Color.TRANSPARENT, 0)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.shadow_color = Color(0.08, 0.16, 0.24, 0.10)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	if icon_name != "":
		row.add_child(icon(icon_name, size + 3, fg))
	var l := label(text, size, fg, true)
	l.name = "Text"
	row.add_child(l)
	return p


## Coral-pink countdown chip ("00:23") from the drawing/sketch boards.
static func timer_chip(text: String) -> PanelContainer:
	return chip(text, CORAL_SOFT, Color("#D4483A"), "clock", 26, Vector2(20, 8))


## White stat card with a small caption over a big number ("Time / 00:18.4").
static func stat_card(caption: String, value: String, value_size := 36) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(IVORY, 18, 0, Color.TRANSPARENT, 14, true))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	p.add_child(v)
	v.add_child(label(caption, 15, NAVY, false))
	var val := label(value, value_size, NAVY, true)
	val.name = "Value"
	v.add_child(val)
	return p


# ------------------------------------------------------------------ layout --
static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12, align := BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.alignment = align
	return h


static func spacer(w := 0.0, h := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Places `child` inside `root` with anchors (0..1) and pixel offsets, like the mockup layouts.
static func pin(root: Control, child: Control, anchor: Vector4, offsets := Vector4.ZERO) -> Control:
	root.add_child(child)
	child.anchor_left = anchor.x
	child.anchor_top = anchor.y
	child.anchor_right = anchor.z
	child.anchor_bottom = anchor.w
	child.offset_left = offsets.x
	child.offset_top = offsets.y
	child.offset_right = offsets.z
	child.offset_bottom = offsets.w
	return child


## Full-rect transparent root for a screen; stops world clicks only where panels are.
static func screen_root() -> Control:
	var r := Control.new()
	r.theme = UIKit.THEME
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Selected-state check badge in a card corner.
static func check_badge(size := 28) -> TextureRect:
	var t := icon("check_badge", size, TEAL)
	t.name = "Check"
	return t


## Manifest thumbnail for an asset id ("avatar/red_beanie"), or null.
## Cropped to its visible pixels (thumbnails ship with generous transparent margins).
static func asset_icon(asset_id: String) -> Texture2D:
	if _icons.has("asset:" + asset_id):
		return _icons["asset:" + asset_id]
	var p := "res://Models/%s/icons/%s.png" % [asset_id.get_slice("/", 0), asset_id.get_slice("/", 1)]
	var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
	if tex:
		var img := tex.get_image()
		if img:
			var used := img.get_used_rect().grow(6).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			if used.size.x > 8 and used.size.y > 8:
				tex = ImageTexture.create_from_image(img.get_region(used))
	_icons["asset:" + asset_id] = tex
	return tex
