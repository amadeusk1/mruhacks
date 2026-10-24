extends Control

## Endless run. Space or W jumps. S ducks under the birds.

var score := 0
var over := false
var won := false

const _GROUND := 0.72

var _y := 0.0
var _vy := 0.0
var _duck := false
var _speed := 0.38
var _spawn := 0.0
var _obstacles: Array = []
var _time := 0.0
var _leg := 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	score = 0
	over = false
	won = false
	_y = 0.0
	_vy = 0.0
	_duck = false
	_speed = 0.38
	_spawn = 1.1
	_obstacles.clear()
	_time = 0.0
	_leg = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if over:
		queue_redraw()
		return
	_time += delta
	_leg += delta * (_speed * 14.0)
	_speed = minf(0.92, _speed + delta * 0.012)
	score = int(_time * 10.0)
	var space := Input.is_physical_key_pressed(KEY_SPACE)
	var jump := Input.is_action_just_pressed("move_forward") or (space and not _space_down)
	_space_down = space
	if jump and _y <= 0.001:
		_vy = 1.55
		_duck = false
	_duck = Input.is_action_pressed("move_back") and _y <= 0.001
	_vy -= 3.4 * delta
	_y = maxf(0.0, _y + _vy * delta)
	if _y <= 0.0:
		_vy = 0.0
	_spawn -= delta
	if _spawn <= 0.0:
		var bird := randf() < 0.28 and _time > 6.0
		_obstacles.append({"x": 1.15, "bird": bird, "high": bird and randf() < 0.5})
		_spawn = randf_range(0.85, 1.45) * (0.55 / _speed)
	var runner := _body()
	var kept: Array = []
	for ob in _obstacles:
		ob["x"] = float(ob["x"]) - _speed * delta
		if float(ob["x"]) > -0.2:
			kept.append(ob)
		if runner.intersects(_hit(ob)):
			over = true
	_obstacles = kept
	queue_redraw()


var _space_down := false


func _body() -> Rect2:
	var ground := size.y * _GROUND
	var x := size.x * 0.18
	var h := size.y * (0.11 if _duck else 0.2)
	var lift := _y * size.y * 0.34
	return Rect2(x, ground - h - lift, size.x * 0.07, h)


func _hit(ob: Dictionary) -> Rect2:
	var ground := size.y * _GROUND
	var x := float(ob["x"]) * size.x
	if bool(ob["bird"]):
		var y := ground - size.y * (0.28 if bool(ob["high"]) else 0.16)
		return Rect2(x, y, size.x * 0.07, size.y * 0.06)
	return Rect2(x, ground - size.y * 0.16, size.x * 0.045, size.y * 0.16)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.95, 0.98))
	var ground := size.y * _GROUND
	draw_rect(Rect2(0, ground, size.x, size.y - ground), Color(0.86, 0.9, 0.94))
	draw_line(Vector2(0, ground), Vector2(size.x, ground), Color(0.55, 0.62, 0.7), 3.0)
	for ob in _obstacles:
		var box := _hit(ob)
		if bool(ob["bird"]):
			draw_rect(box, Color(0.25, 0.45, 0.72))
			draw_line(box.position + Vector2(0, box.size.y * 0.4), box.position + Vector2(-18, box.size.y * 0.1), Color(0.2, 0.35, 0.6), 3.0)
		else:
			draw_rect(box, Color(0.28, 0.62, 0.4))
			draw_rect(Rect2(box.position + Vector2(-6, 8), Vector2(6, box.size.y * 0.45)), Color(0.22, 0.5, 0.34))
			draw_rect(Rect2(box.end + Vector2(0, 10), Vector2(6, box.size.y * 0.4)), Color(0.22, 0.5, 0.34))
	var body := _body()
	var col := Color(0.12, 0.22, 0.4)
	draw_rect(body, col)
	if not _duck:
		draw_rect(Rect2(body.end.x - 8, body.position.y - body.size.y * 0.35, body.size.x * 0.55, body.size.y * 0.45), col)
		draw_circle(body.end + Vector2(6, -body.size.y * 0.2), 4.0, Color.WHITE)
	var step := sin(_leg * TAU) * 8.0
	if _y <= 0.01 and not _duck:
		draw_line(body.position + Vector2(body.size.x * 0.3, body.size.y), body.position + Vector2(body.size.x * 0.3 + step, body.size.y + 16), col, 4.0)
		draw_line(body.position + Vector2(body.size.x * 0.7, body.size.y), body.position + Vector2(body.size.x * 0.7 - step, body.size.y + 16), col, 4.0)
	else:
		draw_line(body.position + Vector2(10, body.size.y), body.end + Vector2(-6, 10), col, 4.0)
