extends CanvasLayer

## Five-card draw. Deal, hold the cards you want, then draw once.

var _table: Node
var _stake := 1
var _held_bet := 0
var _done := false
var _phase := "bet"
var _deck: Array = []
var _cards: Array = []
var _buttons: Array[Button] = []
var _coins: Label
var _status: Label
var _action: Button
var _stakes: Array[Button] = []


func open(table: Node) -> void:
	layer = 12
	_table = table
	_build()
	_refresh_coins()


func finish() -> void:
	if _done:
		return
	_done = true
	if _held_bet > 0 and _table != null and is_instance_valid(_table):
		_table.call("give_coins", _held_bet)
		_held_bet = 0


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
	panel.offset_left = -420.0
	panel.offset_top = -250.0
	panel.offset_right = -18.0
	panel.offset_bottom = 250.0
	panel.add_theme_stylebox_override("panel", UiKit.panel(20))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_title("Poker"))
	_coins = _body("")
	column.add_child(_coins)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	for i in 5:
		var card := Button.new()
		card.text = "—"
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(68, 88)
		card.pressed.connect(_toggle.bind(i))
		row.add_child(card)
		_buttons.append(card)
	var stakes := HBoxContainer.new()
	stakes.add_theme_constant_override("separation", 8)
	column.add_child(stakes)
	for amount in [1, 5, 10]:
		var button := Button.new()
		button.text = str(amount)
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_stake.bind(amount))
		stakes.add_child(button)
		_stakes.append(button)
	_action = Button.new()
	_action.text = "Deal"
	_action.custom_minimum_size = Vector2(0, 48)
	_action.pressed.connect(_on_action)
	column.add_child(_action)
	_status = _body("Jacks or better wins. Click cards to hold them.")
	column.add_child(_status)
	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(0, 42)
	UiKit.paint(leave, UiKit.QUIET, UiKit.NAVY)
	leave.pressed.connect(_leave)
	column.add_child(leave)
	_paint_cards()
	_paint_stakes()


func _on_action() -> void:
	if _done:
		return
	if _phase == "bet":
		_deal()
	else:
		_draw()


func _deal() -> void:
	if not bool(_table.call("take_coins", _stake)):
		_status.text = "Need %d coins." % _stake
		_refresh_coins()
		return
	_held_bet = _stake
	_deck = CasinoRules.fresh_deck()
	_cards.clear()
	for _i in 5:
		_cards.append(_deck.pop_back())
	for button in _buttons:
		button.button_pressed = false
	_phase = "hold"
	_action.text = "Draw"
	_status.text = "Click cards to hold, then draw."
	_paint_cards()
	_paint_stakes()
	_refresh_coins()


func _draw() -> void:
	for i in _cards.size():
		if not _buttons[i].button_pressed:
			_cards[i] = _deck.pop_back()
	var title := CasinoRules.poker_title(_cards)
	var prize := CasinoRules.poker_prize(title, _stake)
	_held_bet = 0
	_phase = "bet"
	_action.text = "Deal"
	for button in _buttons:
		button.button_pressed = false
	_paint_cards()
	_paint_stakes()
	if prize > 0:
		_table.call("give_coins", prize)
		_status.text = "%s. Won %d." % [title, prize]
	else:
		_status.text = "%s." % title
	_refresh_coins()


func _toggle(index: int) -> void:
	if _phase != "hold":
		_buttons[index].button_pressed = false
		return
	_paint_cards()


func _set_stake(amount: int) -> void:
	if _phase != "bet":
		return
	_stake = amount
	_paint_stakes()


func _paint_cards() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		var held := _phase == "hold" and button.button_pressed
		if i < _cards.size():
			var card: Dictionary = _cards[i]
			var name := CasinoRules.card_label(card)
			button.text = "%s\nHOLD" % name if held else name
			var ink := Color(0.78, 0.16, 0.18) if CasinoRules.card_red(card) else UiKit.NAVY
			UiKit.paint(button, UiKit.TEAL if held else UiKit.WHITE, ink, 10)
		else:
			button.text = "—"
			UiKit.paint(button, UiKit.QUIET, UiKit.NAVY, 10)


func _paint_stakes() -> void:
	for button in _stakes:
		var picked := int(button.text) == _stake
		UiKit.paint(button, UiKit.TEAL if picked else UiKit.QUIET, UiKit.WHITE if picked else UiKit.NAVY)
		button.disabled = _phase != "bet"
	UiKit.paint(_action, UiKit.TEAL, UiKit.WHITE)


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
