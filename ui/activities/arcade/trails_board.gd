class_name TrailsBoard
extends Control
## Draws a Snow Trails state (TrailsGame.view()). Solo practice: owns a local TrailsGame vs the
## AI and reads WASD; online: apply_view() from the server and send turns with the `turned` signal.

signal turned(dir: int)
signal finished(a: int, b: int)

const A_COL := Color("#F0645C")
const B_COL := Color("#28B5B0")

var local: TrailsGame          ## solo practice only
var _view: Dictionary = {}
var _last_dir := -1
var _flash := 0.0


func start_local() -> void:
	local = TrailsGame.new()
	local.ai_b = true
	local.start()
	_view = local.view()


func apply_view(v: Dictionary) -> void:
	if float(v.get("wait", 0.0)) > 0.0 and float(_view.get("wait", 0.0)) <= 0.0:
		_flash = 0.35
		Sfx.play(self, "explode", -6.0)
	_view = v
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var d := _read_dir()
	if d >= 0 and d != _last_dir:
		_last_dir = d
		if local:
			local.set_dir(0, d)
		else:
			turned.emit(d)
	if local:
		var was_running := local.running
		local.step(delta)
		apply_view(local.view())
		if was_running and local.done:
			finished.emit(local.sa, local.sb)
	queue_redraw()


func _read_dir() -> int:
	if Input.is_action_pressed("move_forward"):
		return 0
	if Input.is_action_pressed("move_right"):
		return 1
	if Input.is_action_pressed("move_back"):
		return 2
	if Input.is_action_pressed("move_left"):
		return 3
	return -1


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("#3B6FB3"))
	var cell := minf((size.x - 20.0) / TrailsGame.W, (size.y - 20.0) / TrailsGame.H)
	var origin := (size - Vector2(TrailsGame.W, TrailsGame.H) * cell) * 0.5
	var field := Rect2(origin, Vector2(TrailsGame.W, TrailsGame.H) * cell)
	draw_rect(field, Color("#DDF0FA"))
	for x in range(0, TrailsGame.W + 1, 4):
		draw_line(origin + Vector2(x * cell, 0), origin + Vector2(x * cell, field.size.y), Color("#C3E2F2"), 1.0)
	for y in range(0, TrailsGame.H + 1, 4):
		draw_line(origin + Vector2(0, y * cell), origin + Vector2(field.size.x, y * cell), Color("#C3E2F2"), 1.0)
	_trail(_view.get("a", PackedInt32Array()), origin, cell, A_COL)
	_trail(_view.get("b", PackedInt32Array()), origin, cell, B_COL)
	var crash: Array = _view.get("crash", [-1, -1])
	if float(_view.get("wait", 0.0)) > 0.0 and int(crash[0]) >= 0:
		var c := origin + (Vector2(int(crash[0]), int(crash[1])) + Vector2(0.5, 0.5)) * cell
		for k in 8:
			var a := TAU * k / 8.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * cell * (2.0 + 2.0 * float(_view["wait"])), Color("#FFE27A"), 3.0)
	if _flash > 0.0:
		draw_rect(r, Color(1, 1, 1, _flash))


func _trail(flat: PackedInt32Array, origin: Vector2, cell: float, col: Color) -> void:
	if flat.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(origin + (Vector2(flat[i], flat[i + 1]) + Vector2(0.5, 0.5)) * cell)
	if pts.size() >= 2:
		draw_polyline(pts, col.darkened(0.25), cell * 0.95, false)
		draw_polyline(pts, col, cell * 0.6, false)
	var head := pts[pts.size() - 1]
	draw_circle(head, cell * 0.9, col.darkened(0.3))
	draw_circle(head, cell * 0.6, Color.WHITE)
	draw_circle(head, cell * 0.35, col)
