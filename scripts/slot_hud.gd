extends CanvasLayer

## Three-reel slots. Spin spends coins. Leave refunds a spin still in motion.

var _table: Node
var _stake := 1
var _held := 0
var _busy := false
var _done := false
var _spin_left := 0.0
var _tick := 0.0
var _final := PackedStringArray()
var _coins: Label
var _status: Label
var _reels: Array[Label] = []
var _spin: Button
var _stakes: Array[Button] = []


func open(table: Node) -> void:
	layer = 12
	_table = table
	_build()
	_show(PackedStringArray(["fish", "coin", "sled"]))
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
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.08
		var shown := PackedStringArray()
		for i in 3:
			if _spin_left > float(2 - i) * 0.28:
				shown.append(CasinoRules.slot_roll()[0])
			else:
				shown.append(_final[i])
		_show(shown)
		_table.call("show_reels", shown)
	if _spin_left <= 0.0:
		_show(_final)
		_table.call("show_reels", _final)
		_payout()


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
	panel.offset_left = -300.0
	panel.offset_top = -230.0
	panel.offset_right = -18.0
	panel.offset_bottom = 230.0
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
	column.add_child(_title("Slots"))
	_coins = _body("")
	column.add_child(_coins)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for _i in 3:
		var reel := Label.new()
		reel.custom_minimum_size = Vector2(78, 64)
		reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reel.add_theme_font_size_override("font_size", 18)
		reel.add_theme_color_override("font_color", UiKit.NAVY)
		row.add_child(reel)
		_reels.append(reel)
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
	_spin = Button.new()
	_spin.text = "Spin"
	_spin.custom_minimum_size = Vector2(0, 52)
	_spin.pressed.connect(_on_spin)
	column.add_child(_spin)
	_status = _body("Three of a kind pays the most. Two alike pays double.")
	column.add_child(_status)
	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(0, 42)
	UiKit.paint(leave, UiKit.QUIET, UiKit.NAVY)
	leave.pressed.connect(_leave)
	column.add_child(leave)
	_paint_stakes()


func _on_spin() -> void:
	if _busy or _done:
		return
	if not bool(_table.call("take_coins", _stake)):
		_status.text = "Need %d coins." % _stake
		_refresh_coins()
		return
	_held = _stake
	_busy = true
	_final = CasinoRules.slot_roll()
	_spin_left = 1.15
	_tick = 0.0
	_status.text = "Spinning..."
	_spin.disabled = true
	_refresh_coins()


func _payout() -> void:
	if _done:
		return
	var prize := CasinoRules.slot_prize(_final, _stake)
	_held = 0
	_busy = false
	_spin.disabled = false
	if prize > 0:
		_table.call("give_coins", prize)
		_status.text = "Won %d." % prize
	else:
		_status.text = "No match."
	_refresh_coins()


func _set_stake(amount: int) -> void:
	if _busy:
		return
	_stake = amount
	_paint_stakes()


func _paint_stakes() -> void:
	for button in _stakes:
		var picked := int(button.text) == _stake
		UiKit.paint(button, UiKit.TEAL if picked else UiKit.QUIET, UiKit.WHITE if picked else UiKit.NAVY)
	UiKit.paint(_spin, UiKit.TEAL, UiKit.WHITE)


func _show(symbols: PackedStringArray) -> void:
	for i in mini(symbols.size(), _reels.size()):
		_reels[i].text = symbols[i].capitalize()


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
