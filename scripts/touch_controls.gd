class_name TouchControls
extends CanvasLayer
## On-screen stick, jump, interact, and a drag-to-look zone for touch browsers.
## The stick feeds the same move/jump/aim actions the keyboard uses, so town
## movement, the sled, and the arcade games all share it.

const T := preload("res://ui/theme/ui_tokens.gd")

var _stick := Vector2.ZERO
var _dragging := false
var _pointer := -1
var _look_pointer := -1
var _held := {}
var _base: Control
var _knob: Control
var _jump: Button
var _use: Button
var _talk: Button
var _aim_up: Button
var _aim_down: Button
var _shoot: Button
var _look_travel := 0.0
var _forwarding := false
var _forward_frames := 0

static var _live: TouchControls


## True while a touch on the right side of the screen is a camera drag, so the
## emulated mouse click must not also walk, shoot, or throw.
static func blocks_click(at: Vector2) -> bool:
	if _live == null or not is_instance_valid(_live) or not _live.visible or _live._forwarding:
		return false
	return _live._claims(at)


func _ready() -> void:
	_live = self
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Pad"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_base = _disc(root, 148.0, Color(T.NAVY, 0.28))
	_knob = _disc(_base, 64.0, Color(T.PANEL, 0.95))
	_jump = _round(root, "Jump", "jump")
	_use = _round(root, "Use", "interact")
	_talk = _round(root, "Talk", "push_to_talk")
	_aim_up = _round(root, "Higher", "aim_up")
	_aim_down = _round(root, "Lower", "aim_down")
	_shoot = _round(root, "Shoot", "")
	_shoot.pressed.connect(_shoot_ball)
	for b in [_jump, _use, _talk, _aim_up, _aim_down]:
		b.button_down.connect(_press.bind(str(b.get_meta("action"))))
		b.button_up.connect(_release_btn.bind(str(b.get_meta("action"))))
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = _wants_pad()


func _exit_tree() -> void:
	if _live == self:
		_live = null


func _disc(parent: Control, diameter: float, color: Color) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(diameter, diameter)
	d.mouse_filter = Control.MOUSE_FILTER_STOP if parent == get_child(0) else Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(diameter))
	panel.add_theme_stylebox_override("panel", box)
	d.add_child(panel)
	return d


func _round(parent: Control, text: String, action: String) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("action", action)
	b.custom_minimum_size = Vector2(84, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", T.NAVY)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = T.PANEL if state != "pressed" else T.TEAL_SOFT
		box.set_corner_radius_all(42)
		box.set_border_width_all(3)
		box.border_color = T.NAVY if state != "pressed" else T.TEAL
		b.add_theme_stylebox_override(state, box)
	parent.add_child(b)
	return b


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var margin := 28.0
	_place(_base, margin, vp.y - margin - 148.0, 148.0, 148.0)
	_place(_knob, 42.0, 42.0, 64.0, 64.0)
	var right := vp.x - margin - 84.0
	var y := vp.y - margin - 84.0
	_place(_jump, right, y, 84.0, 84.0)
	_place(_use, right - 96.0, y, 84.0, 84.0)
	_place(_aim_down, right - 96.0, y - 96.0, 84.0, 72.0)
	_place(_shoot, right, y - 96.0, 84.0, 84.0)
	_place(_aim_up, right, y - 188.0, 84.0, 72.0)
	_place(_talk, right - 96.0, y - 188.0, 84.0, 84.0)
	_refresh_buttons()


func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


func _process(_delta: float) -> void:
	if _forwarding:
		_forward_frames += 1
		if _forward_frames > 2:
			_forwarding = false
			_forward_frames = 0
	else:
		_forward_frames = 0
	var show := _wants_pad()
	layer = 60 if _arcade() else 40
	if visible != show:
		visible = show
		if not show:
			_cancel_stick()
	if not visible:
		return
	_refresh_buttons()
	_drive_stick()


func _wants_pad() -> bool:
	if not Mobile.active():
		return false
	if _arcade():
		return true
	if UIRouter.is_open():
		return false
	return _play_visible()


func _arcade() -> bool:
	var top := UIRouter.top()
	return top != null and is_instance_valid(top) and top.is_in_group("touch_play")


func _on_court() -> bool:
	if _arcade():
		return false
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	return player != null and Net.court_here(player.global_position)


func _refresh_buttons() -> void:
	var court := _on_court()
	var playing := _arcade()
	_use.visible = not playing
	_shoot.visible = court
	_aim_up.visible = court
	_aim_down.visible = court
	_talk.visible = not playing and bool(UIRouter.settings.get("push_to_talk", false))


func _shoot_ball() -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player and player.has_method("court_shoot"):
		player.call("court_shoot")


func _play_visible() -> bool:
	var hud := get_tree().get_first_node_in_group("play_hud") as CanvasLayer
	return hud != null and hud.visible


func _input(event: InputEvent) -> void:
	if _forwarding and event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			_forwarding = false
		return
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _base.get_global_rect().grow(36).has_point(touch.position):
			_dragging = true
			_pointer = touch.index
			_move_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _pointer:
			_cancel_stick()
			get_viewport().set_input_as_handled()
		elif touch.pressed and _claims(touch.position) and not _over_button(touch.position):
			_look_pointer = touch.index
			_look_travel = 0.0
		elif not touch.pressed and touch.index == _look_pointer:
			var tap := _look_travel < 22.0 and not _over_button(touch.position)
			var at := touch.position
			_look_pointer = -1
			if tap:
				_emit_click(at)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer and _dragging:
			_move_knob(drag.position)
			get_viewport().set_input_as_handled()
		elif drag.index == _look_pointer:
			_look_travel += drag.relative.length()
			_turn(drag.relative.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and DisplayServer.is_touchscreen_available() == false:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed and _base.get_global_rect().grow(36).has_point(mouse.position):
			_dragging = true
			_pointer = 0
			_move_knob(mouse.position)
			get_viewport().set_input_as_handled()
		elif mouse.pressed and _claims(mouse.position) and not _over_button(mouse.position):
			_look_pointer = 0
			_look_travel = 0.0
			get_viewport().set_input_as_handled()
		elif not mouse.pressed and _dragging:
			_cancel_stick()
		elif not mouse.pressed and _look_pointer == 0:
			var tap := _look_travel < 22.0 and not _over_button(mouse.position)
			var at := mouse.position
			_look_pointer = -1
			if tap:
				_emit_click(at)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging and not DisplayServer.is_touchscreen_available():
		_move_knob((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _look_pointer == 0 and not DisplayServer.is_touchscreen_available():
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_look_travel += motion.relative.length()
			_turn(motion.relative.x)
			get_viewport().set_input_as_handled()


func _over_button(at: Vector2) -> bool:
	for b in [_jump, _use, _talk, _aim_up, _aim_down, _shoot]:
		if b.visible and b.get_global_rect().has_point(at):
			return true
	return false


func _claims(at: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	if at.x > vp.x * 0.45:
		return true
	return _base != null and _base.get_global_rect().grow(36).has_point(at)


func _emit_click(at: Vector2) -> void:
	_forwarding = true
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)


func _move_knob(screen_at: Vector2) -> void:
	var center := _base.get_global_rect().get_center()
	var offset := screen_at - center
	var radius := 42.0
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob.position = Vector2(42, 42) + offset
	_stick = Vector2(offset.x / radius, offset.y / radius)


func _cancel_stick() -> void:
	_dragging = false
	_pointer = -1
	_stick = Vector2.ZERO
	_knob.position = Vector2(42, 42)
	_drive_stick()


func _drive_stick() -> void:
	# Screen up is forward, matching the keyboard (get_vector y is negative when W is held).
	_axis("move_right", maxf(_stick.x, 0.0))
	_axis("move_left", maxf(-_stick.x, 0.0))
	_axis("move_back", maxf(_stick.y, 0.0))
	_axis("move_forward", maxf(-_stick.y, 0.0))


func _axis(action: String, strength: float) -> void:
	var on := strength > 0.18
	if on:
		Input.action_press(action, strength)
		_held[action] = true
	elif bool(_held.get(action, false)) and not _key_held(action):
		Input.action_release(action)
		_held[action] = false


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)
	_held[action] = true


func _release_btn(action: String) -> void:
	if _key_held(action):
		_held[action] = false
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	_held[action] = false


func _key_held(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and Input.is_physical_key_pressed((ev as InputEventKey).physical_keycode):
			return true
	return false


func _turn(pixels: float) -> void:
	var rig := get_tree().get_first_node_in_group("follow_camera")
	if rig and rig.has_method("add_yaw"):
		rig.call("add_yaw", -pixels * 0.008)
