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

var state := {"phase": "lobby", "players": [], "seated": false, "min_players": 3, "deadline_s": 30.0}
var _root: Control
var _canvas: SketchCanvas
var _timer_label: Label
var _left := 0.0
var _free := false
var _free_strokes: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func apply_state(s: Dictionary) -> void:
	if _free and _canvas:
		_free_strokes = _canvas.strokes.duplicate(true)
	var phase := str(s.get("phase", "lobby"))
	state = s
	if _free and phase in ["lobby", "spectate", ""]:
		return
	_free = false
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
	A.pin(_root, head, Vector4(0.5, 0, 0.5, 0), Vector4(-280, 16, 280, 100))
	head.add_child(A.title("Sketch Club", 42, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(A.label(sub, 20, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
	if phase in ["prompt", "draw", "guess"]:
		var tc := A.timer_chip("00:00")
		_timer_label = tc.find_child("Text", true, false) as Label
		_left = float(state.get("deadline_s", 30.0))
		_timer_label.text = "%02d:%02d" % [int(_left) / 60, int(_left) % 60]
		A.pin(_root, tc, Vector4(1, 0, 1, 0), Vector4(-220, 18, -24, 78))
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
	var names: Array = state.get("players", [])
	var count := A.chip("%d at the table" % names.size(), A.WHITE, A.NAVY, "users", 20)
	A.pin(_root, count, Vector4(1, 0, 1, 0), Vector4(-230, 18, -24, 78))
	var card := A.panel(28, 24)
	A.pin(_root, card, Vector4(0, 0.5, 1, 0.5), Vector4(40, -210, -40, 70))
	var body := A.hbox(28)
	card.add_child(body)
	var pv := PenguinView.new()
	pv.framing = "portrait"
	pv.custom_minimum_size = Vector2(220, 240)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(pv)
	pv.call_deferred("set_look", Net.coat_color(0), {})
	var info := A.vbox(14)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	var seated := bool(state.get("seated", true))
	var need := int(state.get("min_players", 3)) - names.size()
	var blurb := "Sit at the table to play with friends." if not seated else (
		"Ready when everyone is." if need <= 0 else "The party game needs %d more." % need)
	info.add_child(A.label(blurb, 22, A.NAVY, true))
	info.add_child(A.label("Or just draw on your own.", 18, A.SUB))
	var roster := HFlowContainer.new()
	roster.add_theme_constant_override("h_separation", 8)
	roster.add_theme_constant_override("v_separation", 8)
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(roster)
	if names.is_empty():
		roster.add_child(A.label("Nobody is seated yet.", 18, A.MUTED))
	else:
		var me := str(Net.local_profile().get("name", ""))
		var readies: Array = state.get("ready", [])
		for i in names.size():
			var ready := i < readies.size() and bool(readies[i])
			var chip := A.chip(str(names[i]) + ("  ·  Ready" if ready else ""), Color("#BDEBE6") if str(names[i]) == me else A.WHITE, A.NAVY, "check" if ready else "", 18, Vector2(14, 8))
			roster.add_child(chip)
	var bar := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	A.pin(_root, bar, Vector4(0, 1, 1, 1), Vector4(24, -116, -24, -28))
	if seated:
		var ready_btn := A.button("Ready" if need <= 0 else "Waiting for %d more" % need, "primary" if need <= 0 else "secondary", "pencil", 26, Vector2(360, 76))
		ready_btn.disabled = need > 0
		ready_btn.pressed.connect(func() -> void: intent.emit("ready", null); ready_btn.disabled = true; ready_btn.text = "Ready!")
		bar.add_child(ready_btn)
	var draw := A.button("Just draw", "primary" if not seated or need > 0 else "secondary", "brush", 26, Vector2(240, 76))
	draw.pressed.connect(_start_free)
	bar.add_child(draw)
	bar.add_child(_leave_button())


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
	var prompt := str(state.get("assignment", {}).get("text", ""))
	_canvas_board(prompt if prompt != "" else "Draw the prompt below", "Submit", _submit_drawing, true)
	if state.has("demo"):
		_canvas.call_deferred("demo")


## Free drawing. Stays up while the table is still in the lobby, and steps aside when a game starts.
func _start_free() -> void:
	_free = true
	_seat("sketch_draw")
	_build_free()


func _stop_free() -> void:
	if _canvas:
		_free_strokes = _canvas.strokes.duplicate(true)
	_free = false
	_seat("sketch")
	_build()


func _build_free() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	_timer_label = null
	var back := A.close_disc(56)
	back.icon = A.icon_tex("arrow_left")
	back.tooltip_text = "Back to the table"
	back.pressed.connect(_stop_free)
	A.pin(_root, back, Vector4(0, 0, 0, 0), Vector4(24, 20, 80, 76))
	var head := A.vbox(-4)
	A.pin(_root, head, Vector4(0.5, 0, 0.5, 0), Vector4(-280, 16, 280, 100))
	head.add_child(A.title("Sketch Club", 42, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(A.label("Draw whatever you like", 20, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER))
	_canvas_board("", "Done", _stop_free, false)
	if not _free_strokes.is_empty():
		_canvas.set_strokes(_free_strokes)


func _canvas_board(prompt: String, action_text: String, on_action: Callable, quiet: bool) -> void:
	var p := A.panel(16, 22)
	A.pin(_root, p, Vector4(0, 0, 1, 1), Vector4(24, 112, -24, -104))
	var v := A.vbox(12)
	p.add_child(v)
	if prompt != "":
		var cap := A.label(prompt, 24, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cap)
	var h: BoxContainer = A.vbox(12) if Mobile.active() else A.hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	_canvas = SketchCanvas.new()
	_canvas.clip_contents = true
	_canvas.custom_minimum_size = Vector2(0, 240) if Mobile.active() else Vector2(360, 280)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tools := A.vbox(12)
	tools.custom_minimum_size.x = 0 if Mobile.active() else 220
	if Mobile.active():
		h.add_child(_canvas)
		h.add_child(tools)
	else:
		h.add_child(tools)
		h.add_child(_canvas)
	var pal := GridContainer.new()
	pal.columns = 6 if Mobile.active() else 3
	pal.add_theme_constant_override("h_separation", 10)
	pal.add_theme_constant_override("v_separation", 10)
	tools.add_child(pal)
	var group := ButtonGroup.new()
	for i in COLORS.size():
		var col := Color(COLORS[i])
		var sw := UIKit.swatch(col, _pick_color.bind(col))
		sw.custom_minimum_size = Vector2(52, 52)
		sw.button_group = group
		if i == 0:
			sw.button_pressed = true
		pal.add_child(sw)
	var sizes := A.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	tools.add_child(sizes)
	for w in SIZES:
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(44, 44)
		b.tooltip_text = "Brush size"
		var dot := A.icon("snowball", w * 2.2, A.NAVY)
		dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		dot.offset_left = -w * 1.1
		dot.offset_right = w * 1.1
		dot.offset_top = -w * 1.1
		dot.offset_bottom = w * 1.1
		b.add_child(dot)
		b.pressed.connect(_pick_width.bind(w))
		sizes.add_child(b)
	var er := A.button("Eraser", "secondary", "eraser", 18, Vector2(0, 48))
	er.alignment = HORIZONTAL_ALIGNMENT_LEFT
	er.pressed.connect(func() -> void: _canvas.eraser = true)
	tools.add_child(er)
	var ur := A.hbox(8)
	tools.add_child(ur)
	var undo := A.button("Undo", "secondary", "undo", 18, Vector2(0, 48))
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.pressed.connect(func() -> void: _canvas.undo())
	ur.add_child(undo)
	var clear := A.button("Clear", "secondary", "trash", 18, Vector2(0, 48))
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(_confirm_clear)
	ur.add_child(clear)
	tools.add_child(A.expander())
	if quiet:
		var note := A.hbox(8)
		note.add_child(A.icon("mic_off", 22, A.CORAL))
		note.add_child(A.label("Private round · voice paused", 16, A.SUB))
		tools.add_child(note)
	var submit := A.button(action_text, "primary", "send" if action_text == "Submit" else "check", 26, Vector2(220, 64))
	submit.pressed.connect(on_action)
	A.pin(_root, submit, Vector4(0.5, 1, 0.5, 1), Vector4(-110, -88, 110, -20))


func _pick_color(c: Color) -> void:
	if _canvas == null:
		return
	_canvas.color = c
	_canvas.eraser = false


func _pick_width(w: float) -> void:
	if _canvas == null:
		return
	_canvas.width = w
	_canvas.eraser = false


func _submit_drawing() -> void:
	if _canvas == null:
		return
	intent.emit("submit_drawing", _canvas.strokes.duplicate(true))
	_free = false
	apply_state({"phase": "wait", "players": state.get("players", [])})


func _seat(kit: String) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player and player.has_method("set_seat_clip") and player.has_method("is_sitting") and bool(player.call("is_sitting")):
		player.call("set_seat_clip", kit)


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
	A.pin(_root, p, Vector4(0, 0, 1, 1), Vector4(48, 112, -48, -28))
	var v := A.vbox(12)
	p.add_child(v)
	var top := A.hbox(16)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(top)
	var cv := SketchCanvas.new()
	cv.editable = false
	cv.clip_contents = true
	cv.custom_minimum_size = Vector2(0, 240)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	A.pin(_root, chip, Vector4(1, 0, 1, 0), Vector4(-150, 18, -24, 82))
	var row := A.hbox(20, BoxContainer.ALIGNMENT_CENTER)
	A.pin(_root, row, Vector4(0, 0, 1, 1), Vector4(28, 176, -28, -180))
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
		A.pin(_root, oc, Vector4(0, 0, 0, 0), Vector4(96, 108, 560, 164))
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
