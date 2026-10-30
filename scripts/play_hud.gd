extends CanvasLayer

## Corner coin count and the chat box: full session history stays on the newest line unless
## the player scrolls up. Minimize (button or C, remembered in settings) leaves the
## say-something field with the chat icon on its right, and a red badge for unread lines.
## Speech bubbles over heads: ui/hud/chat_bubbles.gd.

const T := preload("res://ui/theme/ui_tokens.gd")
const SPEAKER := "You"
const MAX_LINES := 300   ## session history kept (scrollable)
const NAME_SIZE := 18
const BODY_SIZE := 22

var coins := 0

var _entries: Array[Dictionary] = []
var _lines: PackedStringArray = PackedStringArray()
var _scroll: ScrollContainer
var _feed: VBoxContainer
var _spacer: Control
var _toggle: Button
var _title: Label
var _badge_panel: PanelContainer
var _badge: Label
var _unread := 0
var _typing_sent := false
var _follow := true
var _stick_gen := 0

@onready var _amount: Label = $Root/CoinBadge/Margin/Row/Amount
@onready var _entry: LineEdit = $Root/Chat/Entry
@onready var _chat: VBoxContainer = $Root/Chat
@onready var _log_panel: Control = $Root/Chat/Log


func _ready() -> void:
	add_to_group("play_hud")
	var bubbles := ChatBubbles.new()  # behind the HUD: speech bubbles over penguins
	bubbles.name = "ChatBubbles"
	$Root.add_child(bubbles)
	$Root.move_child($Root.get_child(-1), 0)
	var hud := TownHud.new()
	hud.name = "TownHud"
	$Root.add_child(hud)  # UI core: location chip, mic, dock and contextual action
	var pad := preload("res://scripts/touch_controls.gd").new()
	get_tree().root.add_child.call_deferred(pad)
	tree_exiting.connect(pad.queue_free)
	_build_chat_chrome()
	_entry.text_submitted.connect(_on_submitted)
	_entry.text_changed.connect(_on_text_changed)
	_entry.focus_entered.connect(_on_focus_entered)
	_entry.focus_exited.connect(_on_focus_exited)
	set_coins(Pets.load_coins())  # coins carry over between sessions (they buy pets)
	_refresh_log()


func set_coins(amount: int) -> void:
	coins = maxi(0, amount)
	_amount.text = str(coins)
	Pets.save_coins(coins)


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
	var mine := speaker == SPEAKER or speaker == str(Net.local_profile().get("name", ""))
	if mine:
		_follow = true  # sending a line brings you back to the latest message
	_entries.append({"speaker": speaker, "message": message})
	_lines.append("%s: %s" % [speaker, message])
	if _entries.size() > MAX_LINES:
		_entries.pop_front()
		_lines.remove_at(0)
	if minimized() and not mine:  # your own lines aren't news
		_unread += 1
		_refresh_toggle()
	_refresh_log()


## Header row (title + minimize/restore with unread badge) and a scrolling history.
func _build_chat_chrome() -> void:
	_chat.alignment = BoxContainer.ALIGNMENT_END  # minimized: the header sits at the bottom
	var lines := $Root/Chat/Log/Margin/Lines
	var margin := lines.get_parent()
	margin.remove_child(lines)
	lines.queue_free()
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)
	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed.add_theme_constant_override("separation", 12)
	_spacer = Control.new()
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_child(_spacer)
	_scroll.add_child(_feed)
	_scroll.resized.connect(_on_log_resized)
	_scroll.gui_input.connect(_on_log_pointer)
	_scroll.get_v_scroll_bar().gui_input.connect(_on_log_pointer)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	_chat.add_child(head)
	_chat.move_child(head, 0)
	_title = Label.new()
	_title.text = "Chat"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_override("font", UIKit.THEME.get_font("font", "Strong"))
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", T.NAVY_TITLE)
	head.add_child(_title)
	_toggle = UIKit.icon_button("chevron_down", "Show chat (C)", 58)
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(toggle_chat)
	var composer := HBoxContainer.new()
	composer.name = "Composer"
	composer.add_theme_constant_override("separation", 8)
	composer.alignment = BoxContainer.ALIGNMENT_CENTER
	_chat.remove_child(_entry)
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.custom_minimum_size.y = 58
	composer.add_child(_entry)
	composer.add_child(_toggle)
	_chat.add_child(composer)
	var glyph := _ChatGlyph.new()
	glyph.name = "ChatGlyph"
	_toggle.add_child(glyph)
	_badge_panel = PanelContainer.new()
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.visible = false
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Color("#D6453C")
	badge_box.set_corner_radius_all(12)
	badge_box.content_margin_left = 5
	badge_box.content_margin_right = 5
	badge_box.content_margin_top = 1
	badge_box.content_margin_bottom = 1
	_badge_panel.add_theme_stylebox_override("panel", badge_box)
	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_override("font", UIKit.THEME.get_font("font", "Strong"))
	_badge.add_theme_font_size_override("font_size", 14)
	_badge.add_theme_color_override("font_color", Color.WHITE)
	_badge_panel.add_child(_badge)
	_toggle.add_child(_badge_panel)
	_toggle.resized.connect(_place_badge)
	_apply_minimized()


func minimized() -> bool:
	return bool(UIRouter.settings.get("chat_minimized", false))


func toggle_chat() -> void:
	UIRouter.set_setting("chat_minimized", not minimized())
	_apply_minimized()


func _apply_minimized() -> void:
	_sync_chat_frame(not minimized())


## Open panel, or just the bottom row: the field, with the chat icon on its right.
func _sync_chat_frame(stick_to_latest := false) -> void:
	var mini := minimized()
	if not mini:
		_unread = 0
	if stick_to_latest:
		_follow = true
	_log_panel.visible = not mini
	_entry.visible = true
	_title.visible = not mini
	(_title.get_parent() as Control).visible = not mini
	_refresh_toggle()
	_relayout_chat()
	if stick_to_latest:
		_stick_bottom_soon()


func _relayout_chat() -> void:
	var hud := get_tree().get_first_node_in_group("town_hud")
	if hud and hud.has_method("_layout"):
		hud.call("_layout")


func _refresh_toggle() -> void:
	var mini := minimized()
	_toggle.custom_minimum_size = Vector2(58, 58)
	_toggle.icon = null
	var glyph := _toggle.get_node_or_null("ChatGlyph") as CanvasItem
	if glyph:
		glyph.visible = true
	_toggle.tooltip_text = "Show chat (C)" if mini else "Hide chat (C)"
	var alert := mini and _unread > 0
	_badge_panel.visible = alert
	if alert:
		_badge.text = str(_unread) if _unread < 10 else "9+"
		_place_badge()


func _place_badge() -> void:
	if _badge_panel == null or not _badge_panel.visible or _toggle.size.x < 2.0:
		return
	var s := _badge_panel.get_combined_minimum_size()
	var side := maxf(maxf(s.x, s.y), 22.0)
	_badge_panel.size = Vector2(side, side)
	_badge_panel.position = Vector2(_toggle.size.x - side - 2.0, 2.0)


func _on_log_resized() -> void:
	_pin_log()
	if _follow:
		_stick_bottom()


## Wheel and scrollbar drags are the player reading history. Code-driven jumps are ignored.
func _on_log_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			var bar := _scroll.get_v_scroll_bar()
			if bar.max_value - bar.page > 1.0 and bar.value > 1.0:
				_follow = false
				_stick_gen += 1
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_mark_scroll.call_deferred()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_mark_scroll.call_deferred()
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_mark_scroll.call_deferred()
	elif event is InputEventPanGesture:
		_mark_scroll.call_deferred()


func _mark_scroll() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	var bottom := bar.max_value - bar.page
	var at_bottom := bottom <= 1.0 or bar.value >= bottom - 12.0
	if at_bottom:
		_follow = true
		_stick_bottom()
	else:
		_follow = false
		_stick_gen += 1


func _stick_bottom() -> void:
	if not _follow or _scroll == null:
		return
	_pin_log()
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## Layout catches up a frame or two after new lines are added. A scroll-up cancels this.
func _stick_bottom_soon() -> void:
	_stick_gen += 1
	var gen := _stick_gen
	for _i in 3:
		if gen != _stick_gen or not _follow:
			return
		_stick_bottom()
		await get_tree().process_frame


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
	_sync_chat_frame()


func _on_focus_exited() -> void:
	_set_typing(false)
	_stop_typing()
	_sync_chat_frame()


func _refresh_log() -> void:
	if _feed == null:
		return
	var saved := _scroll.scroll_vertical if _scroll else 0
	for c in _feed.get_children():
		if c != _spacer:
			_feed.remove_child(c)
			c.free()
	if _entries.is_empty():
		_feed.add_child(_hint("Chat with friends here."))
	else:
		for entry in _entries:
			_feed.add_child(_message_block(str(entry["speaker"]), str(entry["message"])))
	_pin_log()
	if _follow:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	else:
		_scroll.scroll_vertical = saved
	if _follow:
		_stick_bottom_soon()
	else:
		_restore_scroll.call_deferred(saved)


func _restore_scroll(saved: int) -> void:
	if _follow or _scroll == null:
		return
	_pin_log()
	_scroll.scroll_vertical = saved


func _fit_widths() -> void:
	var w := _scroll.size.x - 16.0  # keep wrapped lines clear of the scrollbar
	if w < 8.0:
		return
	for c in _feed.get_children():
		if c == _spacer:
			continue
		var block := c as Control
		block.custom_minimum_size.x = w
		for lab in block.get_children():
			if lab is Label:
				(lab as Label).custom_minimum_size.x = w


## Short history sits on the bottom of the panel, the way a chat is read.
func _pin_log() -> void:
	if _scroll == null or _feed == null or _spacer == null:
		return
	_fit_widths()
	var sep := float(_feed.get_theme_constant("separation"))
	var content := 0.0
	var n := 0
	for c in _feed.get_children():
		if c == _spacer:
			continue
		content += (c as Control).get_combined_minimum_size().y
		n += 1
	if n > 0:
		content += sep * n
	var extra := maxf(0.0, _scroll.size.y - content)
	if absf(_spacer.custom_minimum_size.y - extra) > 1.0:
		_spacer.custom_minimum_size.y = extra


func _message_block(speaker: String, message: String) -> Control:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 2)
	var who := Label.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.text = speaker
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_theme_font_override("font", UIKit.THEME.get_font("font", "Strong"))
	who.add_theme_font_size_override("font_size", NAME_SIZE)
	var mine := speaker == SPEAKER or speaker == str(Net.local_profile().get("name", ""))
	who.add_theme_color_override("font_color", T.TEAL_PRESSED if mine else T.NAVY_TITLE)
	var said := Label.new()
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	said.text = message
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.add_theme_font_size_override("font_size", BODY_SIZE)
	said.add_theme_constant_override("line_spacing", 4)
	said.add_theme_color_override("font_color", T.NAVY)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(who)
	block.add_child(said)
	return block


func _hint(text: String) -> Label:
	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", T.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return hint


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


## Navy speech bubble, drawn so the closed-chat button does not depend on an imported icon.
class _ChatGlyph:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var navy := Color("#15274D")
		var body := Rect2(size.x * 0.22, size.y * 0.28, size.x * 0.56, size.y * 0.36)
		var bubble := StyleBoxFlat.new()
		bubble.bg_color = navy
		bubble.set_corner_radius_all(6)
		bubble.draw(get_canvas_item(), body)
		var tail := PackedVector2Array([
			Vector2(body.position.x + body.size.x * 0.22, body.end.y - 1.0),
			Vector2(body.position.x + body.size.x * 0.46, body.end.y - 1.0),
			Vector2(body.position.x + body.size.x * 0.16, body.end.y + size.y * 0.12),
		])
		draw_colored_polygon(tail, navy)
