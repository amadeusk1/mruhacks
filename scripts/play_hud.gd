extends CanvasLayer

## Compact town HUD: place, coins, map, home, and chat.

const SPEAKER := "You"
const MAX_LINES := 6

var coins := 0

var _lines: PackedStringArray = PackedStringArray()

@onready var _amount: Label = $Root/CoinBadge/Margin/Row/Amount
@onready var _place: Label = $Root/PlaceChip/Margin/Place
@onready var _log: Label = $Root/Chat/Log/Margin/Lines
@onready var _entry: LineEdit = $Root/Chat/Entry


func _ready() -> void:
	_entry.text_submitted.connect(_on_submitted)
	_entry.focus_entered.connect(_on_focus_entered)
	_entry.focus_exited.connect(_on_focus_exited)
	$Root/Actions/Map.pressed.connect(_on_map)
	$Root/Actions/Home.pressed.connect(_on_home)
	set_coins(coins)
	_refresh_log()


func set_place(title: String) -> void:
	_place.text = title if title != "" else "Town"


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
	if _opens_chat(event) and not _entry.has_focus():
		_entry.grab_focus()
		get_viewport().set_input_as_handled()
	elif _entry.has_focus() and event.is_action_pressed("ui_cancel"):
		_entry.release_focus()
		get_viewport().set_input_as_handled()
	elif _entry.has_focus() and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_entry.release_focus()
			get_viewport().set_input_as_handled()


func _opens_chat(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_accept"):
		return false
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE:
		return false
	return true


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
	var world := _world()
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
		_log.add_theme_color_override("font_color", Color(UiKit.NAVY, 0.55))
		return
	_log.text = "\n".join(_lines)
	_log.add_theme_color_override("font_color", UiKit.NAVY)


func _on_map() -> void:
	var world := _world()
	if world != null and world.has_method("open_bus_menu"):
		world.call("open_bus_menu")


func _on_home() -> void:
	var world := _world()
	if world != null and world.has_method("travel_to"):
		world.call("travel_to", "home")


func _world() -> Node:
	return get_tree().get_first_node_in_group("world")


func _set_typing(active: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_typing_locked"):
		player.call("set_typing_locked", active)


func _menu_open() -> bool:
	var world := _world()
	if world == null:
		return false
	if world.has_method("is_bus_menu_open") and bool(world.call("is_bus_menu_open")):
		return true
	return world.has_method("is_shop_open") and bool(world.call("is_shop_open"))
