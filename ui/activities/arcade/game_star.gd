extends Control

## Star Patrol: a penguin rocket at the bottom of the screen. A/D or arrows move, Space or W
## fires. Snow-bat waves sway in formation and dive; their snowballs cost a life. Golden fish
## drops give a double shot. Every cleared wave comes back faster.

var score := 0
var over := false
var won := false

var _x := 0.5
var _lives := 3
var _wave := 0
var _shots: Array = []      ## Vector2
var _bombs: Array = []      ## Vector2
var _foes: Array = []       ## {home, p, dive, t, hp}
var _drops: Array = []      ## Vector2
var _sparks: Array = []     ## {p, v, t, c}
var _stars: Array = []
var _cool := 0.0
var _double := 0.0
var _safe := 0.0
var _time := 0.0
var _sway := 0.0
var _next_wave := 0.0


func _ready() -> void:
	for i in 60:
		_stars.append(Vector3(randf(), randf(), randf_range(0.05, 0.25)))
	reset()


func reset() -> void:
	score = 0
	over = false
	won = false
	_x = 0.5
	_lives = 3
	_wave = 0
	_shots.clear()
	_bombs.clear()
	_foes.clear()
	_drops.clear()
	_sparks.clear()
	_double = 0.0
	_safe = 1.0
	_next_wave = 0.8
	queue_redraw()


func _process(delta: float) -> void:
	if size.x < 2.0:
		return
	_time += delta
	for i in _stars.size():
		var s: Vector3 = _stars[i]
		s.y = fposmod(s.y + s.z * delta, 1.0)
		_stars[i] = s
	for sp in _sparks:
		sp["p"] += sp["v"] * delta
		sp["t"] = float(sp["t"]) - delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return float(sp["t"]) > 0.0)
	if over:
		queue_redraw()
		return
	_cool -= delta
	_safe = maxf(0.0, _safe - delta)
	_double = maxf(0.0, _double - delta)
	_x = clampf(_x + Input.get_axis("move_left", "move_right") * 0.75 * delta, 0.05, 0.95)
	if (Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("move_forward")) and _cool <= 0.0:
		_cool = 0.26
		if _double > 0.0:
			_shots.append(Vector2(_x - 0.018, 0.86))
			_shots.append(Vector2(_x + 0.018, 0.86))
		else:
			_shots.append(Vector2(_x, 0.86))
	if _foes.is_empty():
		_next_wave -= delta
		if _next_wave <= 0.0:
			_spawn_wave()
	_sway += delta * (0.8 + _wave * 0.08)
	var kept: Array = []
	for s in _shots:
		s.y -= 1.3 * delta
		if s.y > -0.05:
			kept.append(s)
	_shots = kept
	for f in _foes:
		f["t"] = float(f["t"]) + delta
		var home: Vector2 = f["home"] + Vector2(sin(_sway) * 0.08, 0.0)
		if bool(f["dive"]):
			f["p"] += Vector2(sin(float(f["t"]) * 3.0) * 0.3, 0.32 + _wave * 0.02) * delta
			if f["p"].y > 1.05:
				f["p"] = Vector2(home.x, -0.05)
				f["dive"] = false
		else:
			f["p"] = f["p"].lerp(home, 1.0 - exp(-4.0 * delta))
			if randf() < delta * (0.04 + _wave * 0.012):
				f["dive"] = true
				f["t"] = 0.0
		if randf() < delta * (0.18 + _wave * 0.04):
			_bombs.append(f["p"] + Vector2(0, 0.03))
	# hits on foes
	var survivors: Array = []
	for f in _foes:
		var dead := false
		for s in _shots:
			if (s as Vector2).distance_to(f["p"]) < 0.04:
				_shots.erase(s)
				f["hp"] = int(f["hp"]) - 1
				if int(f["hp"]) <= 0:
					dead = true
				break
		if dead:
			score += 50 if bool(f["dive"]) else 25
			_burst(f["p"], Color("#B48CF0"))
			if randf() < 0.08:
				_drops.append(f["p"])
		else:
			survivors.append(f)
	_foes = survivors
	if _foes.is_empty() and _next_wave <= 0.0:
		_next_wave = 1.4
		score += 100 * _wave
	var aspect := size.x / size.y
	var me := Vector2(_x, 0.9)
	var bombs: Array = []
	for b in _bombs:
		b.y += (0.42 + _wave * 0.02) * delta
		if b.y > 1.05:
			continue
		if _safe <= 0.0 and Vector2((b.x - me.x) * aspect, b.y - me.y).length() < 0.035:
			_hit()
			continue
		bombs.append(b)
	_bombs = bombs
	for f in _foes:
		if _safe <= 0.0 and Vector2((f["p"].x - me.x) * aspect, f["p"].y - me.y).length() < 0.05:
			_hit()
	var drops: Array = []
	for d in _drops:
		d.y += 0.3 * delta
		if Vector2((d.x - me.x) * aspect, d.y - me.y).length() < 0.05:
			_double = 8.0
			score += 75
			continue
		if d.y < 1.05:
			drops.append(d)
	_drops = drops
	queue_redraw()


func _spawn_wave() -> void:
	_wave += 1
	var rows := mini(2 + _wave / 2, 5)
	for r in rows:
		for c in 8:
			var home := Vector2(0.15 + c * 0.1, 0.1 + r * 0.075)
			_foes.append({"home": home, "p": Vector2(home.x, -0.1 - r * 0.05), "dive": false, "t": 0.0,
				"hp": 2 if r == 0 and _wave > 2 else 1})


func _hit() -> void:
	_lives -= 1
	_safe = 1.8
	_bombs.clear()
	_burst(Vector2(_x, 0.9), Color("#F0645C"))
	if _lives <= 0:
		over = true


func _burst(at: Vector2, c: Color) -> void:
	for i in 12:
		var a := randf() * TAU
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(0.1, 0.35), "t": randf_range(0.3, 0.6), "c": c})


func _draw() -> void:
	if size.x < 2.0:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0A1230"))
	for s in _stars:
		draw_rect(Rect2(s.x * w, s.y * h, 2.0 + s.z * 6.0, 2.0 + s.z * 6.0), Color(1, 1, 1, 0.35 + s.z * 2.0))
	for s in _shots:
		draw_rect(Rect2(s.x * w - 2, s.y * h - 8, 4, 14), Color("#FFE27A"))
	for b in _bombs:
		draw_circle(Vector2(b.x * w, b.y * h), h * 0.01, Color.WHITE)
	for d in _drops:
		_fish_icon(Vector2(d.x * w, d.y * h), h * 0.02)
	for f in _foes:
		_bat(Vector2(f["p"].x * w, f["p"].y * h), h * 0.028, int(f["hp"]) > 1)
	for sp in _sparks:
		draw_circle(Vector2(sp["p"].x * w, sp["p"].y * h), 3.0, (sp["c"] as Color) * Color(1, 1, 1, clampf(float(sp["t"]) * 3.0, 0, 1)))
	if not over and not (_safe > 0.0 and int(_time * 12.0) % 2 == 0):
		_rocket(Vector2(_x * w, 0.9 * h), h * 0.045)
	for i in _lives:
		_rocket(Vector2(w * (0.04 + 0.04 * i), h * 0.05), h * 0.018)
	var font := get_theme_default_font()
	draw_string(font, Vector2(w * 0.86, h * 0.07), "WAVE %d" % _wave, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.04), Color("#8BD3E6"))
	if _double > 0.0:
		draw_string(font, Vector2(w * 0.4, h * 0.07), "DOUBLE SHOT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.04), Color("#F2C14E"))


func _rocket(c: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.3), c + Vector2(r * 0.7, r * 0.6), c + Vector2(-r * 0.7, r * 0.6)]), Color("#E8EEF5"))
	draw_circle(c + Vector2(0, -r * 0.1), r * 0.42, Color("#14243A"))   # penguin pilot
	draw_circle(c + Vector2(0, 0), r * 0.26, Color.WHITE)
	draw_circle(c + Vector2(0, -r * 0.35), r * 0.2, Color("#E86D58"))  # beanie
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.6), c + Vector2(r * 0.3, r * 0.6),
		c + Vector2(0, r * (1.1 + sin(_time * 40.0) * 0.2))]), Color("#F2A33A"))


func _bat(c: Vector2, r: float, armored: bool) -> void:
	var flap := sin(_time * 10.0 + c.x) * r * 0.4
	var col := Color("#B48CF0") if not armored else Color("#F0645C")
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(-r * 1.6, -r * 0.4 + flap), c + Vector2(-r * 0.8, r * 0.4)]), col.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(r * 1.6, -r * 0.4 + flap), c + Vector2(r * 0.8, r * 0.4)]), col.darkened(0.2))
	draw_circle(c, r * 0.7, col)
	draw_circle(c + Vector2(-r * 0.25, -r * 0.1), r * 0.16, Color.WHITE)
	draw_circle(c + Vector2(r * 0.25, -r * 0.1), r * 0.16, Color.WHITE)


func _fish_icon(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color("#F2C14E"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(-r * 1.7, -r * 0.7), c + Vector2(-r * 1.7, r * 0.7)]), Color("#F2C14E"))
