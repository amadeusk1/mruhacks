extends Control
## Sketch Club / drawing telephone (Images/UI - Drawing Telephone.png + the Drawing Guess panel).
## Phases: lobby -> prompt -> draw -> guess -> wait (submitted) -> reveal. Each player only ever gets
## their own assignment via apply_state(); nothing about other chains is held here until reveal.
##   state: {phase, players:[names], deadline_s, assignment: {text|strokes}, reveal:{chain, entries:[{who, kind, text|strokes}], index, total}}
## Intents: ready, leave, submit_text(text), submit_drawing(strokes), next_entry.
## Live state comes from the SketchClub autoload (ActivityScreens wires it); preview() keeps mock
## states for UI captures.  Extra live fields: ready[], seated, min_players, is_host, round/rounds,
## reveal.done, assignment.fallback, phase "spectate".

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const COLORS := ["#1E2E55", "#3D7BD9", "#1FA3A4", "#F0645C", "#F2C230", "#A784D9"]
const SIZES := [5.0, 9.0, 15.0]
const MAX_TEXT := 100

var state := {"phase": "lobby", "players": ["You", "Milo", "Pip", "Coco"], "deadline_s": 30.0}
var _root: Control
var _canvas: SketchCanvas
var _timer_label: Label
var _left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func apply_state(s: Dictionary) -> void:
	state = s
	_left = float(s.get("deadline_s", 0.0))
	_build()


func _process(delta: float) -> void:
	if _timer_label and _left > 0.0:
		_left = maxf(0.0, _left - delta)
		_timer_label.text = "%02d:%02d" % [int(_left) / 60, int(_left) % 60]


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	_timer_label = null
	var back := A.close_disc(56)
	back.icon = A.icon_tex("arrow_left")
	back.tooltip_text = "Leave"
	back.pressed.connect(func() -> void: intent.emit("leave", null))
	A.pin(_root, back, Vector4(0, 0, 0, 0), Vector4(24, 20, 80, 76))
	var phase := str(state.get("phase", "lobby"))
	var sub := {"lobby": "A silly drawing game with friends", "prompt": "Write a silly idea for the next drawing",
		"draw": "Draw the prompt below", "guess": "Describe this drawing", "wait": "Waiting for everyone...",
		"reveal": "See how the idea changed!", "spectate": "A game is underway at the table"}.get(phase, "") as String
	var head := A.vbox(-4)
	A.pin(_root, head, Vector4(0.5, 0, 0.5, 0), Vector4(-360, 14, 360, 110))
	head.add_child(A.title("Sketch Club", 50, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(A.label(sub, 21, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
	if phase in ["prompt", "draw", "guess"]:
		var tc := A.timer_chip("00:00")
		_timer_label = tc.find_child("Text", true, false) as Label
		_left = float(state.get("deadline_s", 30.0))
		_timer_label.text = "%02d:%02d" % [int(_left) / 60, int(_left) % 60]
		A.pin(_root, tc, Vector4(1, 0, 1, 0), Vector4(-210, 22, -24, 0))
	match phase:
		"prompt":
			_prompt()
		"draw":
			_draw_phase()
		"guess":
			_guess()
		"wait":
			_wait()
		"reveal":
			_reveal()
		"spectate":
			_spectate()
		_:
			_lobby()


func _lobby() -> void:
	var count := A.chip("%d players" % (state.get("players", []) as Array).size(), A.WHITE, A.NAVY, "users", 20)
	A.pin(_root, count, Vector4(1, 0, 1, 0), Vector4(-210, 26, -24, 0))
	var row := A.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	A.pin(_root, row, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-560, -170, 560, 150))
	var names: Array = state.get("players", [])
	for i in names.size():
		var col := A.vbox(4)
		col.alignment = BoxContainer.ALIGNMENT_END
		var bubble := A.chip(str(names[i]), Color("#BDEBE6") if i == 0 else A.WHITE, A.NAVY, "", 24, Vector2(20, 8))
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(bubble)
		var pv := PenguinView.new()
		pv.framing = "portrait"
		pv.custom_minimum_size = Vector2(250, 230)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pv)
		pv.call_deferred("set_look", Net.coat_color(0), {"head": ["red_beanie", "glasses", "", "bucket_hat"][i % 4] if i % 4 != 1 else ""} if i % 4 != 1 else {"face": "glasses"})
		row.add_child(col)
	var readies: Array = state.get("ready", [])
	for i in mini(readies.size(), row.get_child_count()):
		if readies[i]:
			var tick := A.chip("Ready", Color("#BDEBE6"), A.NAVY, "check", 18, Vector2(14, 6))
			tick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			(row.get_child(i) as Control).add_child(tick)
	var bar := A.hbox(24, BoxContainer.ALIGNMENT_CENTER)
	A.pin(_root, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-420, -122, 420, -30))
	var need := int(state.get("min_players", 3)) - names.size()
	if not bool(state.get("seated", true)):
		var hint := A.label("Sit at the table to join the next game", 24, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
		bar.add_child(hint)
	else:
		var ready := A.button("Ready" if need <= 0 else "Waiting for %d more" % need, "primary", "pencil", 32, Vector2(520, 84))
		ready.disabled = need > 0
		ready.pressed.connect(func() -> void: intent.emit("ready", null); ready.disabled = true; ready.text = "Ready!")
		bar.add_child(ready)
	var leave := _leave_button()
	bar.add_child(leave)


func _leave_button() -> Button:
	var b := A.button("Leave", "light", "", 24, Vector2(200, 66))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("#E2534A"))
	b.pressed.connect(func() -> void: intent.emit("leave", null))
	return b


func _prompt() -> void:
	var p := A.panel(22, 26)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-420, -160, 420, 30))
	var v := A.vbox(8)
	p.add_child(v)
	var row := A.hbox(16)
	v.add_child(row)
	row.add_child(A.icon("pencil", 44, A.NAVY))
	var field := LineEdit.new()
	field.max_length = MAX_TEXT
	field.placeholder_text = "A penguin on the moon"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = 84
	field.flat = true
	field.add_theme_font_override("font", A.title_font())
	field.add_theme_font_size_override("font_size", 38)
	field.add_theme_color_override("font_color", A.NAVY)
	field.text = str(state.get("draft", ""))
	row.add_child(field)
	var counter := A.label("%d / %d" % [field.text.length(), MAX_TEXT], 17, A.MUTED)
	field.text_changed.connect(func(t: String) -> void: counter.text = "%d / %d" % [t.length(), MAX_TEXT])
	v.add_child(counter)
	var submit := A.button("Submit", "primary", "send", 30, Vector2(420, 78))
	submit.pressed.connect(func() -> void:
		if field.text.strip_edges() != "":
			intent.emit("submit_text", field.text.strip_edges())
			apply_state({"phase": "wait", "players": state.get("players", [])}))
	A.pin(_root, submit, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-210, 60, 210, 138))
	var leave := _leave_button()
	A.pin(_root, leave, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-100, 160, 100, 220))


func _draw_phase() -> void:
	var asg := A.panel(12, 18)
	A.pin(_root, asg, Vector4(0.5, 0, 0.5, 0), Vector4(-340, 112, 340, 170))
	asg.add_child(A.label(str(state.get("assignment", {}).get("text", "")), 26, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	var p := A.panel(16, 24)
	A.pin(_root, p, Vector4(0.5, 0, 0.5, 0), Vector4(-600, 184, 600, 700))
	var h := A.hbox(16)
	p.add_child(h)
	var tools := A.vbox(12)
	tools.custom_minimum_size.x = 230
	h.add_child(tools)
	_canvas = SketchCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(_canvas)
	var pal := GridContainer.new()
	pal.columns = 3
	pal.add_theme_constant_override("h_separation", 14)
	pal.add_theme_constant_override("v_separation", 14)
	tools.add_child(pal)
	for c in COLORS:
		pal.add_child(UIKit.swatch(Color(c), func() -> void: _canvas.color = Color(c); _canvas.eraser = false))
	var sizes := A.hbox(24, BoxContainer.ALIGNMENT_CENTER)
	tools.add_child(sizes)
	for w in SIZES:
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(46, 46)
		b.tooltip_text = "Brush size"
		var dot := A.icon("snowball", w * 2.4, A.NAVY)
		dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		dot.offset_left = -w * 1.2; dot.offset_right = w * 1.2; dot.offset_top = -w * 1.2; dot.offset_bottom = w * 1.2
		b.add_child(dot)
		b.pressed.connect(func() -> void: _canvas.width = w)
		sizes.add_child(b)
	var er := A.button("Eraser", "secondary", "eraser", 19, Vector2(0, 50))
	er.alignment = HORIZONTAL_ALIGNMENT_LEFT
	er.pressed.connect(func() -> void: _canvas.eraser = true)
	tools.add_child(er)
	var ur := A.hbox(10)
	tools.add_child(ur)
	var undo := A.button("Undo", "secondary", "undo", 18, Vector2(0, 50))
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.pressed.connect(func() -> void: _canvas.undo())
	ur.add_child(undo)
	var clear := A.button("Clear", "secondary", "trash", 18, Vector2(0, 50))
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(_confirm_clear)
	ur.add_child(clear)
	tools.add_child(A.expander())
	var quiet := A.hbox(8)
	quiet.add_child(A.icon("mic_off", 22, A.CORAL))
	quiet.add_child(A.label("Private round · voice paused", 16, A.SUB))
	tools.add_child(quiet)
	var submit := A.button("Submit", "primary", "send", 28, Vector2(240, 66))
	submit.pressed.connect(func() -> void:
		intent.emit("submit_drawing", _canvas.strokes.duplicate(true))
		apply_state({"phase": "wait", "players": state.get("players", [])}))
	A.pin(_root, submit, Vector4(0.5, 0, 0.5, 0), Vector4(340, 610, 580, 676))
	if state.has("demo"):
		_canvas.call_deferred("demo")


## Clear asks first only when it would throw strokes away; Undo is immediate.
func _confirm_clear() -> void:
	if _canvas.strokes.is_empty():
		return
	var m := UIKit.modal("Clear drawing?", "This removes every stroke.", 440)
	var row := A.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	var keep := A.button("Keep drawing", "secondary", "", 20, Vector2(190, 56))
	keep.pressed.connect(m.close)
	var yes := A.button("Clear", "danger", "", 20, Vector2(140, 56))
	yes.pressed.connect(func() -> void: _canvas.clear(); m.close())
	row.add_child(keep)
	row.add_child(yes)
	m.body.add_child(row)
	m.open()


func _guess() -> void:
	var p := A.panel(24, 26)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-430, -230, 430, 300))
	var v := A.vbox(12)
	p.add_child(v)
	var top := A.hbox(16)
	v.add_child(top)
	var cv := SketchCanvas.new()
	cv.editable = false
	cv.custom_minimum_size = Vector2(0, 280)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cv)
	cv.set_strokes(state.get("assignment", {}).get("strokes", []))
	if state.has("demo"):
		cv.call_deferred("demo")
	var mute := A.vbox(4)
	mute.custom_minimum_size.x = 120
	mute.alignment = BoxContainer.ALIGNMENT_CENTER
	var mi := A.icon("mic_off", 48, A.NAVY)
	mi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mute.add_child(mi)
	mute.add_child(A.label("Private round\nMic muted", 16, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(mute)
	var fb := str(state.get("assignment", {}).get("fallback", ""))
	v.add_child(A.label(fb if fb != "" else "Describe this drawing", 22, A.NAVY, true))
	var f := UIKit.field("A space penguin", str(state.get("draft", "")), false)
	v.add_child(f["root"])
	var row := A.hbox(16)
	v.add_child(row)
	var leave := A.button("Leave", "secondary", "", 22, Vector2(200, 62))
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	row.add_child(leave)
	row.add_child(A.expander())
	var submit := A.button("Submit", "primary", "", 26, Vector2(280, 66))
	submit.pressed.connect(func() -> void:
		var t := str((f["field"] as LineEdit).text).strip_edges()
		if t == "":
			UIKit.set_field_error(f, "Write a guess first")
			return
		intent.emit("submit_text", t)
		apply_state({"phase": "wait", "players": state.get("players", [])}))
	row.add_child(submit)


func _wait() -> void:
	var p := A.panel(26, 26)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-300, -110, 300, 110))
	var v := A.vbox(10)
	p.add_child(v)
	v.add_child(A.title("Submitted!", 40, HORIZONTAL_ALIGNMENT_CENTER))
	var n := int(state.get("submitted", 1))
	var total := (state.get("players", []) as Array).size()
	v.add_child(A.label("%d of %d friends are done. Voice is back at the reveal." % [n, total], 19, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))


func _reveal() -> void:
	var r: Dictionary = state.get("reveal", {})
	var chip := A.chip("%d / %d" % [int(r.get("index", 1)), int(r.get("total", 1))], A.WHITE, A.NAVY, "", 26, Vector2(22, 10))
	A.pin(_root, chip, Vector4(1, 0, 1, 0), Vector4(-140, 26, -24, 0))
	var row := A.hbox(20, BoxContainer.ALIGNMENT_CENTER)
	A.pin(_root, row, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-560, -210, 560, 160))
	for e in r.get("entries", []):
		var p := A.panel(16, 22)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
		var v := A.vbox(10)
		p.add_child(v)
		v.add_child(A.label(str(e.get("caption", "")), 21, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
		var inner := PanelContainer.new()
		inner.add_theme_stylebox_override("panel", A.box(A.WHITE, 14, 0, Color.TRANSPARENT, 12))
		inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(inner)
		if str(e.get("kind", "text")) == "text":
			var l := A.title(str(e.get("text", "")), 32, HORIZONTAL_ALIGNMENT_CENTER)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inner.add_child(l)
		elif str(e.get("kind")) == "skipped":
			inner.add_child(A.label("(skipped: time ran out)", 22, A.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var cv := SketchCanvas.new()
			cv.editable = false
			cv.custom_minimum_size = Vector2(0, 260)
			inner.add_child(cv)
			if e.has("strokes"):
				cv.set_strokes(e["strokes"])
			else:
				cv.call_deferred("demo")
	var owner := str(r.get("owner", ""))
	if owner != "":
		var oc := A.chip("%s's chain · %d of %d" % [owner, int(r.get("chain", 0)) + 1, int(r.get("chains", 1))], A.WHITE, A.NAVY, "users", 20)
		A.pin(_root, oc, Vector4(0, 0, 0, 0), Vector4(24, 100, 460, 0))
	if bool(state.get("is_host", true)):
		var done := bool(r.get("done", false))
		var next := A.button("Play again" if done else "Next entry", "primary", "arrow_right", 30, Vector2(440, 78))
		next.pressed.connect(func() -> void: intent.emit("play_again" if done else "next_entry", null))
		A.pin(_root, next, Vector4(0.5, 1, 0.5, 1), Vector4(-220, -150, 220, -72))
	else:
		var wait := A.label("The host is revealing the chains", 22, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
		A.pin(_root, wait, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -130, 300, -90))
	var voice := A.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	voice.add_child(A.icon("mic", 22, A.NAVY))
	voice.add_child(A.label("Voice back on", 18, A.NAVY))
	A.pin(_root, voice, Vector4(0.5, 1, 0.5, 1), Vector4(-120, -60, 120, -26))


func _spectate() -> void:
	var p := A.panel(26, 26)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-320, -110, 320, 110))
	var v := A.vbox(10)
	p.add_child(v)
	v.add_child(A.title("Round %d of %d" % [int(state.get("round", 0)) + 1, int(state.get("rounds", 1))], 38, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.label("%d of %d players are done. Watch the reveal on the easel!" % [int(state.get("submitted", 0)), (state.get("players", []) as Array).size()], 19, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	var leave := _leave_button()
	A.pin(_root, leave, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-100, 140, 100, 200))


func close() -> void:
	intent.emit("leave", null)
	queue_free()


func preview(s: String) -> void:
	var players := ["You", "Milo", "Pip", "Coco"]
	match s:
		"prompt":
			apply_state({"phase": "prompt", "players": players, "deadline_s": 23.0, "draft": "A penguin on the moon"})
		"draw":
			apply_state({"phase": "draw", "players": players, "deadline_s": 54.0, "assignment": {"text": "A penguin on the moon"}, "demo": true})
		"guess":
			apply_state({"phase": "guess", "players": players, "deadline_s": 18.0, "assignment": {}, "demo": true, "draft": "A space penguin"})
		"reveal":
			apply_state({"phase": "reveal", "players": players, "reveal": {"index": 2, "total": 4, "entries": [
				{"caption": "Original prompt", "kind": "text", "text": "A penguin on the moon"},
				{"caption": "Milo's drawing", "kind": "drawing"}]}})
		_:
			apply_state({"phase": "lobby", "players": players})
