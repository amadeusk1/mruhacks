extends Control
## Arcade (Images/UI - Cinema and Arcade.png + Activity Play Guess and Results.png):
## lobby with two station cards on ONE cabinet -> live Puck Rally board -> results.
## State in: set_station(i, {name, look, status}), set_phase(). Intents out: ready, solo, leave, play_again.
## Solo practice runs locally against the AI; two-player play needs the host to drive PuckBoard.

signal intent(action: String)

const A := preload("res://ui/activities/act_style.gd")

var phase := "lobby"          ## lobby | playing | results
var stations := [
	{"name": "You", "status": "Ready to play!", "body": 0, "outfit": {}},
	{"name": "", "status": "Waiting for a friend", "body": 0, "outfit": {}},
]
var _root: Control
var board: PuckBoard


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func set_station(i: int, data: Dictionary) -> void:
	stations[i] = data
	_build()


func set_phase(p: String) -> void:
	phase = p
	_build()


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	match phase:
		"playing":
			_build_playing()
		"results":
			_build_results()
		_:
			_build_lobby()


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
	var bar := A.panel(14, 26)
	A.pin(_root, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-560, -132, 560, -26))
	var row := A.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	bar.add_child(row)
	var solo := A.button("Solo practice", "secondary", "gamepad", 24, Vector2(300, 74))
	solo.pressed.connect(func() -> void: intent.emit("solo"); _start_local())
	row.add_child(solo)
	var two_ready: bool = str(stations[1].get("name", "")) != ""
	var ready := A.button("Ready", "primary", "play", 32, Vector2(380, 86))
	ready.disabled = not two_ready
	ready.tooltip_text = "" if two_ready else "Waiting for a second player at this cabinet"
	ready.pressed.connect(func() -> void: intent.emit("ready"))
	row.add_child(ready)
	var leave := A.button("Leave", "danger", "leave", 24, Vector2(260, 74))
	leave.pressed.connect(func() -> void: intent.emit("leave"); queue_free())
	row.add_child(leave)


func _start_local() -> void:
	stations[1] = {"name": "Computer", "status": "Practice", "body": 2, "outfit": {}}
	phase = "playing"
	_build()
	board.ai_right = true
	board.start()


func _build_playing() -> void:
	var p := A.panel(22, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-380, -320, 380, 320))
	var v := A.vbox(12)
	p.add_child(v)
	v.add_child(A.label("PENGLOO PARTY", 15, A.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.title("LIVE ARCADE", 46, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := A.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(sc)
	var l_chip := _score_chip(str(stations[0]["name"]), 0, A.CORAL)
	var r_chip := _score_chip(str(stations[1]["name"]), 0, A.TEAL)
	sc.add_child(l_chip)
	sc.add_child(r_chip)
	board = PuckBoard.new()
	board.custom_minimum_size = Vector2(0, 340)
	v.add_child(board)
	board.scored.connect(func(a: int, b: int) -> void:
		(l_chip.find_child("Score", true, false) as Label).text = str(a)
		(r_chip.find_child("Score", true, false) as Label).text = str(b))
	board.finished.connect(func(a: int, b: int) -> void: _show_results(a, b))
	var foot := A.hbox(12)
	v.add_child(foot)
	var leave := A.button("Leave", "secondary", "", 22, Vector2(200, 58))
	leave.pressed.connect(func() -> void: intent.emit("leave"); queue_free())
	foot.add_child(leave)
	var hint := A.chip("Move up / down  ·  W / S", A.CARD, A.NAVY, "", 17)
	foot.add_child(A.expander())
	foot.add_child(hint)


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


var _final := Vector2i(5, 3)


func _show_results(a: int, b: int) -> void:
	_final = Vector2i(a, b)
	phase = "results"
	_build()


func _build_results() -> void:
	var top := A.panel(18, 26)
	A.pin(_root, top, Vector4(0.5, 0, 0.5, 0), Vector4(-280, 26, 280, 196))
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
			var won := _final.x > _final.y
			mid.add_child(A.label("Great game!" if won else "So close!", 20, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
			row.add_child(mid)
		row.add_child(pv)
	var bar := A.panel(14, 26)
	A.pin(_root, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-380, -128, 380, -26))
	var b := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	bar.add_child(b)
	var again := A.button("Play again", "primary", "rotate", 28, Vector2(360, 78))
	again.pressed.connect(func() -> void: intent.emit("play_again"); _start_local())
	b.add_child(again)
	var home := A.button("Back to town", "secondary", "home", 24, Vector2(330, 78))
	home.pressed.connect(func() -> void: intent.emit("leave"); queue_free())
	b.add_child(home)


func close() -> void:
	intent.emit("leave")
	queue_free()


func preview(state: String) -> void:
	match state:
		"lobby":
			stations[1] = {"name": "Milo", "status": "In the lobby", "body": 0, "outfit": {"head": "red_beanie"}}
			stations[0]["outfit"] = {}
			set_phase("lobby")
		"playing":
			stations[1] = {"name": "Milo", "status": "", "body": 0, "outfit": {}}
			set_phase("playing")
			board.preview_pose(0.45, 0.48, Vector2(0.7, 0.36), Vector2i(2, 1))
			(_root.find_children("Score", "Label", true, false)[0] as Label).text = "2"
			(_root.find_children("Score", "Label", true, false)[1] as Label).text = "1"
		_:
			stations[1] = {"name": "Milo", "status": "", "body": 0, "outfit": {"head": "red_beanie"}}
			_final = Vector2i(5, 3)
			set_phase("results")
