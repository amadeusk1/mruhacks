extends Control
## Roulette at the casino table. Red, black, or green. The wheel is the 3D rotor;
## this screen only places the bet and reads the purse.

signal intent(action: String)

const A := preload("res://ui/activities/act_style.gd")
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const WHEEL := Vector3(-1.2, 0.758, 0.0)

var blocks_world := true
var _table: Node3D
var _ball: Node3D
var _rotor: AnimationPlayer
var _clip := ""
var _rotor_speed := 1.0
var _mark: Label3D
var _bet := "red"
var _stake := 1
var _pocket := 0
var _spinning := false
var _angle := 0.4
var _omega := 0.0
var _radius := 0.32
var _closing := false
var _result: Label
var _coins: Label
var _spin: Button
var _bets := {}
var _stakes := {}


func setup(table: Node3D) -> void:
	_table = table


func wheel_table() -> Node3D:
	return _table


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.THEME
	_build()
	_bind_wheel()
	_refresh_coins()


func _process(delta: float) -> void:
	if not _spinning or _ball == null:
		return
	_angle += _omega * delta
	_omega = move_toward(_omega, 0.0, 2.6 * delta)
	_radius = move_toward(_radius, 0.18, 0.06 * delta)
	if _rotor != null and _clip != "":
		_rotor.speed_scale = maxf(_omega * 0.45, 0.15)
	_place_ball()
	if _omega > 0.4:
		return
	_spinning = false
	_settle()


func _build() -> void:
	var bar := A.panel(16, 18)
	A.pin(self, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-520, -168, 520, -22))
	var col := A.vbox(10)
	bar.add_child(col)
	var top := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	col.add_child(top)
	top.add_child(A.label("ROULETTE", 16, A.MUTED, true))
	_coins = A.label("0 coins", 22, A.NAVY, true)
	top.add_child(_coins)
	top.add_child(A.expander())
	_result = A.label("Bet red, black, or green", 22, A.NAVY, true)
	top.add_child(_result)
	var row := A.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	col.add_child(row)
	for amount in [1, 5, 10]:
		var stake := A.button(str(amount), "secondary", "", 22, Vector2(72, 56))
		stake.pressed.connect(_choose_stake.bind(amount, stake))
		row.add_child(stake)
		_stakes[amount] = stake
	row.add_child(A.label(" ", 8))
	for color in ["red", "black", "green"]:
		var bet := A.button(color.capitalize(), "secondary", "", 22, Vector2(118, 56))
		bet.pressed.connect(_choose_bet.bind(color))
		row.add_child(bet)
		_bets[color] = bet
	_spin = A.button("Spin", "primary", "", 26, Vector2(132, 56))
	_spin.pressed.connect(_on_spin)
	row.add_child(_spin)
	var leave := A.button("Leave", "danger", "leave", 22, Vector2(120, 56))
	leave.pressed.connect(close)
	row.add_child(leave)
	_choose_stake(1, _stakes[1])
	_choose_bet("red")


func _choose_stake(amount: int, _button: Button) -> void:
	if _spinning:
		return
	_stake = amount
	for n in _stakes:
		(_stakes[n] as Button).text = str(n) if int(n) != amount else "%s*" % n


func _choose_bet(color: String) -> void:
	if _spinning:
		return
	_bet = color
	for key in _bets:
		(_bets[key] as Button).text = str(key).capitalize() if str(key) != color else "• %s" % str(key).capitalize()


func _on_spin() -> void:
	if _spinning:
		return
	var hud := _purse()
	if hud != null and int(hud.coins) < _stake:
		_result.text = "Not enough coins"
		return
	if hud != null:
		hud.add_coins(-_stake)
	_pocket = randi() % 37
	_spinning = true
	_omega = 12.0
	_radius = 0.36
	_spin.disabled = true
	if _mark:
		_mark.visible = false
	_result.text = "Spinning..."
	_refresh_coins()
	intent.emit("spin")


func _settle() -> void:
	var color := _color_of(_pocket)
	if _mark:
		_mark.text = str(_pocket)
		_mark.modulate = _swatch(color)
		_mark.visible = true
	var won := color == _bet
	if won:
		var pay := _stake * (14 if color == "green" else 2)
		var hud := _purse()
		if hud != null:
			hud.add_coins(pay)
		_result.text = "%d %s  ·  you win %d" % [_pocket, color, pay]
	else:
		_result.text = "%d %s" % [_pocket, color]
	_spin.disabled = false
	if _rotor != null:
		_rotor.speed_scale = 0.2
	_refresh_coins()


func _bind_wheel() -> void:
	if _table == null:
		return
	for ap in _table.find_children("*", "AnimationPlayer", true, false):
		for clip in (ap as AnimationPlayer).get_animation_list():
			if String(clip).find("rotor") >= 0 or String(clip).ends_with("_spin"):
				_rotor = ap
				_clip = String(clip)
				_rotor_speed = ap.speed_scale
				if not ap.is_playing():
					ap.play(_clip)
				ap.speed_scale = 0.2
				break
		if _rotor != null:
			break
	_ball = AssetPack.spawn("casino", "roulette_ball")
	if _ball:
		_ball.name = "RouletteBall"
		_table.add_child(_ball)
		_place_ball()
	_mark = Label3D.new()
	_mark.name = "RouletteMark"
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 96
	_mark.pixel_size = 0.004
	_mark.outline_size = 18
	_mark.outline_modulate = Color(0.08, 0.16, 0.2)
	_mark.position = WHEEL + Vector3(0, 0.32, 0)
	_mark.visible = false
	_table.add_child(_mark)


func _place_ball() -> void:
	if _ball == null:
		return
	_ball.position = Vector3(
		WHEEL.x + cos(_angle) * _radius,
		WHEEL.y + 0.04,
		WHEEL.z + sin(_angle) * _radius
	)


func _refresh_coins() -> void:
	var hud := _purse()
	_coins.text = "%d coins" % (int(hud.coins) if hud != null else 0)


func _purse() -> Node:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return null
	return world.get_node_or_null("PlayHud")


func _clear_wheel() -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()
	if is_instance_valid(_mark):
		_mark.queue_free()
	if _rotor != null and is_instance_valid(_rotor):
		_rotor.speed_scale = _rotor_speed
	_ball = null
	_mark = null
	_rotor = null


func close() -> void:
	if _closing:
		return
	_closing = true
	_spinning = false
	_clear_wheel()
	intent.emit("leave")
	UIRouter.remove(self)
	queue_free()


static func _color_of(n: int) -> String:
	if n == 0:
		return "green"
	return "red" if n in REDS else "black"


static func _swatch(color: String) -> Color:
	match color:
		"red":
			return Color(0.86, 0.22, 0.18)
		"green":
			return Color(0.16, 0.55, 0.32)
		_:
			return Color(0.12, 0.14, 0.18)
