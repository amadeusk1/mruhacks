extends CanvasLayer

## Corner coin count and the chat box: full session history (scrolls), minimize / restore
## (button or C, remembered in settings) with an unread badge, Enter or T to type even when minimized.
## Speech bubbles over heads: ui/hud/chat_bubbles.gd.

const T := preload("res://ui/theme/ui_tokens.gd")
const SPEAKER := "You"
const MAX_LINES := 300   ## session history kept (scrollable)

var coins := 0

var _lines: PackedStringArray = PackedStringArray()
var _scroll: ScrollContainer
var _toggle: Button
var _unread := 0
var _typing_sent := false

@onready var _amount: Label = $Root/CoinBadge/Margin/Row/Amount
@onready var _log: Label = $Root/Chat/Log/Margin/Lines
@onready var _entry: LineEdit = $Root/Chat/Entry
@onready var _chat: VBoxContainer = $Root/Chat
@onready var _log_panel: Control = $Root/Chat/Log


func _ready() -> void:
	add_to_group("play_hud")
	var bubbles := ChatBubbles.new()  # behind the HUD: speech bubbles over penguins
	bubbles.name = "ChatBubbles"
	$Root.add_child(bubbles)
	$Root.move_child($Root.get_child(-1), 0)
	$Root.add_child(TownHud.new())  # UI core: location chip, mic, dock and contextual action
	var pad := preload("res://scripts/touch_controls.gd").new()
	get_tree().root.add_child.call_deferred(pad)
	tree_exiting.connect(pad.queue_free)
	_build_chat_chrome()
	_entry.text_submitted.connect(_on_submitted)
	_entry.text_changed.connect(_on_text_changed)
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
		_entry.visible = true  # typing works while minimized too
		_entry.call_deferred("grab_focus")
		get_viewport().set_input_as_handled()
	elif _is_toggle_key(event) and not _entry.has_focus() and not UIRouter.is_open():
		toggle_chat()
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
	if minimized() and speaker != str(Net.local_profile().get("name", "")) and speaker != SPEAKER:  # your own lines aren't news
		_unread += 1
		_refresh_toggle()
	_refresh_log()


## Header row (title + minimize/restore with unread badge) and a scrolling history.
func _build_chat_chrome() -> void:
	_chat.alignment = BoxContainer.ALIGNMENT_END  # minimized: the header sits at the bottom
	var margin := _log.get_parent()
	margin.remove_child(_log)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_log.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log.add_theme_font_size_override("font_size", 22)
	_scroll.add_child(_log)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	_chat.add_child(head)
	_chat.move_child(head, 0)
	_toggle = Button.new()
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.custom_minimum_size = Vector2(0, 44)  # touch-sized
	_toggle.tooltip_text = "Minimize or show chat (C)"
	_toggle.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(T.PANEL, 0.94) if st != "hover" else T.PANEL
		sb.border_color = T.LINE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		_toggle.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_toggle.add_theme_color_override(c, T.NAVY)
	_toggle.pressed.connect(toggle_chat)
	head.add_child(_toggle)
	_apply_minimized()
	var bar := _scroll.get_v_scroll_bar()
	bar.changed.connect(_on_scroll_range)
	bar.value_changed.connect(_on_scroll_value)
	get_viewport().size_changed.connect(func() -> void:
		_fit_log()
		if _follow_bottom:
			_snap_bottom()
	)


func minimized() -> bool:
	return bool(UIRouter.settings.get("chat_minimized", false))


func toggle_chat() -> void:
	UIRouter.set_setting("chat_minimized", not minimized())
	_apply_minimized()


func _apply_minimized() -> void:
	var mini := minimized()
	if not mini:
		_unread = 0
	_log_panel.visible = not mini
	_entry.visible = not mini or _entry.has_focus()
	_refresh_toggle()
	if not mini:
		_follow_bottom = true
		_snap_bottom()


func _refresh_toggle() -> void:
	if minimized():
		_toggle.text = "Chat  ▴" if _unread == 0 else "Chat · %d new  ▴" % _unread
		_toggle.add_theme_color_override("font_color", T.NAVY if _unread == 0 else Color("#D6453C"))
	else:
		_toggle.text = "Hide chat  ▾"
		_toggle.add_theme_color_override("font_color", T.NAVY)


## Stay on the newest line until the player scrolls up to read history.
var _follow_bottom := true
var _moving_scroll := false


func _on_scroll_range() -> void:
	if _follow_bottom:
		_snap_bottom()


func _on_scroll_value(value: float) -> void:
	if _moving_scroll or _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	_follow_bottom = bar.max_value <= bar.page + 8.0 or value >= bar.max_value - bar.page - 28.0


func _snap_bottom() -> void:
	if _scroll == null or _moving_scroll:
		return
	var bar := _scroll.get_v_scroll_bar()
	var bottom := maxi(0, int(bar.max_value - bar.page))
	if _scroll.scroll_vertical == bottom:
		return
	_moving_scroll = true
	_scroll.scroll_vertical = bottom
	_moving_scroll = false


func _on_text_changed(text: String) -> void:
	var typing := text.strip_edges() != ""
	if typing != _typing_sent:
		_typing_sent = typing
		Net.note_typing(typing)


func _stop_typing() -> void:
	if _typing_sent:
		_typing_sent = false
		Net.note_typing(false)


func _on_submitted(text: String) -> void:
	var message := text.strip_edges()
	_entry.clear()
	_stop_typing()
	if message == "":
		return
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("send_chat"):
		world.call("send_chat", message)
	else:
		add_line(SPEAKER, message)
	_entry.grab_focus()


func _on_focus_entered() -> void:
	_entry.visible = true
	_set_typing(true)


func _on_focus_exited() -> void:
	_set_typing(false)
	_stop_typing()
	if minimized():
		_entry.visible = false


func _refresh_log() -> void:
	if _lines.is_empty():
		_log.text = "Chat with friends here."
		_log.add_theme_color_override("font_color", Color(0.55, 0.56, 0.61, 1))  # UI theme: muted on ivory
		_fit_log()
		return
	_log.text = "\n".join(_lines)
	_log.add_theme_color_override("font_color", Color(0.08, 0.15, 0.3, 1))  # UI theme: navy on ivory
	_fit_log()
	if _follow_bottom:
		_snap_bottom()
		_snap_after_layout()


func _snap_after_layout() -> void:
	for _i in 3:
		await get_tree().process_frame
		if not _follow_bottom or _scroll == null:
			return
		_snap_bottom()


func _fit_log() -> void:
	var width := 280.0
	if _scroll and _scroll.size.x > 40.0:
		width = _scroll.size.x - 8.0
	var font := _log.get_theme_font("font")
	var size := _log.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(_log.text, HORIZONTAL_ALIGNMENT_LEFT, width, size)
	_log.custom_minimum_size = Vector2(width, text_size.y)


func _set_typing(active: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_typing_locked"):
		player.call("set_typing_locked", active)


func _is_chat_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo and key.physical_keycode in [KEY_T, KEY_ENTER, KEY_KP_ENTER] and not key.shift_pressed and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed


func _is_toggle_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.physical_keycode == KEY_C and not key.shift_pressed and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed


func _menu_open() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	return world != null and world.has_method("is_bus_menu_open") and bool(world.call("is_bus_menu_open"))
