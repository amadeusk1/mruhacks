extends CanvasLayer

## Corner coin count and a local chat box for the town.

const SPEAKER := "You"
const MAX_LINES := 6

var coins := 0

var _lines: PackedStringArray = PackedStringArray()

@onready var _amount: Label = $Root/CoinBadge/Margin/Row/Amount
@onready var _log: Label = $Root/Chat/Log/Margin/Lines
@onready var _entry: LineEdit = $Root/Chat/Entry


func _ready() -> void:
	$Root.add_child(TownHud.new())  # UI core: location chip, mic, dock and contextual action
	_entry.text_submitted.connect(_on_submitted)
	_entry.focus_entered.connect(_on_focus_entered)
	_entry.focus_exited.connect(_on_focus_exited)
	set_coins(coins)
	_refresh_log()


func set_coins(amount: int) -> void:
	coins = maxi(0, amount)
	_amount.text = str(coins)


func add_coins(amount: int) -> void:
	set_coins(coins + amount)


func close_chat() -> void:
	if _entry.has_focus():
		_entry.release_focus()


func set_play_visible(show_hud: bool) -> void:
	visible = show_hud
	if not show_hud:
		close_chat()


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open():
		close_chat()
		return
	if _is_chat_key(event) and not _entry.has_focus():
		_entry.call_deferred("grab_focus")
		get_viewport().set_input_as_handled()
	elif _entry.has_focus() and event.is_action_pressed("ui_cancel"):
		_entry.release_focus()
		get_viewport().set_input_as_handled()
	elif _entry.has_focus() and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_entry.release_focus()
			get_viewport().set_input_as_handled()


func add_line(speaker: String, message: String) -> void:
	_lines.append("%s: %s" % [speaker, message])
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_refresh_log()


func _on_submitted(text: String) -> void:
	var message := text.strip_edges()
	_entry.clear()
	if message == "":
		return
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("send_chat"):
		world.call("send_chat", message)
	else:
		add_line(SPEAKER, message)
	_entry.grab_focus()


func _on_focus_entered() -> void:
	_set_typing(true)


func _on_focus_exited() -> void:
	_set_typing(false)


func _refresh_log() -> void:
	if _lines.is_empty():
		_log.text = "Chat with friends here."
		_log.add_theme_color_override("font_color", Color(0.55, 0.56, 0.61, 1))  # UI theme: muted on ivory
		return
	_log.text = "\n".join(_lines)
	_log.add_theme_color_override("font_color", Color(0.08, 0.15, 0.3, 1))  # UI theme: navy on ivory


func _set_typing(active: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_typing_locked"):
		player.call("set_typing_locked", active)


func _is_chat_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo and key.physical_keycode == KEY_T and not key.shift_pressed and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed


func _menu_open() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	return world != null and world.has_method("is_bus_menu_open") and bool(world.call("is_bus_menu_open"))
