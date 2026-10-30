extends Node

## Headless chat check. No window, no desktop input.
##   Godot --headless --path . res://tools/type_probe.tscn
## T focuses chat and the opening T is not typed. Space, Shift+T and an echoed T do not.
## While the line is focused, WASD does not move the penguin. Escape releases it and walking works.

var _w: Node
var _p: CharacterBody3D
var _entry: LineEdit
var _fails := 0


func _ready() -> void:
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	_p = _w.get_node("Penguin")
	_entry = _w.get_node("PlayHud").get_node("Root/Chat/Entry")
	await _w.travel_to("town", "BusArrival")
	await get_tree().create_timer(2.0).timeout
	_release_move()
	_check("space does not open chat", await _space_closed())
	_check("shift+T does not open chat", await _shifted_t_closed())
	_check("echoed T does not open chat", await _echo_t_closed())
	_check("T opens chat", await _open_with_t())
	_check("opening T is not typed", _entry.text == "")
	_check("letters type into chat", await _type_hi())
	_check("WASD is locked while chat is open", await _walk_locked())
	_check("Escape closes chat", await _close_with_escape())
	_check("WASD walks after chat closes", await _walk_free())
	print("TYPE_PROBE fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _space_closed() -> bool:
	await _tap(KEY_SPACE)
	return not _entry.has_focus()


func _shifted_t_closed() -> bool:
	await _tap(KEY_T, true)
	return not _entry.has_focus()


func _echo_t_closed() -> bool:
	await _tap(KEY_T, false, true)
	return not _entry.has_focus()


func _open_with_t() -> bool:
	await _tap(KEY_T)
	return _entry.has_focus() and bool(_p.get("_typing_locked"))


func _type_hi() -> bool:
	await _tap(KEY_H, false, false, 104)
	await _tap(KEY_I, false, false, 105)
	return _entry.text == "hi"


func _walk_locked() -> bool:
	var home := _p.global_position
	for i in 8:
		_p.global_position = home
		_p.velocity = Vector3.ZERO
		var moved := await _hold_dir(float(i) / 8.0 * TAU, 0.35)
		if moved > 0.05:
			return false
	_p.global_position = home
	_p.velocity = Vector3.ZERO
	return true


func _close_with_escape() -> bool:
	await _tap(KEY_ESCAPE)
	return not _entry.has_focus() and not bool(_p.get("_typing_locked"))


func _walk_free() -> bool:
	var home := _p.global_position
	var best := 0.0
	for i in 8:
		_p.global_position = home
		_p.velocity = Vector3.ZERO
		best = maxf(best, await _hold_dir(float(i) / 8.0 * TAU, 0.45))
	return best > 0.35


func _tap(code: Key, shift := false, echo := false, unicode := 0) -> void:
	await _key(code, true, shift, echo, unicode)
	await _key(code, false, shift, false, 0)


func _key(code: Key, pressed: bool, shift: bool, echo: bool, unicode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	event.echo = echo
	event.unicode = unicode
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _hold_dir(angle: float, seconds: float) -> float:
	var before := _p.global_position
	var dir := Vector3(cos(angle), 0.0, sin(angle))
	var t := 0.0
	while t < seconds:
		_press(dir)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release_move()
	return Vector2(_p.global_position.x - before.x, _p.global_position.z - before.z).length()


func _press(dir: Vector3) -> void:
	_release_move()
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		Input.action_press("move_forward", 1.0)
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	var right := cam.global_transform.basis.x
	right.y = 0.0
	dir = dir.normalized()
	var x := dir.dot(right.normalized())
	var y := dir.dot(fwd.normalized())
	var m := maxf(absf(x), absf(y))
	x /= m
	y /= m
	if x > 0.0:
		Input.action_press("move_right", x)
	if x < 0.0:
		Input.action_press("move_left", -x)
	if y > 0.0:
		Input.action_press("move_forward", y)
	if y < 0.0:
		Input.action_press("move_back", -y)


func _release_move() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("TYPE_PROBE %s %s focus=%s lock=%s text=\"%s\" at=(%.1f, %.1f)" % [
		"FAIL" if not ok else "ok  ", label, _entry.has_focus(), _p.get("_typing_locked"), _entry.text,
		_p.global_position.x, _p.global_position.z])
