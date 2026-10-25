extends CanvasLayer

## Local catch panel. Friends see the rod and bobber, not this bar.
## Hold Space or the mouse button to raise the band. Move or Escape to leave.

const FISH: Array[Dictionary] = [
	{"name": "Sunny", "model": "fish_round", "color": Color(0.95, 0.55, 0.18), "speed": 0.32, "coins": 3, "lo": 18, "hi": 28},
	{"name": "Drift", "model": "fish_slim", "color": Color(0.25, 0.72, 0.7), "speed": 0.46, "coins": 5, "lo": 24, "hi": 36},
	{"name": "Bramble", "model": "fish_spiky", "color": Color(0.58, 0.36, 0.78), "speed": 0.58, "coins": 8, "lo": 30, "hi": 46},
]

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
var _band_y := 0.32
var _band_h := 0.38
var _progress := 0.42
var _in_band := false
var _held := false
var _finger := false
var _paid := false

# Presentation follows Images/UI - Fishing.png (Ready / Bite / Reel / Result); logic unchanged.
const A := preload("res://ui/activities/act_style.gd")
const FISH_ICON := {"fish_round": "fishing/fish_round", "fish_slim": "fishing/fish_slim", "fish_spiky": "fishing/fish_spiky"}

var _status: Label
var _hint: Label
var _track: PanelContainer
var _band: PanelContainer
var _mark: TextureRect
var _meter: PanelContainer
var _fill: PanelContainer
var _card: Control
var _card_title: Label
var _card_body: Label
var _panel: PanelContainer
var _pages := {}
var _card_icon: TextureRect
var _miss_box: PanelContainer
var _bob_icon: TextureRect
var _bite_clock: Label
var _reel_name: Label
var _reel_hint: Label
var _meter_label: Label


func open(penguin: Node) -> void:
	_penguin = penguin
	_phase = "ready"
	_show_page("ready")
	_lock_clicks(false)


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.THEME
	add_child(root)
	_panel = A.panel(26, 26)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if Mobile.active():
		var vp := get_viewport().get_visible_rect().size
		var bottom := maxf(420.0, vp.y - Mobile.pad() - 12.0) if vp.y > 200.0 else 560.0
		A.pin(root, _panel, Vector4(0.5, 0, 0.5, 0), Vector4(-210, 12, 210, bottom))
	else:
		A.pin(root, _panel, Vector4(1, 0.5, 1, 0.5), Vector4(-470, -300, -40, 300))
	var stack := Control.new()
	_panel.add_child(stack)
	# READY
	var ready := _page(stack, "ready")
	ready.add_child(A.title("Gone Fishing!", 38, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := A.label("Cast, wait, then reel\nwhen you get a bite.", 20, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	ready.add_child(sub)
	ready.add_child(_bobber(150))
	var cast := A.button("Cast", "primary", "hook", 28, Vector2(0, 72))
	cast.pressed.connect(func() -> void: if _phase in ["ready", "card"]: _begin_cast())
	ready.add_child(cast)
	ready.add_child(_leave_btn())
	# BITE
	var bite := _page(stack, "bite")
	bite.add_child(A.title("Bite!", 52, HORIZONTAL_ALIGNMENT_CENTER))
	bite.add_child(A.label("Hook now!", 26, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	_bite_clock = A.label("", 20, A.SUB, true, HORIZONTAL_ALIGNMENT_CENTER)
	bite.add_child(_bite_clock)
	var splash := _bobber(120)
	bite.add_child(splash)
	var hook := A.button("Hook", "primary", "hook", 30, Vector2(0, 76))
	hook.pressed.connect(func() -> void: if _phase == "bite": _begin_reel())
	bite.add_child(hook)
	bite.add_child(_leave_btn())
	# WAIT (bobber floats; same layout as ready, no Cast)
	var wait := _page(stack, "wait")
	_status = A.title("Waiting...", 36, HORIZONTAL_ALIGNMENT_CENTER)
	wait.add_child(_status)
	_hint = A.label("Watch the bobber.", 20, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	wait.add_child(_hint)
	_bob_icon = _bobber(170)
	wait.add_child(_bob_icon)
	wait.add_child(A.expander())
	wait.add_child(_leave_btn())
	# REEL
	var reel := _page(stack, "reel")
	reel.add_child(A.title("Reel It In!", 36, HORIZONTAL_ALIGNMENT_CENTER))
	_reel_name = A.label("", 22, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	reel.add_child(_reel_name)
	_reel_hint = A.label("Hold to raise  ·  Release to lower", 18, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	reel.add_child(_reel_hint)
	var hold := A.button("Hold", "primary", "", 26, Vector2(0, 72))
	hold.button_down.connect(func() -> void: _finger = true)
	hold.button_up.connect(func() -> void: _finger = false)
	hold.focus_mode = Control.FOCUS_NONE
	reel.add_child(hold)
	var row := A.hbox(22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reel.add_child(row)
	var arrow := A.icon("play", 26, A.TEAL)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	_track = PanelContainer.new()
	_track.custom_minimum_size = Vector2(96, 160 if Mobile.active() else 320)
	_track.add_theme_stylebox_override("panel", A.box(Color("#E6E2DA"), 30, 2, Color("#D8D2C6")))
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_track)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(holder)
	_band = PanelContainer.new()
	_band.add_theme_stylebox_override("panel", A.box(A.TEAL, 6))
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_band)
	_mark = TextureRect.new()
	_mark.texture = A.asset_icon("fishing/fish_round")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_mark)
	var right := A.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(A.spacer(0, 70))
	var catch_row := A.hbox(10)
	catch_row.add_child(A.label("Catch", 21, A.NAVY, true))
	catch_row.add_child(A.expander())
	_meter_label = A.label("0%", 21, A.TEAL_DARK, true)
	catch_row.add_child(_meter_label)
	right.add_child(catch_row)
	_meter = PanelContainer.new()
	_meter.custom_minimum_size = Vector2(0, 30)
	_meter.add_theme_stylebox_override("panel", A.box(Color("#E6E2DA"), 15))
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_meter)
	var mh := Control.new()
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(mh)
	_fill = PanelContainer.new()
	_fill.add_theme_stylebox_override("panel", A.box(A.TEAL, 15))
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mh.add_child(_fill)
	right.add_child(A.expander())
	right.add_child(_leave_btn())
	# RESULT (caught card + escaped inset; mutually exclusive in play)
	var res := _page(stack, "card")
	var top := A.hbox(16)
	res.add_child(top)
	_card = A.vbox(4)
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_card)
	_card_title = A.title("Caught!", 38, HORIZONTAL_ALIGNMENT_CENTER)
	_card.add_child(_card_title)
	_card_icon = TextureRect.new()
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.custom_minimum_size = Vector2(0, 150)
	_card.add_child(_card_icon)
	_card_body = A.label("", 22, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	_card.add_child(_card_body)
	_miss_box = PanelContainer.new()
	_miss_box.add_theme_stylebox_override("panel", A.box(A.CARD, 18, 0, Color.TRANSPARENT, 12))
	_miss_box.custom_minimum_size = Vector2(120, 0)
	var mv := A.vbox(4)
	_miss_box.add_child(mv)
	mv.add_child(A.label("It got away...", 16, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
	var ghost := A.icon("fish", 64, Color("#8FA9C4"))
	ghost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mv.add_child(ghost)
	mv.add_child(A.label("Try again!", 15, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(_miss_box)
	var again := A.button("Cast again", "primary", "rod", 26, Vector2(0, 70))
	again.pressed.connect(_begin_cast)
	res.add_child(again)
	res.add_child(_leave_btn())
	_show_page("ready")
	_phase = "ready"


func _page(stack: Control, page_name: String) -> VBoxContainer:
	var v := A.vbox(14)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(v)
	_pages[page_name] = v
	return v


func _show_page(page_name: String) -> void:
	for k in _pages:
		_pages[k].visible = k == page_name


func _bobber(h: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = A.asset_icon("fishing/bobber")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(0, h)
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _leave_btn() -> Button:
	var b := A.button("Leave", "secondary", "", 22, Vector2(0, 58))
	b.pressed.connect(_leave)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _penguin == null or not is_instance_valid(_penguin):
		return
	if not _penguin.has_method("is_fishing") or not bool(_penguin.call("is_fishing")):
		return
	var down := _finger or Input.is_action_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var pressed := down and not _held
	_held = down
	_age += delta
	match _phase:
		"cast":
			if _age >= 0.5:
				_begin_wait()
		"wait":
			_wait_left -= delta
			if _bob_icon:
				_bob_icon.pivot_offset = _bob_icon.size * 0.5
				_bob_icon.scale = Vector2.ONE * (1.0 + sin(_age * 3.4) * 0.06)
				_bob_icon.modulate = Color(1, 0.78, 0.55) if _wait_left < 0.6 else Color.WHITE
			if _wait_left < 0.6 and _wait_left > 0.0:
				_hint.text = "Get ready to hook!"
			if _wait_left <= 0.0:
				_begin_bite()
		"bite":
			_bite_left -= delta
			if _bite_clock:
				_bite_clock.text = ("Tap Hook  ·  %.1f" if Mobile.active() else "Space, click, or Hook  ·  %.1f") % maxf(_bite_left, 0.0)
			if pressed:
				_begin_reel()
			elif _bite_left <= 0.0:
				_show_card("", "")
				_tell("miss")
		"reel":
			_step_reel(delta)
		"card", "ready":
			pass   # waits for Cast / Cast again (mockup flow)
	_layout_bar()


func _begin_cast() -> void:
	_phase = "cast"
	_age = 0.0
	_show_page("wait")
	_status.text = "Casting..."
	_hint.text = "Watch the bobber."
	_lock_clicks(false)
	_tell("cast")


func _begin_wait() -> void:
	_phase = "wait"
	_wait_left = randf_range(0.8, 1.7)
	_status.text = "Waiting..."
	_hint.text = "Hook when the bobber dips."
	_lock_clicks(false)
	_tell("wait")


func _begin_bite() -> void:
	_phase = "bite"
	_bite_left = 2.6
	_show_page("bite")
	_lock_clicks(true)
	_tell("bite")


func _begin_reel() -> void:
	_phase = "reel"
	_fish = FISH[_pick_fish()]
	_fish_y = randf_range(0.3, 0.7)
	_fish_v = 0.5 * float(_fish["speed"]) * (1.0 if randf() > 0.5 else -1.0)
	_turn_left = _next_turn()
	_band_y = clampf(_fish_y - _band_h * 0.5, 0.0, 1.0 - _band_h)
	_progress = 0.42
	_in_band = true
	_paid = false
	_mark.texture = A.asset_icon(FISH_ICON.get(str(_fish["model"]), "fishing/fish_round"))
	_mark.modulate = Color.WHITE
	if _reel_name:
		_reel_name.text = str(_fish["name"])
	_show_page("reel")
	_lock_clicks(true)
	_tell("reel")


func _step_reel(delta: float) -> void:
	var speed := float(_fish["speed"])
	_turn_left -= delta
	if _turn_left <= 0.0:
		_turn_left = _next_turn()
		_fish_v = 0.5 * speed * (1.0 if randf() > 0.5 else -1.0)
	_fish_y += _fish_v * delta
	if _fish_y > 0.96:
		_fish_y = 0.96
		_fish_v = -absf(_fish_v)
	elif _fish_y < 0.04:
		_fish_y = 0.04
		_fish_v = absf(_fish_v)
	if _held:
		_band_y += 1.65 * delta
	else:
		_band_y -= 1.25 * delta
	_band_y = clampf(_band_y, 0.0, 1.0 - _band_h)
	_in_band = _fish_y >= _band_y and _fish_y <= _band_y + _band_h
	if _in_band:
		_progress += 0.28 * delta
	else:
		_progress -= 0.1 * delta
	_progress = clampf(_progress, 0.0, 1.0)
	if _progress >= 1.0:
		_caught()
	elif _progress <= 0.0:
		_show_card("", "")
		_tell("miss")


func _caught() -> void:
	var size := randi_range(int(_fish["lo"]), int(_fish["hi"]))
	var coins := int(_fish["coins"])
	if not _paid:
		_paid = true
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("grant_coins"):
			world.call("grant_coins", coins)
	_show_card(str(_fish["name"]), "%s  ·  %d cm\n+%d coins" % [str(_fish["name"]), size, coins])
	_tell("catch:%s" % str(_fish["model"]))


## Empty title means the fish escaped: the "It got away" inset alone, no Caught card.
func _show_card(title: String, body: String) -> void:
	_phase = "card"
	_show_page("card")
	var caught := title != ""
	_card.visible = caught
	_miss_box.visible = not caught
	_miss_box.size_flags_horizontal = Control.SIZE_SHRINK_END if caught else Control.SIZE_EXPAND_FILL
	if caught:
		_card_title.text = "Caught!"
		_card_body.text = body
		_card_icon.texture = A.asset_icon(FISH_ICON.get(str(_fish.get("model", "")), "fishing/fish_round"))
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
	if roll < 0.62:
		return 0
	if roll < 0.9:
		return 1
	return 2


func _next_turn() -> float:
	var speed := float(_fish.get("speed", 1.0))
	return randf_range(1.1, 1.8) / maxf(speed, 0.4)


func _layout_bar() -> void:
	if not _pages["reel"].visible:
		return
	var height := _track.size.y - 8.0
	if height < 8.0:
		return
	var w := _track.size.x
	_band.position = Vector2(4.0, 4.0 + (1.0 - (_band_y + _band_h)) * height)
	_band.size = Vector2(w - 8.0, _band_h * height)
	_mark.position = Vector2(6.0, 4.0 + (1.0 - _fish_y) * height - 26.0)
	_mark.size = Vector2(w - 12.0, 52.0)
	_band.modulate = Color(0.55, 1.15, 0.85) if _in_band else Color(1, 1, 1, 0.92)
	if _reel_hint:
		_reel_hint.text = "In the band. Hold steady." if _in_band else "Hold to raise  ·  Release to lower"
	if _meter_label:
		_meter_label.text = "%d%%" % int(_progress * 100.0)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(maxf(18.0, _meter.size.x * _progress), _meter.size.y)


func preview(state: String) -> void:
	_penguin = null
	_fish = FISH[0]
	match state:
		"bite":
			_show_page("bite")
		"reel":
			_show_page("reel")
			_band_y = 0.36; _fish_y = 0.48; _progress = 0.62
			await get_tree().process_frame
			_layout_bar()
		"result":
			_show_card("Sunny", "Sunny  ·  24 cm")
		"escaped":
			_show_card("", "")
		_:
			_show_page("ready")
