extends CanvasLayer

## Host, join, or play alone before the first room loads.

signal host_requested
signal join_requested
signal solo_requested

var _name_field: LineEdit
var _status: Label
var _host_button: Button
var _join_button: Button
var _solo_button: Button


func _ready() -> void:
	layer = 20
	_build()


func player_name() -> String:
	var raw := _name_field.text.strip_edges().replace("\n", " ")
	if raw == "":
		return "Penguin"
	if raw.length() > 16:
		raw = raw.substr(0, 16)
	return raw


func set_name_text(value: String) -> void:
	_name_field.text = value


func set_status(message: String) -> void:
	_status.text = message


func set_busy(busy: bool) -> void:
	_host_button.disabled = busy
	_join_button.disabled = busy
	_solo_button.disabled = busy
	_name_field.editable = not busy


func show_lobby(message: String = "") -> void:
	visible = true
	set_busy(false)
	if message != "":
		_status.text = message


func hide_lobby() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
	visible = false


func _build() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.05, 0.1, 0.16, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(420, 0)
	frame.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)

	var title := Label.new()
	title.text = "Play together"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1))
	column.add_child(title)

	var hint := Label.new()
	hint.text = "One window hosts. The other joins 127.0.0.1:7777."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(360, 0)
	hint.add_theme_color_override("font_color", Color(0.84, 0.92, 0.98))
	column.add_child(hint)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	column.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name"
	name_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)

	_name_field = LineEdit.new()
	_name_field.text = "Penguin"
	_name_field.custom_minimum_size = Vector2(260, 40)
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.add_theme_color_override("font_color", Color(0.08, 0.16, 0.24))
	_name_field.add_theme_stylebox_override("normal", _field_style())
	name_row.add_child(_name_field)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)

	_host_button = _make_button("Host", Color(0.13, 0.49, 0.52), Color(0.95, 0.97, 1))
	_host_button.pressed.connect(func() -> void: host_requested.emit())
	actions.add_child(_host_button)

	_join_button = _make_button("Join", Color(0.95, 0.97, 1), Color(0.08, 0.16, 0.24))
	_join_button.pressed.connect(func() -> void: join_requested.emit())
	actions.add_child(_join_button)

	_solo_button = _make_button("Play solo", Color(0.14, 0.28, 0.42), Color(0.95, 0.97, 1))
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	column.add_child(_solo_button)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(360, 36)
	_status.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	column.add_child(_status)


func _make_button(text: String, fill: Color, font: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_disabled_color", Color(font.r, font.g, font.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_style(fill))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.08)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(fill.r, fill.g, fill.b, 0.45)))
	return button


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.22, 0.4, 0.98)
	box.border_color = Color(0.86, 0.93, 0.98)
	box.set_border_width_all(4)
	box.set_corner_radius_all(18)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box


func _button_style(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _field_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.97, 1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
