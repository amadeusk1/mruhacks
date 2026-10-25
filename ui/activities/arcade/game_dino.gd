extends Control

## Endless run, in the style of the offline dinosaur game.
## Charcoal shapes on a paper desert: a two-frame rex, armed cacti, and birds
## you duck under or run beneath. Space or W jumps. S ducks.

var score := 0
var over := false
var won := false

const _GROUND := 0.72
const _NIGHT := 250

const _REX: Array[Rect2] = [
	Rect2(0, 10, 5, 2), Rect2(3, 11, 6, 3),
	Rect2(8, 9, 9, 7), Rect2(15, 15, 3, 4),
	Rect2(16, 18, 6, 5), Rect2(21, 19, 4, 3), Rect2(21, 16, 4, 2),
	Rect2(16, 11, 3, 2), Rect2(18, 9, 2, 2), Rect2(18, 23, 3, 2),
]
const _REX_EYE := Rect2(18, 20, 2, 2)
const _REX_MOUTH := Rect2(21, 18, 4, 1)
const _REX_HIT := Rect2(8, 0, 17, 25)
const _LEG_A: Array[Rect2] = [Rect2(9, 0, 3, 9), Rect2(8, 0, 5, 2), Rect2(14, 5, 3, 4), Rect2(16, 3, 2, 3)]
const _LEG_B: Array[Rect2] = [Rect2(14, 0, 3, 9), Rect2(13, 0, 5, 2), Rect2(9, 5, 3, 4), Rect2(8, 3, 2, 3)]
const _JUMP_LEGS: Array[Rect2] = [Rect2(7, 3, 5, 3), Rect2(10, 5, 3, 2), Rect2(6, 2, 3, 2)]
const _DUCK: Array[Rect2] = [
	Rect2(0, 5, 6, 2), Rect2(5, 4, 11, 4),
	Rect2(14, 5, 8, 3), Rect2(21, 6, 4, 2), Rect2(21, 4, 4, 1),
]
const _DUCK_EYE := Rect2(16, 6, 2, 2)
const _DUCK_MOUTH := Rect2(21, 5, 4, 1)
const _DUCK_HIT := Rect2(5, 0, 20, 8)
const _DUCK_LEG_A: Array[Rect2] = [Rect2(8, 0, 2, 4), Rect2(7, 0, 4, 2)]
const _DUCK_LEG_B: Array[Rect2] = [Rect2(13, 0, 2, 4), Rect2(12, 0, 4, 2)]
const _CACTUS_TALL: Array[Rect2] = [
	Rect2(3, 0, 3, 16), Rect2(0, 9, 2, 5), Rect2(0, 9, 4, 2), Rect2(6, 6, 2, 6), Rect2(5, 6, 3, 2),
]
const _CACTUS_SMALL: Array[Rect2] = [Rect2(2, 0, 2, 10), Rect2(0, 5, 2, 4), Rect2(0, 5, 3, 2)]
const _BIRD: Array[Rect2] = [Rect2(0, 0, 8, 3), Rect2(7, 1, 3, 3), Rect2(10, 2, 3, 1), Rect2(6, 3, 2, 2)]
const _WING_UP: Array[Rect2] = [Rect2(1, 3, 8, 2), Rect2(3, 5, 5, 2)]
const _WING_DOWN: Array[Rect2] = [Rect2(-5, 0, 7, 2)]
const _CLOUD: Array[Rect2] = [Rect2(2, 0, 8, 3), Rect2(0, 1, 3, 2), Rect2(8, 1, 4, 3), Rect2(4, 3, 5, 2)]

var _y := 0.0
var _vy := 0.0
var _duck := false
var _speed := 0.38
var _spawn := 0.0
var _obstacles: Array = []
var _clouds: Array = []
var _time := 0.0
var _leg := 0.0
var _dist := 0.0
var _space_down := false


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
	_clouds = [{"x": 0.15, "y": 0.16}, {"x": 0.48, "y": 0.28}, {"x": 0.78, "y": 0.12}]
	_time = 0.0
	_leg = 0.0
	_dist = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if over:
		queue_redraw()
		return
	if size.x < 2.0:
		return
	_time += delta
	_leg += delta * (_speed * 14.0)
	_dist += _speed * delta
	_speed = minf(0.92, _speed + delta * 0.012)
	score = int(_time * 10.0)
	var space := Input.is_action_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)
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
	for cloud in _clouds:
		cloud["x"] = float(cloud["x"]) - _speed * delta * 0.22
		if float(cloud["x"]) < -0.25:
			cloud["x"] = float(cloud["x"]) + 1.45
	_spawn -= delta
	if _spawn <= 0.0:
		var bird := randf() < 0.28 and _time > 6.0
		if bird:
			_obstacles.append({"x": 1.15, "bird": true, "high": randf() < 0.5})
		else:
			var roll := randf()
			var kind := "pair" if roll > 0.72 else ("tall" if roll > 0.35 else "small")
			_obstacles.append({"x": 1.15, "bird": false, "kind": kind})
		_spawn = randf_range(0.85, 1.45) * (0.55 / _speed)
	var runner := _body()
	var kept: Array = []
	for ob in _obstacles:
		ob["x"] = float(ob["x"]) - _speed * delta
		if float(ob["x"]) > -0.25:
			kept.append(ob)
		if runner.intersects(_hit(ob)):
			over = true
	_obstacles = kept
	queue_redraw()


func _s() -> float:
	return maxf(3.0, floor(minf(size.x / 180.0, size.y / 88.0)))


func _ground() -> float:
	return size.y * _GROUND


func _ink() -> Color:
	return Color(0.96, 0.96, 0.96) if score >= _NIGHT else Color(0.325, 0.325, 0.325)


func _paper() -> Color:
	return Color(0.16, 0.16, 0.18) if score >= _NIGHT else Color(0.969, 0.969, 0.969)


func _screen_box(origin: Vector2, cell: Rect2) -> Rect2:
	var s := _s()
	return Rect2(
		origin.x + cell.position.x * s,
		origin.y - (cell.position.y + cell.size.y) * s,
		cell.size.x * s,
		cell.size.y * s
	)


func _rex_origin() -> Vector2:
	return Vector2(size.x * 0.12, _ground() - _y * 57.0 * _s())


func _body() -> Rect2:
	var ducking := _duck and _y <= 0.02
	return _screen_box(_rex_origin(), _DUCK_HIT if ducking else _REX_HIT)


func _cactus_rects(kind: String) -> Array:
	if kind == "small":
		return _CACTUS_SMALL.duplicate()
	var rects: Array = _CACTUS_TALL.duplicate()
	if kind == "pair":
		for r in _CACTUS_SMALL:
			rects.append(Rect2(r.position.x + 9.0, r.position.y, r.size.x, r.size.y))
	return rects


func _bird_rects(high: bool) -> Array:
	var base := 27.0 if high else 10.0
	var wing: Array = _WING_UP if int(_time * 6.0) % 2 == 0 else _WING_DOWN
	var rects: Array = []
	for r in _BIRD:
		rects.append(Rect2(r.position.x, r.position.y + base, r.size.x, r.size.y))
	for r in wing:
		rects.append(Rect2(r.position.x, r.position.y + base, r.size.x, r.size.y))
	return rects


func _hit(ob: Dictionary) -> Rect2:
	var rects: Array = _bird_rects(bool(ob.get("high", false))) if bool(ob.get("bird", false)) else _cactus_rects(str(ob.get("kind", "tall")))
	var box := _screen_box(Vector2(float(ob["x"]) * size.x, _ground()), rects[0])
	for i in range(1, rects.size()):
		box = box.merge(_screen_box(Vector2(float(ob["x"]) * size.x, _ground()), rects[i]))
	return box


func _draw() -> void:
	if size.x < 2.0:
		return
	var paper := _paper()
	var ink := _ink()
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	if score >= _NIGHT:
		_draw_night(ink)
	for cloud in _clouds:
		var faint := ink
		faint.a = 0.4
		var origin := Vector2(float(cloud["x"]) * size.x, size.y * float(cloud["y"]))
		for r in _CLOUD:
			draw_rect(_screen_box(origin, r), faint)
	var ground := _ground()
	draw_rect(Rect2(0, ground, size.x, maxf(2.0, _s() * 0.45)), ink)
	_draw_pebbles(ink)
	for ob in _obstacles:
		var origin := Vector2(float(ob["x"]) * size.x, ground)
		var rects: Array = _bird_rects(bool(ob.get("high", false))) if bool(ob.get("bird", false)) else _cactus_rects(str(ob.get("kind", "tall")))
		for r in rects:
			draw_rect(_screen_box(origin, r), ink)
	_draw_rex(ink, paper)


func _draw_night(ink: Color) -> void:
	for i in 14:
		var sx := fposmod(float(i * 97), size.x)
		var sy := fposmod(float(i * 53), size.y * 0.42) + size.y * 0.05
		draw_rect(Rect2(sx, sy, maxf(2.0, _s() * 0.35), maxf(2.0, _s() * 0.35)), ink)
	var moon := Vector2(size.x * 0.8, size.y * 0.2)
	var radius := _s() * 4.2
	draw_circle(moon, radius, ink)
	draw_circle(moon + Vector2(radius * 0.38, -radius * 0.12), radius * 0.82, _paper())


func _draw_pebbles(ink: Color) -> void:
	var s := _s()
	var ground := _ground()
	for i in 18:
		var x := fposmod(float(i) * 0.07 - _dist, 1.15) * size.x
		var w := s * (2.2 if i % 4 == 0 else 1.1)
		var h := s * (0.7 if i % 3 == 0 else 0.35)
		draw_rect(Rect2(x, ground - h, w, h), ink)


func _draw_rex(ink: Color, paper: Color) -> void:
	var origin := _rex_origin()
	var ducking := _duck and _y <= 0.02
	var parts: Array = []
	parts.append_array(_DUCK if ducking else _REX)
	if ducking:
		parts.append_array(_DUCK_LEG_A if over or int(_leg) % 2 == 0 else _DUCK_LEG_B)
	elif _y > 0.02:
		parts.append_array(_JUMP_LEGS)
	elif over:
		parts.append_array(_LEG_A)
	else:
		parts.append_array(_LEG_A if int(_leg) % 2 == 0 else _LEG_B)
	for r in parts:
		draw_rect(_screen_box(origin, r), ink)
	var eye: Rect2 = _DUCK_EYE if ducking else _REX_EYE
	var mouth: Rect2 = _DUCK_MOUTH if ducking else _REX_MOUTH
	draw_rect(_screen_box(origin, eye), paper)
	draw_rect(_screen_box(origin, mouth), paper)
	if not over:
		return
	var box := _screen_box(origin, eye)
	var weight := maxf(2.0, _s() * 0.35)
	draw_line(box.position, box.end, ink, weight)
	draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), ink, weight)
