class_name UiKit
extends RefCounted

## Shared menu colors from the UI mockups.
## Ivory panels, navy text, teal primary actions, coral for warnings.

const IVORY := Color(0.980392, 0.945098, 0.866667)
const QUIET := Color(0.929412, 0.905882, 0.854902)
const NAVY := Color(0.082353, 0.203922, 0.278431)
const TEAL := Color(0.125490, 0.490196, 0.521569)
const CORAL := Color(0.909804, 0.427451, 0.345098)
const WHITE := Color(0.988235, 0.976471, 0.952941)


static func panel(radius := 22) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = IVORY
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.082353, 0.141176, 0.203922, 0.22)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 8)
	return box


static func field() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = WHITE
	box.border_color = Color(NAVY, 0.14)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func field_focus() -> StyleBoxFlat:
	var box := field()
	box.border_color = TEAL
	return box


static func paint(button: Button, fill: Color, font: Color, radius := 16) -> void:
	var hover := fill.lightened(0.08)
	var pressed := fill.darkened(0.08)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_focus_color", font)
	button.add_theme_color_override("font_disabled_color", Color(font, 0.45))
	button.add_theme_stylebox_override("normal", _button(fill, radius, false))
	button.add_theme_stylebox_override("hover", _button(hover, radius, false))
	button.add_theme_stylebox_override("pressed", _button(pressed, radius, false))
	button.add_theme_stylebox_override("disabled", _button(Color(fill, 0.45), radius, false))
	button.add_theme_stylebox_override("focus", _button(fill, radius, true))


static func _button(fill: Color, radius: int, focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if focused:
		box.border_color = NAVY
		box.set_border_width_all(3)
	return box
