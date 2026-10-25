extends Control

## Fish Frenzy: swim with WASD / arrows, eat fish smaller than you to grow, dodge bigger fish and
## jellyfish. Three lives; a short blink of safety after a hit. Grow to full size for a x2 frenzy.

var score := 0
var over := false
var won := false

const _GROW := [0, 12, 30, 60]   ## fish eaten to reach each size step
const _SIZES := [0.032, 0.045, 0.06, 0.078]
const _PAL := [Color("#F2C14E"), Color("#F0645C"), Color("#8BD3E6"), Color("#B48CF0"), Color("#7ED38B")]

var _pos := Vector2(0.5, 0.5)
var _vel := Vector2.ZERO
var _face := 1.0
var _lives := 3
var _eaten := 0
var _stage := 0
var _safe := 0.0
var _time := 0.0
var _spawn := 0.0
var _fish: Array = []      ## {p, v, r, c, jelly}
var _bubbles: Array = []   ## {p, r, v}
var _pops: Array = []      ## {p, t, text}


func _ready() -> void:
	reset()


func reset() -> void:
	score = 0
	over = false
	won = false
	_pos = Vector2(0.5, 0.5)
	_vel = Vector2.ZERO
	_lives = 3
	_eaten = 0
	_stage = 0
	_safe = 1.5
	_time = 0.0
	_spawn = 0.4
	_fish.clear()
	_pops.clear()
	_bubbles.clear()
	for i in 14:
		_bubbles.append({"p": Vector2(randf(), randf()), "r": randf_range(0.003, 0.01), "v": randf_range(0.03, 0.08)})
	queue_redraw()


func _process(delta: float) -> void:
	if size.x < 2.0:
		return
	for b in _bubbles:
		b["p"].y -= float(b["v"]) * delta
		if b["p"].y < -0.05:
			b["p"] = Vector2(randf(), 1.05)
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	for p in _pops:
		p["t"] = float(p["t"]) - delta
	if over:
		queue_redraw()
		return
	_time += delta
	_safe = maxf(0.0, _safe - delta)
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back"))
	_vel = _vel.lerp(dir.limit_length(1.0) * 0.5, 1.0 - exp(-6.0 * delta))
	var aspect := size.x / size.y
	_pos += Vector2(_vel.x / aspect, _vel.y) * delta
	_pos = _pos.clamp(Vector2(0.03, 0.06), Vector2(0.97, 0.94))
	if absf(_vel.x) > 0.05:
		_face = signf(_vel.x)
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = randf_range(0.45, 0.9) * maxf(0.5, 1.0 - _time / 160.0)
		_spawn_fish()
	var me: float = _SIZES[_stage]
	var kept: Array = []
	for f in _fish:
		f["p"] += f["v"] * delta
		if bool(f["jelly"]):
			f["p"].y += sin(_time * 3.0 + float(f["r"]) * 90.0) * 0.04 * delta
		if f["p"].x < -0.2 or f["p"].x > 1.2:
			continue
		var d := Vector2((f["p"].x - _pos.x) * aspect, f["p"].y - _pos.y).length()
		if d < (float(f["r"]) + me) * 0.8:
			if not bool(f["jelly"]) and float(f["r"]) < me * 0.95:
				_eat(f)
				continue
			if _safe <= 0.0:
				_hurt()
		kept.append(f)
	_fish = kept
	queue_redraw()


func _spawn_fish() -> void:
	var left := randf() < 0.5
	var jelly := _time > 12.0 and randf() < 0.12
	var me: float = _SIZES[_stage]
	var r := randf_range(me * 0.45, me * (1.9 if _stage < 3 else 1.3))
	if randf() < 0.45:
		r = randf_range(me * 0.4, me * 0.85)  # plenty of food
	var speed := randf_range(0.08, 0.22) * (1.0 + _time / 120.0)
	_fish.append({"p": Vector2(-0.1 if left else 1.1, randf_range(0.1, 0.9)), "v": Vector2(speed if left else -speed, 0.0),
		"r": 0.04 if jelly else r, "c": _PAL[randi() % _PAL.size()], "jelly": jelly})


func _eat(f: Dictionary) -> void:
	_eaten += 1
	var pts := int(10 + float(f["r"]) * 600.0) * (2 if _stage == 3 else 1)
	score += pts
	_pops.append({"p": f["p"], "t": 0.6, "text": "+%d" % pts})
	if _stage < 3 and _eaten >= _GROW[_stage + 1]:
		_stage += 1
		_pops.append({"p": _pos, "t": 1.0, "text": "FRENZY x2!" if _stage == 3 else "GROW!"})


func _hurt() -> void:
	_lives -= 1
	_safe = 1.6
	if _lives <= 0:
		over = true
	else:
		_stage = maxi(0, _stage - 1)
		_eaten = _GROW[_stage]


func _draw() -> void:
	if size.x < 2.0:
		return
	var w := size.x
	var h := size.y
	# water gradient, light rays and sand
	var top := Color("#1E6FA8")
	var bottom := Color("#0B2F5C")
	for i in 12:
		draw_rect(Rect2(0, h * i / 12.0, w, h / 12.0 + 1), top.lerp(bottom, i / 11.0))
	for i in 5:
		var x := w * (0.1 + 0.2 * i) + sin(_time * 0.4 + i) * 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w * 0.05, 0), Vector2(x + w * 0.12, h), Vector2(x + w * 0.06, h)]),
			Color(1, 1, 1, 0.05))
	draw_rect(Rect2(0, h * 0.94, w, h * 0.06), Color("#D9C08A"))
	for i in 9:
		var kx := w * (0.05 + 0.11 * i)
		var sway := sin(_time * 1.5 + i) * 6.0
		draw_line(Vector2(kx, h * 0.95), Vector2(kx + sway, h * (0.78 - 0.04 * (i % 3))), Color("#3FA66B"), 5.0)
	for b in _bubbles:
		draw_arc(Vector2(b["p"].x * w, b["p"].y * h), float(b["r"]) * h, 0, TAU, 12, Color(1, 1, 1, 0.45), 2.0)
	for f in _fish:
		if bool(f["jelly"]):
			_jelly(Vector2(f["p"].x * w, f["p"].y * h), float(f["r"]) * h)
		else:
			_draw_fish(Vector2(f["p"].x * w, f["p"].y * h), float(f["r"]) * h, signf(f["v"].x), f["c"], false)
	if not (_safe > 0.0 and int(_time * 10.0) % 2 == 0) or over:
		_draw_fish(Vector2(_pos.x * w, _pos.y * h), _SIZES[_stage] * h, _face, Color("#3D7BD9"), true)
	var font := get_theme_default_font()
	for p in _pops:
		var a := clampf(float(p["t"]) * 2.0, 0.0, 1.0)
		var at := Vector2(p["p"].x * w, (p["p"].y - (0.6 - float(p["t"])) * 0.1) * h)
		draw_string(font, at, str(p["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, int(h * 0.05), Color(1, 1, 0.7, a))
	for i in _lives:
		_draw_fish(Vector2(w * (0.04 + 0.05 * i), h * 0.06), h * 0.022, 1.0, Color("#F0645C"), false)
	# growth bar
	var need: int = _GROW[mini(_stage + 1, 3)]
	var have: int = _eaten - int(_GROW[_stage])
	var frac := 1.0 if _stage == 3 else clampf(float(have) / float(maxi(1, need - int(_GROW[_stage]))), 0.0, 1.0)
	draw_rect(Rect2(w * 0.7, h * 0.04, w * 0.26, h * 0.035), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(w * 0.7, h * 0.04, w * 0.26 * frac, h * 0.035), Color("#F2C14E") if _stage == 3 else Color("#7ED38B"))


func _draw_fish(c: Vector2, r: float, dir: float, col: Color, player: bool) -> void:
	var body := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		body.append(c + Vector2(cos(a) * r * 1.35, sin(a) * r * 0.85))
	draw_colored_polygon(body, col)
	var tail := PackedVector2Array([c + Vector2(-dir * r * 1.1, 0), c + Vector2(-dir * r * 2.0, -r * 0.8), c + Vector2(-dir * r * 2.0, r * 0.8)])
	draw_colored_polygon(tail, col.darkened(0.15))
	draw_circle(c + Vector2(dir * r * 0.15, r * 0.3), r * 0.55, col.lightened(0.35))  # belly
	draw_circle(c + Vector2(dir * r * 0.65, -r * 0.2), r * 0.24, Color.WHITE)
	draw_circle(c + Vector2(dir * r * 0.72, -r * 0.2), r * 0.12, Color("#14243A"))
	if player:  # coral beanie: it's a penguin-fish, after all
		draw_circle(c + Vector2(0, -r * 0.75), r * 0.42, Color("#E86D58"))
		draw_circle(c + Vector2(0, -r * 1.18), r * 0.16, Color.WHITE)


func _jelly(c: Vector2, r: float) -> void:
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(c + Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(dome, Color(0.96, 0.55, 0.85, 0.85))
	for k in 4:
		var x := c.x - r * 0.6 + r * 0.4 * k
		draw_line(Vector2(x, c.y), Vector2(x + sin(_time * 4.0 + k) * r * 0.3, c.y + r * 1.4), Color(0.96, 0.55, 0.85, 0.7), 2.0)
