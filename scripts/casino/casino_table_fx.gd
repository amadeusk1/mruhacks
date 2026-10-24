extends Node3D
## What everyone in the casino sees on the tables, driven by the host's public views (no private
## cards): the roulette ball spinning to the drawn pocket with the number lit above the wheel, the
## poker board, face-down hole cards and dealer button, blackjack cards and bet stacks, and slot
## reels spinning when someone plays. Added to the casino room by casino_session.gd.

const R := preload("res://scripts/casino/casino_rules.gd")
const WHEEL_TRACK := 0.33
const BALL_END := 0.2

var tables := {}          # game -> table Node3D (from the seats' "table" meta)
var _slot_nodes := {}     # table id ("slot_<key>") -> slot machine Node3D
var _layers := {}         # table id -> Node3D holding that table's cards/chips (rebuilt per view)
var _sigs := {}           # table id -> last drawn signature
var _ball: Node3D
var _mark: Label3D
var _rotor: AnimationPlayer
var _spin_id := -1
var _spin_t := 0.0
var _spin_len := 0.0
var _angle := 0.0
var _omega := 0.0
var _radius := WHEEL_TRACK
var _tick_acc := 0.0
var _reels := {}          # machine -> seconds left spinning


func setup(room: Node) -> void:
	for seat in room.find_children("*", "SeatSpot", true, false):
		var game := str(seat.get("activity"))
		if seat.has_meta("table") and game in ["roulette", "poker", "blackjack"]:
			tables[game] = seat.get_meta("table")
		elif game == "slots":
			var m := _nearest_machine(room, (seat as Node3D).global_position)
			if m:
				_slot_nodes["slot_" + String(seat.name).trim_prefix("Slot_")] = m
	var wheel: Node3D = tables.get("roulette")
	if wheel:
		for ap in wheel.find_children("*", "AnimationPlayer", true, false):
			for clip in (ap as AnimationPlayer).get_animation_list():
				if String(clip).find("rotor") >= 0 or String(clip).ends_with("_spin"):
					_rotor = ap
					ap.play(clip)
					ap.speed_scale = 0.25
					break
		_ball = AssetPack.spawn("casino", "roulette_ball")
		if _ball:
			wheel.add_child(_ball)
			_ball.position = _wheel() + Vector3(cos(_angle) * BALL_END, 0.04, sin(_angle) * BALL_END)
		_mark = Label3D.new()
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.font_size = 110
		_mark.pixel_size = 0.004
		_mark.outline_size = 22
		_mark.outline_modulate = Color(0.06, 0.12, 0.16)
		_mark.position = _wheel() + Vector3(0, 0.45, 0)
		_mark.visible = false
		wheel.add_child(_mark)


func _nearest_machine(room: Node, at: Vector3) -> Node3D:
	var best: Node3D = null
	var d := 3.0
	for n in room.find_children("*", "Node3D", true, false):
		if String(n.scene_file_path).ends_with("slot_machine.glb"):
			var dd := (n as Node3D).global_position.distance_to(at)
			if dd < d:
				d = dd
				best = n
	return best


func _wheel() -> Vector3:
	var s: Dictionary = AssetRegistry.sockets("casino/roulette_table")
	var b: Array = s.get("socket_wheel_center", [-1.2, 0.0, 0.758])
	return Vector3(b[0], b[2], -b[1])


func _process(delta: float) -> void:
	if _spin_len > 0.0 and _ball:
		_spin_t += delta
		var k := clampf(_spin_t / _spin_len, 0.0, 1.0)
		_omega = lerpf(14.0, 0.0, ease(k, 0.6))
		_angle += _omega * delta
		_radius = lerpf(WHEEL_TRACK, BALL_END, smoothstep(0.55, 0.9, k))
		_ball.position = _wheel() + Vector3(cos(_angle) * _radius, 0.04 + (0.012 * sin(_spin_t * 30.0) if k > 0.6 and k < 0.92 else 0.0), sin(_angle) * _radius)
		if _rotor:
			_rotor.speed_scale = lerpf(1.6, 0.25, k)
		_tick_acc += _omega * delta
		if k > 0.55 and _tick_acc > 1.2:
			_tick_acc = 0.0
			CasinoSfx.play(self, "tick", -14.0)
		if k >= 1.0:
			_spin_len = 0.0
			_mark.visible = true
			CasinoSfx.play(self, "drop", -8.0)
	for m in _reels.keys():
		_reels[m] = float(_reels[m]) - delta
		var machine: Node3D = m
		for i in 3:
			var reel := machine.find_child("part_reel_%d" % i, true, false) as Node3D
			if reel and float(_reels[m]) + i * 0.35 > 0.0:
				reel.rotate_object_local(Vector3.RIGHT, delta * 14.0)
		if float(_reels[m]) < -0.8:
			_reels.erase(m)


## A public view from the host (casino_session forwards every one).
func show_view(table_id: String, v: Dictionary) -> void:
	if table_id == "roulette":
		_roulette(v)
	elif table_id == "poker":
		_poker(v)
	elif table_id == "blackjack":
		_blackjack(v)
	elif _slot_nodes.has(table_id):
		var m: Node3D = _slot_nodes[table_id]
		var sig := str(v.get("table_spin", 0))
		if _sigs.get(table_id, sig) != sig:
			_reels[m] = 1.2
		_sigs[table_id] = sig


func _roulette(v: Dictionary) -> void:
	if _ball == null:
		return
	var phase := str(v.get("phase", ""))
	if phase == "spinning" and int(v.get("spin_id", -1)) != _spin_id:
		_spin_id = int(v["spin_id"])
		_spin_len = maxf(0.5, float(v.get("spin_left", 6.0)) - 0.3)
		_spin_t = 0.0
		_radius = WHEEL_TRACK
		_mark.visible = false
	var pocket := int(v.get("pocket", -1))
	if pocket >= 0 and _mark:
		_mark.text = str(pocket)
		_mark.modulate = {"red": Color("#E5493F"), "black": Color("#2A2F3A"), "green": Color("#2E9E5E")}[R.roulette_color(pocket)]
		if phase == "result" and _spin_len <= 0.0:
			_mark.visible = true
	if phase == "betting":
		_mark.visible = false


func _poker(v: Dictionary) -> void:
	var t: Node3D = tables.get("poker")
	if t == null:
		return
	var sig := JSON.stringify([v.get("board"), v.get("pot"), v.get("seats", []).map(func(s): return [s.get("cards", 0), s.get("button", false), s.get("shown", [])] if s is Dictionary else [])])
	if _sigs.get("poker", "") == sig:
		return
	var grew: bool = (v.get("board", []) as Array).size() > int(_sigs.get("poker_board", 0))
	_sigs["poker"] = sig
	_sigs["poker_board"] = (v.get("board", []) as Array).size()
	var layer := _layer("poker", t)
	var sk: Dictionary = AssetRegistry.sockets("casino/poker_table")
	var board: Array = v.get("board", [])
	for i in board.size():
		_card(layer, _sock(sk, "socket_board_%d" % i), board[i], 0.0)
	var seats: Array = v.get("seats", [])
	for s in seats.size():
		var row = seats[s]
		if not row is Dictionary or row.is_empty():
			continue
		var at := _sock(sk, "socket_hand_%d" % s)
		var face := atan2(at.x, at.z)
		var shown: Array = row.get("shown", [])
		for k in int(row.get("cards", 0)):
			var off := Vector3(cos(face), 0, -sin(face)) * (k - 0.5) * 0.07
			_card(layer, at + off, shown[k] if k < shown.size() else null, face)
		if row.get("button", false):
			var b := AssetPack.spawn("casino", "dealer_button")
			if b:
				layer.add_child(b)
				b.position = at.lerp(Vector3(0, at.y, 0), -0.25) + Vector3(0.12, 0.005, 0)
	_stack(layer, _sock(sk, "socket_pot"), int(v.get("pot", 0)))
	if grew:
		CasinoSfx.play(self, "card", -10.0)


func _blackjack(v: Dictionary) -> void:
	var t: Node3D = tables.get("blackjack")
	if t == null:
		return
	var sig := JSON.stringify([v.get("dealer"), v.get("players", []).map(func(p): return [p["seat"], p["bet"], p["hands"]])])
	if _sigs.get("blackjack", "") == sig:
		return
	_sigs["blackjack"] = sig
	var layer := _layer("blackjack", t)
	var sk: Dictionary = AssetRegistry.sockets("casino/blackjack_table")
	var dealer: Array = v.get("dealer", [])
	var d_at := _sock(sk, "socket_dealer_hand")
	for i in dealer.size():
		_card(layer, d_at + Vector3((i - (dealer.size() - 1) * 0.5) * 0.08, 0, 0), dealer[i], 0.0)
	for p in v.get("players", []):
		var s := int(p["seat"])
		var at := _sock(sk, "socket_hand_%d" % s)
		var face := atan2(at.x, at.z)
		var hands: Array = p.get("hands", [])
		for hi in hands.size():
			var cards: Array = hands[hi]["cards"]
			for k in cards.size():
				var off := Vector3(cos(face), 0, -sin(face)) * ((k - (cards.size() - 1) * 0.5) * 0.05 + (hi - (hands.size() - 1) * 0.5) * 0.16)
				_card(layer, at + off + Vector3(0, k * 0.002, 0), cards[k], face)
		var bet := int(p.get("bet", 0))
		for h in hands:
			bet = maxi(bet, int(h.get("bet", 0)))
		_stack(layer, _sock(sk, "socket_bet_%d" % s), bet)
	CasinoSfx.play(self, "card", -12.0)


func _layer(id: String, table: Node3D) -> Node3D:
	if _layers.has(id) and is_instance_valid(_layers[id]):
		_layers[id].queue_free()
	var l := Node3D.new()
	l.name = "CasinoFx_" + id
	table.add_child(l)
	_layers[id] = l
	return l


func _sock(sk: Dictionary, n: String) -> Vector3:
	var b: Array = sk.get(n, [0, 0, 0.64])
	return Vector3(b[0], b[2] + 0.006, -b[1])


## A card lying on the felt; `view` [rank, suit] shows its face, null shows the back.
func _card(layer: Node3D, at: Vector3, view, yaw: float) -> void:
	var c := AssetPack.spawn("casino", "card")
	if c == null:
		return
	layer.add_child(c)
	c.position = at
	c.rotation.y = yaw
	if view == null:
		return
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.084, 0.118)
	face.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#FFFDF8")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override = m
	face.rotation.x = -PI * 0.5
	face.position = Vector3(0, 0.0055, 0)
	c.add_child(face)
	var l := Label3D.new()
	l.text = "%s\n%s" % [view[0], {"spades": "♠", "hearts": "♥", "diamonds": "♦", "clubs": "♣"}.get(view[1], "?")]
	l.modulate = Color("#D6453C") if view[1] in ["hearts", "diamonds"] else Color("#232733")
	l.font_size = 64
	l.pixel_size = 0.0007
	l.outline_size = 0
	l.line_spacing = -18
	l.rotation.x = -PI * 0.5
	l.position = Vector3(0, 0.0065, 0)
	l.double_sided = false
	c.add_child(l)


func _stack(layer: Node3D, at: Vector3, chips: int) -> void:
	if chips <= 0:
		return
	var n := clampi(1 + int(log(float(chips)) / log(3.0)), 1, 6)
	for i in n:
		var s := AssetPack.spawn("casino", "chip")
		if s == null:
			return
		layer.add_child(s)
		s.position = at + Vector3((i % 3) * 0.035 - 0.035, 0.0, (i / 3) * 0.035)
		var stack_h := 1 + (chips / maxi(1, n)) % 4
		s.scale = Vector3(1, stack_h, 1)
		Tints.apply(s, {"chip": CasinoKit.CHIP_COLORS[i % CasinoKit.CHIP_COLORS.size()]})
