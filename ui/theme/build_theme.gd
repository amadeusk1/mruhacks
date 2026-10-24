extends SceneTree
## Regenerates res://ui/theme/pengloo_theme.tres from UITokens.
## Run: Godot --headless --path . --script res://ui/theme/build_theme.gd

const T := preload("res://ui/theme/ui_tokens.gd")
const OUT := "res://ui/theme/pengloo_theme.tres"


func _init() -> void:
	var th := Theme.new()
	var base: FontFile = load("res://fonts/Fredoka-Variable.ttf")
	var body := FontVariation.new()
	body.base_font = base
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	body.variation_opentype = {wght: 520}
	var bold := FontVariation.new()
	bold.base_font = base
	bold.variation_opentype = {wght: 700}
	th.default_font = body
	th.default_font_size = 22

	# --- labels ---------------------------------------------------------------
	th.set_color("font_color", "Label", T.NAVY)
	_label(th, "Title", bold, 52, T.NAVY_TITLE)
	_label(th, "TitleSmall", bold, 46, T.NAVY_TITLE)
	_label(th, "Heading", bold, 32, T.NAVY_TITLE)
	_label(th, "Subtitle", body, 24, T.SUBTEXT)
	_label(th, "Muted", body, 20, T.MUTED)
	_label(th, "Eyebrow", bold, 15, T.MUTED)
	_label(th, "Body", body, 24, T.NAVY)
	_label(th, "Strong", bold, 26, T.NAVY)
	_label(th, "Wordmark", bold, 96, T.NAVY_TITLE)
	th.set_constant("outline_size", "Wordmark", 0)

	# --- panels -----------------------------------------------------------------
	th.set_stylebox("panel", "PanelContainer", _box(T.PANEL, T.RADIUS_CARD, 28, 24, true))
	th.set_type_variation("Card", "PanelContainer")
	th.set_stylebox("panel", "Card", _box(T.PANEL, T.RADIUS_CARD, 36, 30, true))
	th.set_type_variation("Row", "PanelContainer")
	th.set_stylebox("panel", "Row", _box(T.PANEL_ROW, 16, 14, 10, false, T.LINE, 2))
	th.set_type_variation("RowSelected", "PanelContainer")
	th.set_stylebox("panel", "RowSelected", _box(T.TEAL_SELECT, 16, 14, 10, false, T.TEAL, 3))
	th.set_type_variation("Inset", "PanelContainer")
	th.set_stylebox("panel", "Inset", _box(Color("#F6EFE4"), 18, 18, 14, false, T.LINE, 2))
	th.set_type_variation("Chip", "PanelContainer")
	th.set_stylebox("panel", "Chip", _box(T.PANEL, 22, 16, 7, true))
	th.set_type_variation("ErrorBox", "PanelContainer")
	th.set_stylebox("panel", "ErrorBox", _box(Color("#FDE4E0"), 16, 16, 12, false, Color("#F7B7AE"), 2))

	# --- buttons -----------------------------------------------------------------
	_button(th, "Button", T.SECONDARY, T.SECONDARY_HOVER, T.SECONDARY_PRESSED, T.NAVY, bold, 28)
	_button(th, "PrimaryButton", T.TEAL, T.TEAL_HOVER, T.TEAL_PRESSED, Color.WHITE, bold, 29)
	_button(th, "QuietButton", Color(1, 1, 1, 0), T.SECONDARY, T.SECONDARY_PRESSED, T.NAVY, bold, 23)
	_button(th, "OutlineButton", T.PANEL_ROW, T.SECONDARY_HOVER, T.SECONDARY, T.NAVY, bold, 23, T.LINE)
	_button(th, "DangerButton", Color("#FFF6F4"), Color("#FDE8E4"), Color("#F9D6D0"), Color("#D6453C"), bold, 22, Color("#E2534A"))
	_button(th, "TabButton", T.SECONDARY, T.SECONDARY_HOVER, T.TEAL, T.NAVY, bold, 22)
	th.set_color("font_pressed_color", "TabButton", Color.WHITE)
	th.set_color("icon_pressed_color", "TabButton", Color.WHITE)
	th.set_color("font_hover_pressed_color", "TabButton", Color.WHITE)
	th.set_color("icon_hover_pressed_color", "TabButton", Color.WHITE)
	th.set_stylebox("hover_pressed", "TabButton", _btn(T.TEAL_HOVER, T.RADIUS_BUTTON))
	# big hero button on the main menu: white rim like the mockup
	_button(th, "HeroButton", Color("#22AFA1"), Color("#2BBDAF"), Color("#1A9488"), Color.WHITE, bold, 50)
	for s in ["normal", "hover", "pressed", "focus"]:
		var b: StyleBoxFlat = th.get_stylebox(s, "HeroButton").duplicate()
		b.set_corner_radius_all(34)
		b.set_border_width_all(5)
		b.border_color = Color.WHITE
		b.content_margin_left = 44
		b.content_margin_right = 52
		b.content_margin_top = 14
		b.content_margin_bottom = 14
		th.set_stylebox(s, "HeroButton", b)
	# round icon button (back, close, mic)
	th.set_type_variation("IconButton", "Button")
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill: Color = {"normal": Color("#EEE6DB"), "hover": Color("#F5EEE5"), "pressed": Color("#E2D6C6"),
			"disabled": T.DISABLED, "focus": Color("#EEE6DB")}[s]
		var b := _btn(fill, 99)
		b.content_margin_left = 10
		b.content_margin_right = 10
		b.content_margin_top = 10
		b.content_margin_bottom = 10
		if s == "focus":
			b.draw_center = false
			b.set_border_width_all(3)
			b.border_color = T.TEAL
		th.set_stylebox(s, "IconButton", b)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		th.set_color(c, "IconButton", T.NAVY)
	th.set_constant("icon_max_width", "IconButton", 30)
	# HUD dock tile: icon over label
	th.set_type_variation("DockButton", "Button")
	for s in ["normal", "hover", "pressed", "focus"]:
		var fill: Color = {"normal": Color("#FDF8F2"), "hover": Color.WHITE, "pressed": Color("#EFE6DA"), "focus": Color("#FDF8F2")}[s]
		var b := _btn(fill, 16, true)
		b.content_margin_top = 8
		b.content_margin_bottom = 6
		if s == "focus":
			b.set_border_width_all(3)
			b.border_color = T.TEAL
		th.set_stylebox(s, "DockButton", b)
	th.set_color("font_color", "DockButton", T.NAVY)
	th.set_color("font_hover_color", "DockButton", T.NAVY)
	th.set_color("font_pressed_color", "DockButton", T.NAVY)
	th.set_color("font_focus_color", "DockButton", T.NAVY)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		th.set_color(c, "DockButton", T.NAVY_TITLE)
	th.set_font("font", "DockButton", bold)
	th.set_font_size("font_size", "DockButton", 24)
	th.set_constant("icon_max_width", "DockButton", 44)

	# --- inputs --------------------------------------------------------------------
	var field := _box(Color("#FBF5EA"), T.RADIUS_FIELD, 14, 10, false, T.LINE, 2)
	var field_focus: StyleBoxFlat = field.duplicate()
	field_focus.border_color = T.TEAL
	var field_err: StyleBoxFlat = field.duplicate()
	field_err.border_color = T.CORAL
	th.set_stylebox("normal", "LineEdit", field)
	th.set_stylebox("focus", "LineEdit", field_focus)
	th.set_stylebox("read_only", "LineEdit", field)
	th.set_type_variation("LineEditError", "LineEdit")
	th.set_stylebox("normal", "LineEditError", field_err)
	th.set_stylebox("focus", "LineEditError", field_err)
	th.set_color("font_color", "LineEdit", T.NAVY)
	th.set_color("font_placeholder_color", "LineEdit", T.MUTED)
	th.set_color("caret_color", "LineEdit", T.TEAL)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_stylebox("normal", "OptionButton", field)
	th.set_stylebox("hover", "OptionButton", field_focus)
	th.set_stylebox("pressed", "OptionButton", field_focus)
	th.set_stylebox("focus", "OptionButton", field_focus)
	th.set_color("font_color", "OptionButton", T.NAVY)
	th.set_color("font_hover_color", "OptionButton", T.NAVY)
	th.set_color("font_pressed_color", "OptionButton", T.NAVY)
	th.set_color("font_focus_color", "OptionButton", T.NAVY)
	th.set_icon("arrow", "OptionButton", _tinted("res://ui/icons/chevron_down.svg", T.NAVY, 0.45))
	th.set_stylebox("panel", "PopupMenu", _box(T.PANEL, 14, 8, 8, true))
	th.set_stylebox("hover", "PopupMenu", _btn(T.TEAL_SELECT, 10))
	th.set_color("font_color", "PopupMenu", T.NAVY)
	th.set_color("font_hover_color", "PopupMenu", T.NAVY)
	# sliders: grey track, teal fill, white knob with teal ring
	var track := _btn(T.SLIDER_TRACK, 99)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := _btn(T.TEAL, 99)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	th.set_icon("grabber", "HSlider", load("res://ui/icons/grabber.svg"))
	th.set_icon("grabber_highlight", "HSlider", load("res://ui/icons/grabber_hl.svg"))
	# toggles
	th.set_icon("checked", "CheckButton", load("res://ui/icons/toggle_on.svg"))
	th.set_icon("unchecked", "CheckButton", load("res://ui/icons/toggle_off.svg"))
	th.set_icon("checked_disabled", "CheckButton", load("res://ui/icons/toggle_on.svg"))
	th.set_icon("unchecked_disabled", "CheckButton", load("res://ui/icons/toggle_off_disabled.svg"))
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		th.set_stylebox(s, "CheckButton", StyleBoxEmpty.new())
	var cfocus := StyleBoxFlat.new()
	cfocus.draw_center = false
	cfocus.set_border_width_all(2)
	cfocus.border_color = T.TEAL
	cfocus.set_corner_radius_all(16)
	th.set_stylebox("focus", "CheckButton", cfocus)
	th.set_color("font_color", "CheckButton", T.NAVY)
	th.set_color("font_hover_color", "CheckButton", T.NAVY)
	th.set_color("font_pressed_color", "CheckButton", T.NAVY)
	th.set_color("font_hover_pressed_color", "CheckButton", T.NAVY)
	# progress bar
	th.set_stylebox("background", "ProgressBar", _btn(T.SLIDER_TRACK, 99))
	th.set_stylebox("fill", "ProgressBar", _btn(T.TEAL, 99))
	th.set_color("font_color", "ProgressBar", Color(1, 1, 1, 0))
	# scroll bars: slim and quiet
	var grab := _btn(Color(0.08, 0.15, 0.3, 0.22), 99)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", _btn(Color(0.08, 0.15, 0.3, 0.35), 99))
	th.set_stylebox("grabber_pressed", "VScrollBar", _btn(Color(0.08, 0.15, 0.3, 0.45), 99))
	th.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	th.set_constant("separation", "HSeparator", 18)
	var sep := StyleBoxLine.new()
	sep.color = T.LINE
	sep.thickness = 2
	th.set_stylebox("separator", "HSeparator", sep)
	th.set_stylebox("panel", "TooltipPanel", _box(T.NAVY, 10, 10, 6, false))
	th.set_color("font_color", "TooltipLabel", Color.WHITE)

	var err := ResourceSaver.save(th, OUT)
	print("THEME saved ", OUT, " err=", err)
	quit()


func _label(th: Theme, name: String, font: Font, size: int, color: Color) -> void:
	th.set_type_variation(name, "Label")
	th.set_font("font", name, font)
	th.set_font_size("font_size", name, size)
	th.set_color("font_color", name, color)


func _box(fill: Color, radius: int, mx: int, my: int, shadow := false, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_corner_radius_all(radius)
	b.content_margin_left = mx
	b.content_margin_right = mx
	b.content_margin_top = my
	b.content_margin_bottom = my
	b.anti_aliasing = true
	if bw > 0:
		b.set_border_width_all(bw)
		b.border_color = border
	if shadow:
		b.shadow_color = T.SHADOW
		b.shadow_size = 16
		b.shadow_offset = Vector2(0, 6)
	return b


func _btn(fill: Color, radius: int, shadow := false) -> StyleBoxFlat:
	var b := _box(fill, radius, 24, 14, false)
	if shadow:
		b.shadow_color = Color(0.08, 0.14, 0.26, 0.14)
		b.shadow_size = 6
		b.shadow_offset = Vector2(0, 3)
	return b


func _button(th: Theme, name: String, fill: Color, hover: Color, pressed: Color, font_color: Color, font: Font, size: int, border := Color(0, 0, 0, 0)) -> void:
	if name != "Button":
		th.set_type_variation(name, "Button")
	var bw := 2 if border.a > 0 else 0
	for pair in [["normal", fill], ["hover", hover], ["pressed", pressed]]:
		var b := _btn(pair[1], T.RADIUS_BUTTON, name in ["Button", "PrimaryButton", "HeroButton"])
		if bw:
			b.set_border_width_all(bw)
			b.border_color = border
		th.set_stylebox(pair[0], name, b)
	var dis := _btn(T.DISABLED, T.RADIUS_BUTTON)
	th.set_stylebox("disabled", name, dis)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = Color(T.NAVY, 0.4) if name == "PrimaryButton" or name == "HeroButton" else Color(T.TEAL, 0.7)
	focus.set_corner_radius_all(T.RADIUS_BUTTON + 2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	th.set_stylebox("focus", name, focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, name, font_color)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		th.set_color(c, name, font_color)
	th.set_color("font_disabled_color", name, T.DISABLED_TEXT)
	th.set_color("icon_disabled_color", name, T.DISABLED_TEXT)
	th.set_font("font", name, font)
	th.set_font_size("font_size", name, size)
	th.set_constant("h_separation", name, 12)
	th.set_constant("icon_max_width", name, 26)


func _tinted(path: String, color: Color, scale: float) -> Texture2D:
	var img: Image = (load(path) as Texture2D).get_image()
	img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, p.a))
	return ImageTexture.create_from_image(img)
