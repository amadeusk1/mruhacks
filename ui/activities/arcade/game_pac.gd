extends Control

## Original maze chase. Arrows or WASD. Eat the dots, then the ghosts while they are blue.

var score := 0
var over := false
var won := false

const _MAZE := [
	"###############",
	"#o....#...#..o#",
	"#.###.#.#.#.###",
	"#.............#",
	"#.#.###.###.#.#",
	"#.#.........#.#",
	"#.#.#######.#.#",
	"#.............#",
	"###.#.###.#.###",
	"#...#.#.#.#...#",
	"#.###.#.#.###.#",
	"#o...........o#",
	"###############",
]
const _STEP := 0.15

var _pellets := {}
var _px := 7
var _py := 7
var _dir := Vector2i.ZERO
var _next := Vector2i.ZERO
var _held: Array[Vector2i] = []
var _wait := 0.0
var _ghosts: Array = []
var _power := 0.0
var _lives := 3
var _home := [Vector2i(7, 5), Vector2i(7, 9)]


func _ready() -> void:
	reset()


func reset() -> void:
	score = 0
	over = false
	won = false
	_lives = 3
	_power = 0.0
	_dir = Vector2i.ZERO
	_next = Vector2i.ZERO
	_held.clear()
	_wait = 0.0
	_fill()
	queue_redraw()


func _fill() -> void:
	_pellets.clear()
	_px = 7
	_py = 7
	for y in _MAZE.size():
		var row: String = _MAZE[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == "o":
				_pellets[Vector2i(x, y)] = 2 if ch == "o" else 1
	_pellets.erase(Vector2i(_px, _py))
	_ghosts.clear()
	for home in _home:
		_ghosts.append({"at": home, "dir": Vector2i.RIGHT, "eyes": false})


func _process(delta: float) -> void:
	if over:
		return
	_power = maxf(_power - delta, 0.0)
	_read_dir()
	_wait += delta
	if _wait < _STEP:
		queue_redraw()
		return
	_wait = 0.0
	_step_player()
	_step_ghosts()
	_touch()
	if _pellets.is_empty():
		won = true
		over = true
	queue_redraw()


func _read_dir() -> void:
	# Latest key wins. A key still held from the previous corridor used to
	# outrank the new turn, so he kept going straight or reversed late.
	for entry in [
		["move_left", Vector2i.LEFT],
		["move_right", Vector2i.RIGHT],
		["move_forward", Vector2i.UP],
		["move_back", Vector2i.DOWN],
	]:
		var d: Vector2i = entry[1]
		if Input.is_action_just_pressed(entry[0]):
			_held.erase(d)
			_held.append(d)
		elif not Input.is_action_pressed(entry[0]):
			_held.erase(d)
	_next = _held.back() if not _held.is_empty() else _dir


func _step_player() -> void:
	if _open(_px + _next.x, _py + _next.y):
		_dir = _next
	if not _open(_px + _dir.x, _py + _dir.y):
		return
	_px += _dir.x
	_py += _dir.y
	var here := Vector2i(_px, _py)
	if not _pellets.has(here):
		return
	if int(_pellets[here]) == 2:
		score += 50
		_power = 6.0
		for ghost in _ghosts:
			ghost["eyes"] = false
	else:
		score += 10
	_pellets.erase(here)


func _step_ghosts() -> void:
	for ghost in _ghosts:
		var at: Vector2i = ghost["at"]
		var options: Array[Vector2i] = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if d == -ghost["dir"]:
				continue
			if _open(at.x + d.x, at.y + d.y):
				options.append(d)
		if options.is_empty():
			options.append(-ghost["dir"])
		var best: Vector2i = options[0]
		var best_score := -99999
		for d in options:
			var nxt := at + d
			var toward := (_px - nxt.x) * (_px - nxt.x) + (_py - nxt.y) * (_py - nxt.y)
			var rank := -toward if _power <= 0.0 else toward
			rank += randi() % 3
			if rank > best_score:
				best_score = rank
				best = d
		ghost["dir"] = best
		var dest := at + best
		if _open(dest.x, dest.y):
			ghost["at"] = dest
		if bool(ghost["eyes"]) and ghost["at"] == _home[0]:
			ghost["eyes"] = false


func _touch() -> void:
	for ghost in _ghosts:
		if ghost["at"] != Vector2i(_px, _py):
			continue
		if _power > 0.0 and not bool(ghost["eyes"]):
			score += 200
			ghost["eyes"] = true
			ghost["at"] = _home[0]
			continue
		if bool(ghost["eyes"]):
			continue
		_lives -= 1
		_px = 7
		_py = 7
		_dir = Vector2i.ZERO
		_next = Vector2i.ZERO
		_held.clear()
		if _lives <= 0:
			over = true
		return


func _open(x: int, y: int) -> bool:
	if y < 0 or y >= _MAZE.size():
		return false
	var row: String = _MAZE[y]
	if x < 0 or x >= row.length():
		return false
	return row[x] != "#"


func _draw() -> void:
	var cols := _MAZE[0].length()
	var rows := _MAZE.size()
	var cell := minf(size.x / float(cols), size.y / float(rows))
	var origin := (size - Vector2(cols, rows) * cell) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.16))
	for y in rows:
		var row: String = _MAZE[y]
		for x in row.length():
			var at := origin + Vector2(x, y) * cell
			if row[x] == "#":
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(cell, cell) - Vector2(2, 2)), Color(0.16, 0.35, 0.82), true)
	for key in _pellets:
		var cell_at: Vector2i = key
		var mid := origin + (Vector2(cell_at) + Vector2(0.5, 0.5)) * cell
		var power_dot := int(_pellets[key]) == 2
		draw_circle(mid, cell * (0.22 if power_dot else 0.08), Color(1.0, 0.86, 0.55))
	var mouth := 0.35 if _dir != Vector2i.ZERO else 0.15
	var ang := atan2(float(_dir.y), float(_dir.x))
	var pc := origin + (Vector2(_px, _py) + Vector2(0.5, 0.5)) * cell
	draw_circle(pc, cell * 0.38, Color(1.0, 0.86, 0.2))
	if _dir != Vector2i.ZERO:
		draw_colored_polygon(PackedVector2Array([
			pc,
			pc + Vector2(cos(ang - mouth), sin(ang - mouth)) * cell * 0.4,
			pc + Vector2(cos(ang + mouth), sin(ang + mouth)) * cell * 0.4,
		]), Color(0.05, 0.07, 0.16))
	var colors: Array[Color] = [Color(1.0, 0.35, 0.4), Color(1.0, 0.55, 0.75)]
	for i in _ghosts.size():
		var ghost: Dictionary = _ghosts[i]
		var g: Vector2i = ghost["at"]
		var gc := origin + (Vector2(g) + Vector2(0.5, 0.5)) * cell
		var col: Color = colors[i % colors.size()]
		if _power > 0.0 and not bool(ghost["eyes"]):
			col = Color(0.45, 0.7, 1.0)
		if bool(ghost["eyes"]):
			col = Color(0.85, 0.9, 0.95)
		draw_circle(gc + Vector2(0, -cell * 0.05), cell * 0.34, col)
		draw_rect(Rect2(gc + Vector2(-cell * 0.34, 0), Vector2(cell * 0.68, cell * 0.28)), col)
		draw_circle(gc + Vector2(-cell * 0.1, -cell * 0.08), cell * 0.08, Color.WHITE)
		draw_circle(gc + Vector2(cell * 0.12, -cell * 0.08), cell * 0.08, Color.WHITE)
	var life := "Lives %d" % _lives
	draw_string(ThemeDB.fallback_font, Vector2(12, 22), life, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.94, 1))
