extends CanvasLayer

## Local catch panel. Friends see the rod and bobber, not this bar.
## Hold Space or the mouse button to raise the band. Move or Escape to leave.

const FISH: Array[Dictionary] = [
	{"name": "Sunny", "model": "fish_round", "color": Color(0.95, 0.55, 0.18), "speed": 0.22, "coins": 3, "lo": 18, "hi": 28},
	{"name": "Drift", "model": "fish_slim", "color": Color(0.25, 0.72, 0.7), "speed": 0.34, "coins": 5, "lo": 24, "hi": 36},
	{"name": "Bramble", "model": "fish_spiky", "color": Color(0.58, 0.36, 0.78), "speed": 0.48, "coins": 8, "lo": 30, "hi": 46},
]
const BAND_H := 0.42

var _penguin: Node
var _phase := ""
var _fish: Dictionary = {}
var _age := 0.0
var _bite_left := 0.0
var _wait_left := 0.0
var _card_left := 0.0
var _fish_y := 0.5
var _fish_v := 0.6
var _turn_left := 0.8
var _band_y := 0.29
var _band_h := BAND_H
var _progress := 0.4
var _held := false
var _hook_ready := false
var _grace := 0.0
var _fish_aim := 0.0
var _paid := false

var _status: Label
var _hint: Label
var _track: ColorRect
var _band: ColorRect
var _mark: ColorRect
var _meter: ColorRect
var _fill: ColorRect
var _card: PanelContainer
var _card_title: Label
var _card_body: Label


func open(penguin: Node) -> void:
	_penguin = penguin
	_begin_cast()


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -268.0
	panel.offset_top = 84.0
	panel.offset_right = -16.0
	panel.offset_bottom = 548.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Fishing"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1))
	column.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.78, 0.9, 0.96))
	column.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_track = ColorRect.new()
	_track.custom_minimum_size = Vector2(72, 300)
	_track.color = Color(0.06, 0.14, 0.22, 0.95)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_track)
	_band = ColorRect.new()
	_band.color = Color(1.0, 0.72, 0.32, 0.9)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_band)
	_mark = ColorRect.new()
	_mark.color = Color(0.95, 0.55, 0.18)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_mark)
	_meter = ColorRect.new()
	_meter.custom_minimum_size = Vector2(22, 300)
	_meter.color = Color(0.06, 0.14, 0.22, 0.95)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_meter)
	_fill = ColorRect.new()
	_fill.color = Color(0.45, 0.82, 0.55)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_fill)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.94, 0.98))
	column.add_child(_hint)
	_card = PanelContainer.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _card_style())
	column.add_child(_card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	_card.add_child(card_box)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 22)
	_card_title.add_theme_color_override("font_color", Color(0.12, 0.18, 0.24))
	card_box.add_child(_card_title)
	_card_body = Label.new()
	_card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_body.add_theme_font_size_override("font_size", 16)
	_card_body.add_theme_color_override("font_color", Color(0.18, 0.28, 0.36))
	card_box.add_child(_card_body)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _penguin == null or not is_instance_valid(_penguin):
		return
	if not _penguin.has_method("is_fishing") or not bool(_penguin.call("is_fishing")):
		return
	var down := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var pressed := down and not _held
	_held = down
	_age += delta
	match _phase:
		"cast":
			if pressed:
				_hook_ready = true
			if _age >= 0.5:
				_begin_wait()
		"wait":
			if pressed:
				_hook_ready = true
			_wait_left -= delta
			if _wait_left <= 0.0:
				_begin_bite()
		"bite":
			_bite_left -= delta
			if pressed or _hook_ready:
				_hook_ready = false
				_begin_reel()
			elif _bite_left <= 0.0:
				_show_card("Too slow", "It swam off. Casting again.")
				_tell("miss")
		"reel":
			_step_reel(delta)
		"card":
			_card_left -= delta
			if _card_left <= 0.0:
				_begin_cast()
	_layout_bar()


func _begin_cast() -> void:
	_phase = "cast"
	_age = 0.0
	_hook_ready = false
	_card.visible = false
	_track.visible = true
	_meter.visible = true
	_status.text = "Casting"
	_hint.text = "Watch the bobber."
	_lock_clicks(false)
	_tell("cast")


func _begin_wait() -> void:
	_phase = "wait"
	_wait_left = randf_range(0.9, 1.8)
	_status.text = "Waiting"
	_hint.text = "Tap when the bobber dips. An early tap still counts."
	_lock_clicks(false)
	_tell("wait")


func _begin_bite() -> void:
	if _hook_ready:
		_hook_ready = false
		_begin_reel()
		return
	_phase = "bite"
	_bite_left = 2.2
	_status.text = "Hook!"
	_hint.text = "Tap Space or the mouse."
	_lock_clicks(true)
	_tell("bite")


func _begin_reel() -> void:
	_phase = "reel"
	_fish = FISH[_pick_fish()]
	_fish_y = randf_range(0.32, 0.68)
	_fish_aim = float(_fish["speed"]) * (1.0 if randf() > 0.5 else -1.0)
	_fish_v = _fish_aim
	_turn_left = _next_turn()
	_band_y = clampf(_fish_y - _band_h * 0.5, 0.0, 1.0 - _band_h)
	_progress = 0.4
	_grace = 0.85
	_paid = false
	_mark.color = _fish["color"]
	_status.text = "Reel it in"
	_hint.text = "Hold Space or the mouse to raise the bar."
	_lock_clicks(true)
	_tell("reel")


func _step_reel(delta: float) -> void:
	var speed := float(_fish["speed"])
	_turn_left -= delta
	if _turn_left <= 0.0:
		_turn_left = _next_turn()
		_fish_aim = speed * (1.0 if randf() > 0.5 else -1.0)
	_fish_v = move_toward(_fish_v, _fish_aim, speed * 2.2 * delta)
	_fish_y += _fish_v * delta
	if _fish_y > 0.92:
		_fish_y = 0.92
		_fish_aim = -absf(speed)
		_fish_v = _fish_aim
	elif _fish_y < 0.08:
		_fish_y = 0.08
		_fish_aim = absf(speed)
		_fish_v = _fish_aim
	if _held:
		_band_y += 1.25 * delta
	else:
		_band_y -= 1.05 * delta
	_band_y = clampf(_band_y, 0.0, 1.0 - _band_h)
	var inside := _fish_y + 0.04 >= _band_y and _fish_y - 0.04 <= _band_y + _band_h
	_grace = maxf(_grace - delta, 0.0)
	if inside:
		_progress += 0.5 * delta
	elif _grace <= 0.0:
		_progress -= 0.12 * delta
	_progress = clampf(_progress, 0.0, 1.0)
	if _progress >= 1.0:
		_caught()
	elif _progress <= 0.0:
		_show_card("It got away", "The line went slack. Casting again.")
		_tell("miss")


func _caught() -> void:
	var size := randi_range(int(_fish["lo"]), int(_fish["hi"]))
	var coins := int(_fish["coins"])
	if not _paid:
		_paid = true
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("grant_coins"):
			world.call("grant_coins", coins)
	_show_card(str(_fish["name"]), "%d cm    +%d coins" % [size, coins])
	_tell("catch:%s" % str(_fish["model"]))


func _show_card(title: String, body: String) -> void:
	_phase = "card"
	_card_left = 2.1
	_card.visible = true
	_track.visible = false
	_meter.visible = false
	_card_title.text = title
	_card_body.text = body
	_status.text = ""
	_hint.text = "Move or Escape to leave."
	_lock_clicks(false)


func _tell(phase: String) -> void:
	if _penguin and is_instance_valid(_penguin) and _penguin.has_method("set_fish_phase"):
		_penguin.call("set_fish_phase", phase)


func _lock_clicks(locked: bool) -> void:
	if _penguin and is_instance_valid(_penguin) and _penguin.has_method("set_reel_focus"):
		_penguin.call("set_reel_focus", locked)


func _leave() -> void:
	if _penguin and is_instance_valid(_penguin) and _penguin.has_method("stand_up"):
		_penguin.call("stand_up")


func _pick_fish() -> int:
	var roll := randf()
	if roll < 0.5:
		return 0
	if roll < 0.82:
		return 1
	return 2


func _next_turn() -> float:
	return randf_range(1.15, 2.1)


func _layout_bar() -> void:
	var height := _track.size.y
	if height < 8.0:
		return
	_band.position = Vector2(8.0, (1.0 - (_band_y + _band_h)) * height)
	_band.size = Vector2(56.0, _band_h * height)
	_mark.position = Vector2(14.0, (1.0 - _fish_y) * height - 9.0)
	_mark.size = Vector2(44.0, 18.0)
	var meter_h := _meter.size.y
	_fill.position = Vector2(0.0, (1.0 - _progress) * meter_h)
	_fill.size = Vector2(_meter.size.x, _progress * meter_h)


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.2, 0.32, 0.94)
	box.border_color = Color(0.86, 0.93, 0.98)
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	return box


func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.96, 0.93, 0.86)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
