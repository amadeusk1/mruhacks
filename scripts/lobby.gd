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
	frame.custom_minimum_size = Vector2(460, 0)
	frame.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)

	var title := Label.new()
	title.text = "Play together"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiKit.NAVY)
	column.add_child(title)

	var hint := Label.new()
	hint.text = "One window hosts. The other joins 127.0.0.1:7777."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(380, 0)
	hint.add_theme_color_override("font_color", Color(UiKit.NAVY, 0.78))
	column.add_child(hint)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	column.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Display name"
	name_label.add_theme_color_override("font_color", UiKit.NAVY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)

	_name_field = LineEdit.new()
	_name_field.text = "Penguin"
	_name_field.custom_minimum_size = Vector2(260, 40)
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.add_theme_color_override("font_color", UiKit.NAVY)
	_name_field.add_theme_color_override("font_placeholder_color", Color(UiKit.NAVY, 0.45))
	_name_field.add_theme_color_override("caret_color", UiKit.NAVY)
	_name_field.add_theme_stylebox_override("normal", UiKit.field())
	_name_field.add_theme_stylebox_override("focus", UiKit.field_focus())
	name_row.add_child(_name_field)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)

	_host_button = _make_button("Host", UiKit.TEAL, UiKit.WHITE)
	_host_button.pressed.connect(func() -> void: host_requested.emit())
	actions.add_child(_host_button)

	_join_button = _make_button("Join", UiKit.QUIET, UiKit.NAVY)
	_join_button.pressed.connect(func() -> void: join_requested.emit())
	actions.add_child(_join_button)

	_solo_button = _make_button("Play solo", UiKit.TEAL, UiKit.WHITE)
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	column.add_child(_solo_button)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(360, 36)
	_status.add_theme_color_override("font_color", UiKit.CORAL)
	column.add_child(_status)


func _make_button(text: String, fill: Color, font: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.paint(button, fill, font)
	return button


func _panel_style() -> StyleBoxFlat:
	var box := UiKit.panel(22)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 20
	box.content_margin_bottom = 18
	return box
