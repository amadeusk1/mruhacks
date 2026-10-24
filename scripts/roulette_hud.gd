extends CanvasLayer

## Color roulette. Bet red or black. The single green pocket takes the stake.
## The wheel has no numbers.

var _table: Node
var _stake := 1
var _held := 0
var _busy := false
var _done := false
var _spin_left := 0.0
var _bet := ""
var _pocket := 0
var _coins: Label
var _status: Label
var _swatch: ColorRect
var _stakes: Array[Button] = []
var _red: Button
var _black: Button


func open(table: Node) -> void:
	layer = 12
	_table = table
	_build()
	_refresh_coins()


func finish() -> void:
	if _done:
		return
	_done = true
	if _held > 0 and _table != null and is_instance_valid(_table):
		_table.call("give_coins", _held)
		_held = 0


func _process(delta: float) -> void:
	if _done or _spin_left <= 0.0:
		return
	_spin_left -= delta
	if _spin_left <= 0.0:
		_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -320.0
	panel.offset_top = -250.0
	panel.offset_right = -18.0
	panel.offset_bottom = 250.0
	panel.add_theme_stylebox_override("panel", UiKit.panel(20))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_title("Roulette"))
	_coins = _body("")
	column.add_child(_coins)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(0, 36)
	_swatch.color = Color(0.12, 0.55, 0.36)
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_swatch)
	column.add_child(_body("Red or black pays even. One green pocket takes the bet."))
	var stakes := HBoxContainer.new()
	stakes.add_theme_constant_override("separation", 8)
	column.add_child(stakes)
	for amount in [1, 5, 10]:
		var button := Button.new()
		button.text = str(amount)
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_stake.bind(amount))
		stakes.add_child(button)
		_stakes.append(button)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 8)
	column.add_child(colors)
	_red = Button.new()
	_red.text = "Red"
	_red.custom_minimum_size = Vector2(0, 52)
	_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_red.pressed.connect(_spin.bind("red"))
	colors.add_child(_red)
	_black = Button.new()
	_black.text = "Black"
	_black.custom_minimum_size = Vector2(0, 52)
	_black.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_black.pressed.connect(_spin.bind("black"))
	colors.add_child(_black)
	_status = _body("Pick a color to spin.")
	column.add_child(_status)
	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(0, 42)
	UiKit.paint(leave, UiKit.QUIET, UiKit.NAVY)
	leave.pressed.connect(_leave)
	column.add_child(leave)
	_paint_buttons()


func _spin(bet: String) -> void:
	if _busy or _done:
		return
	if not bool(_table.call("take_coins", _stake)):
		_status.text = "Need %d coins." % _stake
		_refresh_coins()
		return
	_bet = bet
	_held = _stake
	_busy = true
	_pocket = CasinoRules.roulette_roll()
	_table.call("spin_wheel")
	_spin_left = 2.0
	_status.text = "Spinning..."
	_red.disabled = true
	_black.disabled = true
	_refresh_coins()


func _reveal() -> void:
	if _done:
		return
	var color_name := CasinoRules.roulette_color(_pocket)
	_table.call("show_color", color_name)
	_swatch.color = _swatch_color(color_name)
	var prize := CasinoRules.roulette_prize(_bet, _pocket, _stake)
	_held = 0
	_busy = false
	_red.disabled = false
	_black.disabled = false
	if color_name == "green":
		_status.text = "Green. The house takes it."
	elif prize > 0:
		_table.call("give_coins", prize)
		_status.text = "%s pays %d." % [color_name.capitalize(), prize]
	else:
		_status.text = "%s. Lost the bet." % color_name.capitalize()
	_refresh_coins()


func _set_stake(amount: int) -> void:
	if _busy:
		return
	_stake = amount
	_paint_buttons()


func _paint_buttons() -> void:
	for button in _stakes:
		var picked := int(button.text) == _stake
		UiKit.paint(button, UiKit.TEAL if picked else UiKit.QUIET, UiKit.WHITE if picked else UiKit.NAVY)
	UiKit.paint(_red, Color(0.78, 0.16, 0.18), Color(0.99, 0.96, 0.94))
	UiKit.paint(_black, Color(0.1, 0.12, 0.16), Color(0.99, 0.96, 0.94))


func _swatch_color(color_name: String) -> Color:
	match color_name:
		"red":
			return Color(0.78, 0.16, 0.18)
		"black":
			return Color(0.1, 0.12, 0.16)
		_:
			return Color(0.12, 0.55, 0.36)


func _refresh_coins() -> void:
	_coins.text = "%d coins" % int(_table.call("coins"))


func _leave() -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player != null and player.has_method("stand_up"):
		player.stand_up()


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UiKit.NAVY)
	return label


func _body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(UiKit.NAVY, 0.82))
	return label
