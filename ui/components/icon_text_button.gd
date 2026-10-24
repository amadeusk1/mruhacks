class_name IconTextButton
extends Button
## Button whose icon sits right beside its text, the pair centred (as every mockup draws them).
## Godot's own Button puts the icon at the far edge when the text is centred.

var _icon_rect: TextureRect
var _label: Label
var _caption := ""
var _tex: Texture2D
var trailing := false   # icon after the text (Continue >)


func _init(caption: String, tex: Texture2D, after := false) -> void:
	_caption = caption
	_tex = tex
	trailing = after
	text = ""
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_icon_rect = TextureRect.new()
	_icon_rect.texture = tex
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = Label.new()
	_label.text = caption
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if trailing:
		row.add_child(_label)
		row.add_child(_icon_rect)
	else:
		row.add_child(_icon_rect)
		row.add_child(_label)


func set_caption(t: String) -> void:
	_caption = t
	_label.text = t


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_restyle()
	elif what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_ENTER:
		_restyle.call_deferred()


func _restyle() -> void:
	if _label == null:
		return
	var f := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	_label.add_theme_font_override("font", f)
	_label.add_theme_font_size_override("font_size", fs)
	var col := get_theme_color("font_disabled_color" if disabled else ("font_pressed_color" if button_pressed else "font_color"))
	_label.add_theme_color_override("font_color", col)
	_icon_rect.modulate = col
	var px := clampf(fs * 1.15, 18, 48)
	_icon_rect.custom_minimum_size = Vector2(px, px)


func _toggled(_on: bool) -> void:
	_restyle()


func _get_minimum_size() -> Vector2:
	if _label == null:
		return Vector2.ZERO
	var sb := get_theme_stylebox("normal")
	var inner := _label.get_combined_minimum_size() + Vector2(_icon_rect.custom_minimum_size.x + 12, 0)
	return inner + (sb.get_minimum_size() if sb else Vector2.ZERO)
