extends Control

## Falling blocks. Arrows or A/D move, W rotates, S drops a step, Space slams down.

var score := 0
var over := false
var won := false

const _W := 10
const _H := 20
const _COLORS := [
	Color(0.35, 0.85, 0.95),
	Color(0.95, 0.82, 0.28),
	Color(0.72, 0.45, 0.9),
	Color(0.35, 0.55, 0.95),
	Color(0.95, 0.55, 0.25),
	Color(0.4, 0.85, 0.45),
	Color(0.95, 0.38, 0.4),
]
const _SHAPES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
]

var _grid: Array = []
var _cells: Array = []
var _kind := 0
var _x := 3
var _y := 0
var _fall := 0.0
var _lock := 0.0
var _lines := 0
var _bag: Array = []
var _repeat := 0.0
var _repeat_dir := 0


func _ready() -> void:
	reset()


func reset() -> void:
	score = 0
	over = false
	won = false
	_lines = 0
	_fall = 0.0
	_lock = 0.0
	_bag.clear()
	_grid.clear()
	for _y in _H:
		var row: Array = []
		row.resize(_W)
		row.fill(-1)
		_grid.append(row)
	_spawn()
	queue_redraw()


func _process(delta: float) -> void:
	if over:
		return
	# Held keys and the touch stick both need to repeat. A single just-pressed
	# would move the piece once and then freeze until the stick returned to center.
	var dir := 0
	if Input.is_action_pressed("move_left"):
		dir -= 1
	if Input.is_action_pressed("move_right"):
		dir += 1
	if dir == 0 or absi(dir) == 2:
		_repeat = 0.0
		_repeat_dir = 0
	elif dir != _repeat_dir:
		_repeat_dir = dir
		_repeat = -0.18
		_try(Vector2i.LEFT if dir < 0 else Vector2i.RIGHT, _cells)
	else:
		_repeat += delta
		if _repeat >= 0.13:
			_repeat = 0.0
			_try(Vector2i.LEFT if dir < 0 else Vector2i.RIGHT, _cells)
	if Input.is_action_just_pressed("move_forward") and _kind != 1:
		var spun := _spin(_cells)
		if not _try(Vector2i.ZERO, spun):
			if not _try(Vector2i.LEFT, spun):
				_try(Vector2i.RIGHT, spun)
	var drop := Input.is_action_pressed("move_back")
	if (Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)) and not _was_space:
		_was_space = true
		_slam()
		queue_redraw()
		return
	_was_space = Input.is_action_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)
	_fall += delta
	var every := maxf(0.12, 0.72 - float(_lines) * 0.04)
	if drop:
		every = 0.05
	if _fall < every:
		queue_redraw()
		return
	_fall = 0.0
	if _fits(_cells, _x, _y + 1):
		_y += 1
		_lock = 0.0
		if drop:
			score += 1
	else:
		_lock += every
		if _lock >= 0.35:
			_lock_piece()
	queue_redraw()


var _was_space := false


func _try(step: Vector2i, cells: Array) -> bool:
	if not _fits(cells, _x + step.x, _y + step.y):
		return false
	_cells = cells
	_x += step.x
	_y += step.y
	return true


func _slam() -> void:
	while _fits(_cells, _x, _y + 1):
		_y += 1
		score += 2
	_lock_piece()


func _lock_piece() -> void:
	for c in _cells:
		var gx := _x + int(c.x)
		var gy := _y + int(c.y)
		if gy < 0 or gy >= _H or gx < 0 or gx >= _W:
			over = true
			return
		_grid[gy][gx] = _kind
	var cleared := 0
	var y := _H - 1
	while y >= 0:
		var full := true
		for x in _W:
			if int(_grid[y][x]) < 0:
				full = false
				break
		if full:
			_grid.remove_at(y)
			var blank: Array = []
			blank.resize(_W)
			blank.fill(-1)
			_grid.insert(0, blank)
			cleared += 1
		else:
			y -= 1
	if cleared > 0:
		score += [0, 100, 300, 500, 800][mini(cleared, 4)]
		_lines += cleared
	_spawn()


func _spawn() -> void:
	if _bag.is_empty():
		_bag = [0, 1, 2, 3, 4, 5, 6]
		_bag.shuffle()
	_kind = int(_bag.pop_back())
	_cells = _SHAPES[_kind].duplicate()
	_x = 3
	_y = 0
	_lock = 0.0
	if not _fits(_cells, _x, _y):
		over = true


func _spin(cells: Array) -> Array:
	var pivot: Vector2i = cells[1]
	var spun: Array = []
	for c in cells:
		var d: Vector2i = c - pivot
		spun.append(pivot + Vector2i(d.y, -d.x))
	return spun


func _fits(cells: Array, ox: int, oy: int) -> bool:
	for c in cells:
		var x := ox + int(c.x)
		var y := oy + int(c.y)
		if x < 0 or x >= _W or y >= _H:
			return false
		if y >= 0 and int(_grid[y][x]) >= 0:
			return false
	return true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.16))
	var cell := minf(size.x / float(_W + 2), size.y / float(_H + 1))
	var origin := Vector2((size.x - cell * _W) * 0.5, (size.y - cell * _H) * 0.5)
	draw_rect(Rect2(origin - Vector2(4, 4), Vector2(cell * _W, cell * _H) + Vector2(8, 8)), Color(0.12, 0.16, 0.26))
	for y in _H:
		for x in _W:
			var id := int(_grid[y][x])
			if id >= 0:
				_block(origin + Vector2(x, y) * cell, cell, _COLORS[id])
	if not over:
		for c in _cells:
			_block(origin + Vector2(_x + int(c.x), _y + int(c.y)) * cell, cell, _COLORS[_kind])


func _block(at: Vector2, cell: float, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(cell, cell) - Vector2(2, 2)), color)
	draw_rect(Rect2(at + Vector2(3, 3), Vector2(cell * 0.45, cell * 0.2)), Color(1, 1, 1, 0.28))
