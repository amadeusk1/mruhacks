class_name TrailsGame
extends RefCounted
## Snow Trails (duo cabinet): two snowmobiles leave ice walls behind them on a grid. Turn with
## WASD; hit a wall, the edge or a trail and the other rider takes the round. First to TARGET.
## Pure rules: the server steps it for online matches, the cabinet steps it for solo practice
## (with ai_b = true). view() is the whole public state, small enough to send 20 times a second.

const W := 48
const H := 27
const TARGET := 3
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]   ## up right down left

var sa := 0
var sb := 0
var running := false
var done := false
var ai_b := false
var round_wait := 0.0
var last_crash := Vector2i(-1, -1)

var _heads: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _dir := [1, 3]
var _want := [1, 3]
var _turns: Array = [[], []]   ## corner cells per rider, the head closes each polyline
var _cells := {}               ## Vector2i -> rider (0/1)
var _acc := 0.0
var _rate := 11.0


func start() -> void:
	sa = 0
	sb = 0
	done = false
	running = true
	_new_round()


func set_dir(side: int, d: int) -> void:
	if side < 0 or side > 1 or d < 0 or d > 3:
		return
	if (d + 2) % 4 == int(_dir[side]):
		return  # no instant reverse into your own trail
	_want[side] = d


func step(delta: float) -> void:
	if not running:
		return
	if round_wait > 0.0:
		round_wait -= delta
		if round_wait <= 0.0:
			if sa >= TARGET or sb >= TARGET:
				running = false
				done = true
			else:
				_new_round()
		return
	_rate = minf(18.0, _rate + delta * 0.25)
	_acc += delta * _rate
	while _acc >= 1.0 and round_wait <= 0.0:
		_acc -= 1.0
		_tick()


func _tick() -> void:
	if ai_b:
		_ai(1)
	var next: Array[Vector2i] = []
	for side in 2:
		if int(_want[side]) != int(_dir[side]):
			_dir[side] = _want[side]
			_turns[side].append(_heads[side])
		next.append(_heads[side] + DIRS[int(_dir[side])])
	var crashed := [_blocked(next[0]), _blocked(next[1])]
	if next[0] == next[1]:
		crashed = [true, true]
	for side in 2:
		if not crashed[side]:
			_heads[side] = next[side]
			_cells[next[side]] = side
	if crashed[0] or crashed[1]:
		last_crash = next[0] if crashed[0] else next[1]
		if crashed[0] and not crashed[1]:
			sb += 1
		elif crashed[1] and not crashed[0]:
			sa += 1
		round_wait = 1.6


func _blocked(c: Vector2i) -> bool:
	return c.x < 0 or c.y < 0 or c.x >= W or c.y >= H or _cells.has(c)


## Practice opponent: keep going unless the next two cells are blocked, then take the open side.
func _ai(side: int) -> void:
	var d := int(_dir[side])
	var ahead: Vector2i = _heads[side] + DIRS[d]
	var free_ahead := not _blocked(ahead) and not _blocked(ahead + DIRS[d])
	if free_ahead and randf() > 0.04:
		return
	var best := d
	var best_room := -1
	for turn in [1, 3]:
		var nd: int = (d + turn) % 4
		var room := 0
		var c := _heads[side]
		for k in 12:
			c += DIRS[nd]
			if _blocked(c):
				break
			room += 1
		if room > best_room:
			best_room = room
			best = nd
	if not free_ahead or best_room > 6:
		set_dir(side, best)


func _new_round() -> void:
	_cells.clear()
	_heads = [Vector2i(8, H / 2), Vector2i(W - 9, H / 2)]
	_dir = [1, 3]
	_want = [1, 3]
	_turns = [[_heads[0]], [_heads[1]]]
	for side in 2:
		_cells[_heads[side]] = side
	_acc = 0.0
	_rate = 11.0
	round_wait = 0.0
	last_crash = Vector2i(-1, -1)


func view() -> Dictionary:
	return {"g": "trails", "a": _flat(0), "b": _flat(1), "sa": sa, "sb": sb, "wait": round_wait,
		"crash": [last_crash.x, last_crash.y], "running": running}


## Corner cells then the head, as [x0, y0, x1, y1, ...].
func _flat(side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in _turns[side]:
		out.append(c.x)
		out.append(c.y)
	out.append(_heads[side].x)
	out.append(_heads[side].y)
	return out
