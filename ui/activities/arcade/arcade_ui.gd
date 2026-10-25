extends Control
## Duo cabinet (Images/UI - Cinema and Arcade.png + Activity Play Guess and Results.png):
## lobby with two station cards and a game pick (Puck Rally / Snow Trails) -> 3-2-1 -> live board
## -> results with rematch. Online matches are run by ArcadeNet on the server; this screen draws
## its state and sends this player's paddle / turns. Solo practice runs locally against the AI.
## Intents out: ready, solo, leave, play_again, pick:<game>.

signal intent(action: String)

const A := preload("res://ui/activities/act_style.gd")
const TITLES := {"puck": "Puck Rally", "trails": "Snow Trails"}
const HINTS := {"puck": "Move up / down  ·  W / S", "trails": "Turn  ·  W A S D"}

var blocks_world := true
var cabinet := ""
var station := 0
var slots := 1
var versus := false
var local_solo := false
var game := "puck"
var phase := "lobby"          ## lobby | countdown | playing | results
var stations := [
	{"name": "You", "status": "Ready to play!", "body": 0, "outfit": {}},
	{"name": "", "status": "Waiting for a friend", "body": 0, "outfit": {}},
]
var board: Control            ## PuckBoard or TrailsBoard
var _pad := 0.5
var _lobby_sig := ""
var _closing_ui := false
var _root: Control
var _count: Label
var _final := Vector2i(5, 3)
var _waiting_ready := false
var _last_left := -1
var _state: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _process(delta: float) -> void:
	if phase != "playing" or local_solo or not (board is PuckBoard):
		return
	var axis := Input.get_axis("move_forward", "move_back") if InputMap.has_action("move_forward") else 0.0
	_pad = clampf(_pad + axis * 0.9 * delta, 0.13, 0.87)
	ArcadeNet.duo_input(_pad)


# ------------------------------------------------------------- state in --
func show_lobby(rows: Array) -> void:
	if local_solo or phase != "lobby":
		return
	var sig := str(rows) + game + str(_waiting_ready)
	if sig == _lobby_sig:
		return
	_lobby_sig = sig
	stations = rows
	_build()


## Server state for this cabinet (ArcadeNet.duo_changed).
func apply_state(s: Dictionary) -> void:
	if local_solo:
		return
	_state = s
	var g := str(s.get("game", game))
	var p := str(s.get("phase", "idle"))
	if g != game:
		game = g
		_lobby_sig = ""
		if phase == "lobby":
			_build()
	match p:
		"countdown":
			if phase != "countdown":
				_begin(false)
				phase = "countdown"
			var n := int(ceil(float(s.get("left", 0.0))))
			if n != _last_left and n >= 1:
				_last_left = n
				_set_count(str(n))
				Sfx.play(self, "count", -6.0)
			_feed(s)
		"live":
			if phase != "playing":
				if phase != "countdown":
					_begin(false)
				phase = "playing"
				_set_count("GO!")
				Sfx.play(self, "go", -4.0)
				get_tree().create_timer(0.6).timeout.connect(func() -> void: _set_count(""))
			_feed(s)
		"results":
			if phase == "playing" or phase == "countdown":
				_waiting_ready = false
				_show_results(int(s.get("sa", 0)), int(s.get("sb", 0)))
		_:
			if phase == "results" and not _waiting_ready:
				return
			if phase != "lobby" and phase != "results":
				return_lobby()
	if phase == "lobby" or (phase == "results" and _waiting_ready):
		var ready_ids: Array = s.get("ready", [])
		_waiting_ready = ready_ids.has(Net.local_id())


func _feed(s: Dictionary) -> void:
	if board is PuckBoard:
		(board as PuckBoard).apply_view(float(s.get("px", 0.5)), float(s.get("py", 0.5)), float(s.get("lp", 0.5)), float(s.get("rp", 0.5)))
	elif board is TrailsBoard:
		(board as TrailsBoard).apply_view(s)
	_set_scores(int(s.get("sa", 0)), int(s.get("sb", 0)))


func return_lobby() -> void:
	local_solo = false
	phase = "lobby"
	_lobby_sig = ""
	_pad = 0.5
	_waiting_ready = false
	_build()


func start_solo() -> void:
	_begin(true)


# --------------------------------------------------------------- building --
func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	match phase:
		"playing", "countdown":
			_build_playing()
		"results":
			_build_results()
		_:
			_build_lobby()
	_count = A.title("", 110, HORIZONTAL_ALIGNMENT_CENTER)
	_count.add_theme_color_override("font_outline_color", A.WHITE)
	_count.add_theme_constant_override("outline_size", 18)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	A.pin(_root, _count, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-200, -80, 200, 80))


func _set_count(text: String) -> void:
	if _count == null:
		return
	_count.text = text
	_count.add_theme_color_override("font_color", A.CORAL if text == "GO!" else A.NAVY)
	_count.pivot_offset = Vector2(200, 80)
	_count.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(_count, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _station_card(i: int) -> PanelContainer:
	var st: Dictionary = stations[i]
	var p := A.panel(14, 18)
	var v := A.vbox(4)
	p.add_child(v)
	var nm := str(st.get("name", ""))
	v.add_child(A.label(nm if nm != "" else "Open", 24, A.NAVY if nm != "" else A.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	if nm != "":
		var pv := PenguinView.new()
		pv.framing = "portrait"
		pv.custom_minimum_size = Vector2(150, 120)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pv)
		pv.call_deferred("set_look", Net.coat_color(int(st.get("body", 0))), st.get("outfit", {}))
	else:
		var plus := A.icon("plus", 64, A.MUTED)
		plus.custom_minimum_size = Vector2(150, 120)
		v.add_child(plus)
	v.add_child(A.label(str(st.get("status", "")), 18, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _build_lobby() -> void:
	A.pin(_root, _station_card(0), Vector4(0, 0.5, 0, 0.5), Vector4(90, -160, 290, 50))
	A.pin(_root, _station_card(1), Vector4(1, 0.5, 1, 0.5), Vector4(-290, -160, -90, 50))
	# game pick
	var pick := A.panel(14, 22)
	A.pin(_root, pick, Vector4(0.5, 0, 0.5, 0), Vector4(-330, 24, 330, 0))
	var pv := A.vbox(8)
	pick.add_child(pv)
	pv.add_child(A.label("Pick a game", 18, A.SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	var row := A.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	pv.add_child(row)
	for g in ["puck", "trails"]:
		var b := A.button(TITLES[g], "primary" if g == game else "secondary", "gamepad" if g == "puck" else "snowflake", 24, Vector2(290, 64))
		b.toggle_mode = true
		b.button_pressed = g == game
		b.pressed.connect(func() -> void:
			game = g
			_lobby_sig = ""
			intent.emit("pick:" + g)
			_build())
		row.add_child(b)
	pv.add_child(A.label("First to 5 goals" if game == "puck" else "First to 3 rounds  ·  don't hit the ice walls",
		16, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := A.panel(14, 26)
	A.pin(_root, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-560, -132, 560, -26))
	var brow := A.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	bar.add_child(brow)
	var solo := A.button("Solo practice", "secondary", "gamepad", 24, Vector2(300, 74))
	solo.pressed.connect(func() -> void: intent.emit("solo"); _begin(true))
	brow.add_child(solo)
	var two_here := str(stations[0].get("name", "")) != "" and str(stations[1].get("name", "")) != ""
	var ready := A.button("Waiting..." if _waiting_ready else "Ready", "primary", "play", 32, Vector2(380, 86))
	ready.disabled = not two_here or _waiting_ready
	ready.tooltip_text = "" if two_here else "Waiting for a second player at this cabinet"
	ready.pressed.connect(func() -> void:
		intent.emit("ready")
		_waiting_ready = true
		ready.text = "Waiting..."
		ready.disabled = true)
	brow.add_child(ready)
	var leave := A.button("Leave", "danger", "leave", 24, Vector2(260, 74))
	leave.pressed.connect(close)
	brow.add_child(leave)


## Opens the board: solo against the AI, or a mirror of the server's match.
func _begin(solo: bool) -> void:
	local_solo = solo
	versus = not solo
	if solo:
		var me: Dictionary = stations[clampi(station, 0, 1)].duplicate()
		if str(me.get("name", "")) == "":
			me = {"name": "You", "status": "Ready to play!", "body": 0, "outfit": {}}
		stations[0] = me
		stations[1] = {"name": "Computer", "status": "Practice", "body": 2, "outfit": {}}
	phase = "playing"
	_pad = 0.5
	_last_left = -1
	_build()
	if board is PuckBoard:
		var pb := board as PuckBoard
		pb.mirror = not solo
		pb.ai_right = solo
		if solo:
			pb.start()
		else:
			pb.running = false
	elif board is TrailsBoard and solo:
		(board as TrailsBoard).start_local()


func _build_playing() -> void:
	var p := A.panel(22, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-430, -330, 430, 330))
	var v := A.vbox(12)
	p.add_child(v)
	v.add_child(A.label("PENGLOO PARTY  ·  LIVE ARCADE", 15, A.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.title(TITLES.get(game, "Puck Rally"), 44, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := A.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(sc)
	var l_chip := _score_chip(str(stations[0]["name"]), 0, A.CORAL)
	var r_chip := _score_chip(str(stations[1]["name"]), 0, A.TEAL)
	sc.add_child(l_chip)
	sc.add_child(r_chip)
	if game == "trails":
		var tb := TrailsBoard.new()
		tb.turned.connect(func(d: int) -> void: ArcadeNet.duo_input(float(d)))
		tb.finished.connect(func(a: int, b: int) -> void: if local_solo: _show_results(a, b))
		board = tb
	else:
		var pb := PuckBoard.new()
		pb.scored.connect(func(a: int, b: int) -> void:
			(l_chip.find_child("Score", true, false) as Label).text = str(a)
			(r_chip.find_child("Score", true, false) as Label).text = str(b)
			Sfx.play(self, "score", -6.0))
		pb.finished.connect(func(a: int, b: int) -> void: if local_solo: _show_results(a, b))
		board = pb
	board.custom_minimum_size = Vector2(0, 380)
	v.add_child(board)
	var foot := A.hbox(12)
	v.add_child(foot)
	var leave := A.button("Leave", "secondary", "", 22, Vector2(200, 58))
	leave.pressed.connect(close)
	foot.add_child(leave)
	foot.add_child(A.expander())
	foot.add_child(A.chip(HINTS.get(game, ""), A.CARD, A.NAVY, "", 17))


func _score_chip(nm: String, val: int, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.box(col, 14, 0, Color.TRANSPARENT, 0))
	var h := A.hbox(18)
	p.add_child(h)
	var n := A.label(nm, 22, A.WHITE, true)
	n.custom_minimum_size.x = 110
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(n)
	var sv := A.label(str(val), 34, A.WHITE, true)
	sv.name = "Score"
	sv.custom_minimum_size.x = 60
	sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sbox := PanelContainer.new()
	sbox.add_theme_stylebox_override("panel", A.box(col.darkened(0.08), 14, 0, Color.TRANSPARENT, 4))
	sbox.add_child(sv)
	h.add_child(sbox)
	return p


func _set_scores(sa: int, sb: int) -> void:
	if _root == null:
		return
	var labels := _root.find_children("Score", "Label", true, false)
	if labels.size() >= 2:
		if (labels[0] as Label).text != str(sa) or (labels[1] as Label).text != str(sb):
			if (labels[0] as Label).text != "0" or (labels[1] as Label).text != "0" or sa + sb > 0:
				Sfx.play(self, "score", -6.0)
		(labels[0] as Label).text = str(sa)
		(labels[1] as Label).text = str(sb)


func _show_results(a: int, b: int) -> void:
	_final = Vector2i(a, b)
	phase = "results"
	_build()
	var mine := _final.x if local_solo or station == 0 else _final.y
	var theirs := _final.y if local_solo or station == 0 else _final.x
	Sfx.play(self, "win" if mine > theirs else "lose", -4.0)


func _build_results() -> void:
	var top := A.panel(18, 26)
	A.pin(_root, top, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 26, 300, 196))
	var row := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	top.add_child(row)
	for i in 2:
		var pv := PenguinView.new()
		pv.framing = "portrait"
		pv.custom_minimum_size = Vector2(110, 110)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.call_deferred("set_look", Net.coat_color(int(stations[i].get("body", 0))), stations[i].get("outfit", {}))
		if i == 1:
			var mid := A.vbox(0)
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			var line := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
			var lv := A.vbox(-6)
			lv.add_child(A.label(str(stations[0]["name"]), 22, A.NAVY, true))
			lv.add_child(A.title(str(_final.x), 52))
			line.add_child(lv)
			line.add_child(A.title("·", 40))
			line.add_child(A.label(str(stations[1]["name"]), 32, A.NAVY, true))
			line.add_child(A.title(str(_final.y), 52))
			mid.add_child(line)
			var mine := _final.x if local_solo or station == 0 else _final.y
			var won := mine > (_final.y if local_solo or station == 0 else _final.x)
			mid.add_child(A.label("Great game!" if won else "So close!", 20, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
			row.add_child(mid)
		row.add_child(pv)
	var bar := A.panel(14, 26)
	A.pin(_root, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-380, -128, 380, -26))
	var b := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	bar.add_child(b)
	var again := A.button("Waiting..." if _waiting_ready else "Play again", "primary", "rotate", 28, Vector2(360, 78))
	again.disabled = _waiting_ready
	again.pressed.connect(func() -> void:
		if local_solo or intent.get_connections().is_empty():
			_begin(true)
			return
		intent.emit("play_again")
		_waiting_ready = true
		again.text = "Waiting..."
		again.disabled = true)
	b.add_child(again)
	var home := A.button("Back to town", "secondary", "home", 24, Vector2(330, 78))
	home.pressed.connect(close)
	b.add_child(home)


func close() -> void:
	if _closing_ui:
		return
	_closing_ui = true
	intent.emit("leave")
	UIRouter.remove(self)
	queue_free()


func preview(state: String) -> void:
	match state:
		"lobby":
			stations[1] = {"name": "Milo", "status": "In the lobby", "body": 0, "outfit": {"head": "red_beanie"}}
			stations[0]["outfit"] = {}
			phase = "lobby"
			_build()
		"playing":
			stations[1] = {"name": "Milo", "status": "", "body": 0, "outfit": {}}
			phase = "playing"
			_build()
			(board as PuckBoard).preview_pose(0.45, 0.48, Vector2(0.7, 0.36), Vector2i(2, 1))
			_set_scores(2, 1)
		"trails":
			stations[1] = {"name": "Milo", "status": "", "body": 0, "outfit": {}}
			game = "trails"
			_begin(true)
		_:
			stations[1] = {"name": "Milo", "status": "", "body": 0, "outfit": {"head": "red_beanie"}}
			_final = Vector2i(5, 3)
			phase = "results"
			_build()
