class_name PuckBoard
extends Control
## Puck Rally board (brief §10.2): two paddles, one puck, first to `target`. Drawn in 2D so it
## reads at any size (the close cabinet overlay). Local authority for solo vs AI; for two players
## feed `set_remote_paddle()` from the network and let the host own `_step()`.

signal scored(left: int, right: int)
signal finished(left: int, right: int)

const ICE := Color("#CFEAF7")
const ICE_LINE := Color("#9CCBE6")
const RIM := Color("#3B6FB3")
const LEFT_C := Color("#F0645C")
const RIGHT_C := Color("#28B5B0")
const PUCK_C := Color("#173B6B")

var target := 5
var ai_right := true           ## solo: computer plays the right paddle
var running := false
var score := Vector2i.ZERO
var _lp := 0.5                 ## paddle centres, 0..1 of board height
var _rp := 0.5
var _remote_rp := -1.0
var _puck := Vector2(0.5, 0.5)  ## 0..1 board coords
var _vel := Vector2(0.42, 0.18)
const PAD_H := 0.26
const PAD_X := 0.07


func start() -> void:
	score = Vector2i.ZERO
	_serve(1)
	running = true


func set_remote_paddle(y01: float) -> void:
	_remote_rp = clampf(y01, 0.0, 1.0)


func _serve(dir: int) -> void:
	_puck = Vector2(0.5, 0.5)
	_vel = Vector2(0.42 * dir, randf_range(-0.22, 0.22))


func _process(delta: float) -> void:
	if not running:
		queue_redraw()
		return
	var axis := Input.get_axis("move_forward", "move_back") if InputMap.has_action("move_forward") else 0.0
	_lp = clampf(_lp + axis * 0.9 * delta, PAD_H * 0.5, 1.0 - PAD_H * 0.5)
	if ai_right:
		_rp = move_toward(_rp, _puck.y, 0.55 * delta)   # beatable: capped speed
	elif _remote_rp >= 0.0:
		_rp = _remote_rp
	_rp = clampf(_rp, PAD_H * 0.5, 1.0 - PAD_H * 0.5)
	_step(delta)
	queue_redraw()


func _step(delta: float) -> void:
	_puck += _vel * delta
	if _puck.y < 0.05 or _puck.y > 0.95:
		_vel.y = -_vel.y
		_puck.y = clampf(_puck.y, 0.05, 0.95)
	if _puck.x < PAD_X + 0.03 and _vel.x < 0 and absf(_puck.y - _lp) < PAD_H * 0.55:
		_vel = Vector2(-_vel.x * 1.06, _vel.y + (_puck.y - _lp) * 1.4)
	if _puck.x > 1.0 - PAD_X - 0.03 and _vel.x > 0 and absf(_puck.y - _rp) < PAD_H * 0.55:
		_vel = Vector2(-_vel.x * 1.06, _vel.y + (_puck.y - _rp) * 1.4)
	_vel = _vel.limit_length(1.4)
	if _puck.x < -0.02:
		score.y += 1
		_after_goal(1)
	elif _puck.x > 1.02:
		score.x += 1
		_after_goal(-1)


func _after_goal(dir: int) -> void:
	scored.emit(score.x, score.y)
	if score.x >= target or score.y >= target:
		running = false
		finished.emit(score.x, score.y)
	else:
		_serve(dir)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(RIM, 26), r)
	var ice := r.grow(-14)
	draw_style_box(_box(ICE, 18), ice)
	var mid := ice.position.x + ice.size.x * 0.5
	for i in 12:   # dashed centre line
		var y0 := ice.position.y + ice.size.y * (i + 0.2) / 12.0
		draw_line(Vector2(mid, y0), Vector2(mid, y0 + ice.size.y * 0.045), ICE_LINE, 4)
	draw_arc(ice.get_center(), ice.size.y * 0.24, 0, TAU, 48, ICE_LINE, 4, true)
	var ph := ice.size.y * PAD_H
	var pw := ice.size.x * 0.045
	_paddle(Vector2(ice.position.x + ice.size.x * PAD_X, ice.position.y + ice.size.y * _lp), pw, ph, LEFT_C)
	_paddle(Vector2(ice.position.x + ice.size.x * (1.0 - PAD_X), ice.position.y + ice.size.y * _rp), pw, ph, RIGHT_C)
	var pp := ice.position + Vector2(ice.size.x * _puck.x, ice.size.y * _puck.y)
	draw_circle(pp + Vector2(0, 3), ice.size.y * 0.055, Color(0, 0, 0, 0.15))
	draw_circle(pp, ice.size.y * 0.055, PUCK_C)


func _paddle(c: Vector2, w: float, h: float, col: Color) -> void:
	var rect := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_style_box(_box(col.darkened(0.25), int(w * 0.5)), rect.grow(3))
	draw_style_box(_box(col, int(w * 0.5)), rect)


static func _box(c: Color, r: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.anti_aliasing = true
	return s


func preview_pose(l: float, r: float, puck: Vector2, sc: Vector2i) -> void:
	_lp = l; _rp = r; _puck = puck; score = sc
	queue_redraw()
