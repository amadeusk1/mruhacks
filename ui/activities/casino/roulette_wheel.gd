extends Control
## Drawn single-zero wheel for the roulette screen, so the spin is always on screen even when the
## 3D table wheel sits behind a panel. Pockets run in real wheel order; the gold pointer at the top
## marks the pocket. The host draws the pocket; this only shows it.
##   spin_to(pocket, seconds)  spins the wheel down onto `pocket` with the ball dropping in
##   rest_on(pocket)           shows it still on `pocket` (-1: no result yet)

signal landed(pocket: int)

const R := preload("res://scripts/casino/casino_rules.gd")
const ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1,
	20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const SLOT := TAU / 37.0
const TOP := -PI * 0.5
const RED := Color("#D6453C")
const BLACK := Color("#232733")
const GREEN := Color("#2E9E5E")
const GOLD := Color("#F2C230")
const WOOD := Color("#7A4A2A")

var angle := 0.0        # wheel turn; ORDER[i] is under the pointer when angle == -i * SLOT
var ball := TOP         # ball's screen angle
var pocket := -1
var spinning := false
var _from := 0.0
var _to := 0.0
var _ball_from := 0.0
var _t := 0.0
var _len := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func spin_to(p: int, seconds: float) -> void:
	pocket = p
	var target := -ORDER.find(p) * SLOT
	_from = angle
	_to = target - TAU * (ceil((angle - target) / TAU) + 4.0)  # at least four full turns
	_ball_from = ball + TAU * 6.0                                 # ball runs the other way
	_len = maxf(0.6, seconds)
	_t = 0.0
	spinning = true
	queue_redraw()


func rest_on(p: int) -> void:
	if spinning:
		return
	pocket = p
	if p >= 0:
		angle = -ORDER.find(p) * SLOT
	ball = TOP
	queue_redraw()


func _process(delta: float) -> void:
	if not spinning:
		return
	_t += delta
	var k := clampf(_t / _len, 0.0, 1.0)
	angle = lerpf(_from, _to, 1.0 - pow(1.0 - k, 3.0))
	ball = lerpf(_ball_from, TOP, 1.0 - pow(1.0 - k, 2.2))
	queue_redraw()
	if k >= 1.0:
		spinning = false
		angle = _to
		ball = TOP
		landed.emit(pocket)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var k := clampf(_t / _len, 0.0, 1.0) if spinning else 1.0
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.25))
	draw_circle(c, r, WOOD)
	draw_circle(c, r * 0.92, Color("#3B2416"))          # ball track
	var outer := r * 0.82
	var inner := r * 0.56
	for i in 37:
		var a0 := angle + (i - 0.5) * SLOT + TOP
		var a1 := a0 + SLOT
		var pts := PackedVector2Array()
		for s in 4:
			var a := lerpf(a0, a1, s / 3.0)
			pts.append(c + Vector2(cos(a), sin(a)) * outer)
		for s in 4:
			var a := lerpf(a1, a0, s / 3.0)
			pts.append(c + Vector2(cos(a), sin(a)) * inner)
		var n: int = ORDER[i]
		draw_colored_polygon(pts, {"red": RED, "black": BLACK, "green": GREEN}[R.roulette_color(n)])
		draw_line(c + Vector2(cos(a0), sin(a0)) * inner, c + Vector2(cos(a0), sin(a0)) * outer, Color(1, 1, 1, 0.35), 1.0, true)
		_number(c, (outer + inner) * 0.5, angle + i * SLOT + TOP, str(n), r)
	draw_arc(c, outer, 0, TAU, 64, GOLD.darkened(0.2), 2.0, true)
	draw_circle(c, inner, Color("#8C5A34"))
	draw_circle(c, inner * 0.62, Color("#B07A48"))
	if pocket >= 0 and not spinning:     # result in the hub, lit pocket under the pointer
		draw_circle(c, inner * 0.6, {"red": RED, "black": BLACK, "green": GREEN}[R.roulette_color(pocket)])
		draw_arc(c, inner * 0.6, 0, TAU, 40, GOLD, 3.0, true)
		var f := get_theme_default_font()
		var fs := int(r * 0.3)
		var t := str(pocket)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var a0 := TOP - SLOT * 0.5
		draw_arc(c, outer, a0, a0 + SLOT, 8, GOLD, 4.0, true)
		draw_arc(c, inner, a0, a0 + SLOT, 8, GOLD, 4.0, true)
	else:
		for s in 4:                       # hub spokes turning with the wheel
			var a := angle + s * PI * 0.5
			draw_line(c, c + Vector2(cos(a), sin(a)) * inner * 0.55, GOLD.darkened(0.1), 4.0, true)
		draw_circle(c, inner * 0.14, GOLD)
	# ball: rides the outer track, then drops into the pocket ring
	var br := lerpf(r * 0.87, (outer + inner) * 0.5 + r * 0.06, smoothstep(0.6, 0.9, k))
	var bounce := sin(_t * 28.0) * r * 0.02 if spinning and k > 0.6 and k < 0.9 else 0.0
	var bp := c + Vector2(cos(ball), sin(ball)) * (br + bounce)
	draw_circle(bp + Vector2(1, 2), r * 0.055, Color(0, 0, 0, 0.3))
	draw_circle(bp, r * 0.055, Color("#FDFBF6"))
	# pointer
	var tip := c + Vector2(0, -outer + r * 0.02)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-r * 0.09, -r * 0.2), tip + Vector2(r * 0.09, -r * 0.2)]), GOLD)
	draw_polyline(PackedVector2Array([tip, tip + Vector2(-r * 0.09, -r * 0.2), tip + Vector2(r * 0.09, -r * 0.2), tip]), Color("#8A6A10"), 2.0, true)


func _number(c: Vector2, at: float, a: float, t: String, r: float) -> void:
	var f := get_theme_default_font()
	var fs := maxi(8, int(r * 0.085))
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(c + Vector2(cos(a), sin(a)) * at, a + PI * 0.5)
	draw_string(f, Vector2(-w * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
