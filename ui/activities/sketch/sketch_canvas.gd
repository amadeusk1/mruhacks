class_name SketchCanvas
extends Control
## Drawing surface for the drawing telephone. Strokes are stored normalized (0..1 of the canvas)
## as {c: Color html, w: width px at 1000 px wide, p: PackedVector2Array}, per brief §15.5, so they
## travel over the network and redraw at any size. Limits keep payloads bounded.

signal changed

const MAX_STROKES := 400
const MAX_POINTS := 6000

var strokes: Array = []
var color := Color("#1E2E55")
var width := 8.0
var eraser := false
var editable := true
var _cur: Dictionary = {}
var _points := 0


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and strokes.size() < MAX_STROKES:
			_cur = {"c": ("#FFFFFF" if eraser else color.to_html(false)), "w": width * (2.5 if eraser else 1.0) * 1000.0 / maxf(size.x, 1.0), "p": PackedVector2Array()}
			strokes.append(_cur)
			_add(event.position)
		else:
			_cur = {}
			changed.emit()
		accept_event()
	elif event is InputEventMouseMotion and not _cur.is_empty():
		_add(event.position)
		accept_event()


func _add(pos: Vector2) -> void:
	if _points >= MAX_POINTS:
		return
	var n := (pos / size).clamp(Vector2.ZERO, Vector2.ONE)
	var p: PackedVector2Array = _cur["p"]
	if p.size() > 0 and p[p.size() - 1].distance_to(n) < 0.002:
		return
	p.append(n)
	_cur["p"] = p
	_points += 1
	queue_redraw()


func undo() -> void:
	if not strokes.is_empty():
		_points -= (strokes.pop_back()["p"] as PackedVector2Array).size()
		queue_redraw()
		changed.emit()


func clear() -> void:
	strokes.clear()
	_points = 0
	queue_redraw()
	changed.emit()


func set_strokes(data: Array) -> void:
	strokes = data.duplicate(true)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	for s in strokes:
		var p: PackedVector2Array = s["p"]
		var col := Color(str(s["c"]))
		var w := float(s["w"]) * size.x / 1000.0
		if p.size() == 1:
			draw_circle(p[0] * size, w * 0.5, col)
			continue
		var pts := PackedVector2Array()
		for q in p:
			pts.append(q * size)
		draw_polyline(pts, col, w, true)
		for q in [pts[0], pts[pts.size() - 1]]:
			draw_circle(q, w * 0.5, col)


## Demo drawing for previews: a penguin on a crescent moon.
func demo() -> void:
	strokes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:   # scribbled night sky
		var y := 0.12 + i * 0.03
		var sky := PackedVector2Array()
		for k in 9:
			sky.append(Vector2(0.18 + k * 0.08 + rng.randf_range(-0.02, 0.02), y + rng.randf_range(-0.02, 0.02)))
		strokes.append({"c": "#1E2E6B", "w": 30.0, "p": sky})
	var moon := PackedVector2Array()
	for i in 40:
		var a := lerpf(1.9, 5.3, i / 39.0)
		moon.append(Vector2(0.42, 0.55) + Vector2(cos(a), sin(a)) * Vector2(0.24, 0.36))
	strokes.append({"c": "#F2C230", "w": 34.0, "p": moon})
	var body := PackedVector2Array()
	for i in 30:
		var a := TAU * i / 29.0
		body.append(Vector2(0.52, 0.5) + Vector2(cos(a) * 0.09, sin(a) * 0.15))
	strokes.append({"c": "#2F5FB3", "w": 26.0, "p": body})
	strokes.append({"c": "#FFFFFF", "w": 22.0, "p": PackedVector2Array([Vector2(0.52, 0.47), Vector2(0.52, 0.58)])})
	strokes.append({"c": "#F08A2E", "w": 12.0, "p": PackedVector2Array([Vector2(0.55, 0.42), Vector2(0.59, 0.43)])})
	for st in [Vector2(0.72, 0.24), Vector2(0.78, 0.6), Vector2(0.3, 0.2), Vector2(0.66, 0.76)]:
		strokes.append({"c": "#F2C230", "w": 26.0, "p": PackedVector2Array([st])})
	for e in [Vector2(0.505, 0.43), Vector2(0.545, 0.43)]:
		strokes.append({"c": "#1A1A1F", "w": 9.0, "p": PackedVector2Array([e])})
	for f in [Vector2(0.49, 0.66), Vector2(0.55, 0.66)]:
		strokes.append({"c": "#F08A2E", "w": 16.0, "p": PackedVector2Array([f, f + Vector2(0.02, 0)])})
	queue_redraw()
