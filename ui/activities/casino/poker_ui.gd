extends Control
## Poker (Texas Hold'em proposed). Public board, pot and seats; private hole cards for this player only
## (other seats arrive as card counts, never values). Only actions in `legal` are enabled.
##   apply_state({phase: "waiting"|"dealing"|"betting"|"showdown"|"reconnecting"|"full",
##                balance, pot, board: [[rank, suit]], hole: [[rank, suit]] (mine), to_call, min_raise, max_raise,
##                legal: ["fold","check","call","raise"], turn_seat, my_seat, turn_left_s, turn_total_s,
##                seats: [{name, body, chips, cards: int, folded, bet, allin, button, last, shown, hand} or {} (empty)],
##                stack, my_hand, result, starting, left})
##   intent("action", {kind, amount})   amount only for raise, validated to [min_raise, max_raise]
##   intent("leave", null)

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")

var state := {}
var live := false
var _root: Control
var _note := ""
var _note_until := 0.0
var _raise_to := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.is_empty() and not live:
		preview("betting")


func apply_state(s: Dictionary) -> void:
	if int(s.get("turn_seat", -1)) != int(state.get("turn_seat", -2)) or _raise_to == 0:
		_raise_to = int(s.get("min_raise", 0))
	_raise_to = clampi(_raise_to, int(s.get("min_raise", 0)), maxi(int(s.get("min_raise", 0)), int(s.get("max_raise", 0))))
	state = s
	_build()


func notice(message: String) -> void:
	_note = message
	_note_until = Time.get_ticks_msec() / 1000.0 + 4.0
	_build()


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	var fr := K.frame()
	A.pin(_root, fr, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-600, -320, 600, 320))
	var v := A.vbox(8)
	fr.add_child(v)
	var stack_txt := ("Stack %d   " % int(state.get("stack", 0))) if state.has("stack") else ""
	v.add_child(K.header("Poker", "%sPlay chips: %d" % [stack_txt, int(state.get("balance", 0))]))
	var table := Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(table)
	var felt := PanelContainer.new()
	felt.add_theme_stylebox_override("panel", A.box(K.FELT, 200, 12, K.WOOD, 0))
	A.pin(table, felt, Vector4(0.1, 0.12, 0.9, 0.95))
	var phase := str(state.get("phase", ""))
	var broke: bool = state.has("stack") and int(state.get("stack", 0)) == 0 and int(state.get("balance", 0)) == 0 and phase == "waiting"
	if phase == "reconnecting" or (phase == "waiting" and not state.get("starting", false)) or broke:
		var detail := ""
		if phase == "waiting":
			detail = "Blinds %d/%d. A hand starts when two players with chips are seated." % [int(state.get("blinds", [5, 10])[0]), int(state.get("blinds", [5, 10])[1])]
		var card := K.state_card("insufficient" if broke else phase, detail)
		A.pin(table, card, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-260, -160, 260, 160))
		if broke:
			var refill := K.action("Free refill", "primary", 220)
			refill.pressed.connect(func() -> void: intent.emit("refill", null))
			(card.get_child(0) as VBoxContainer).add_child(refill)
		_seats_only(table)
	else:
		_table(table)
	var msg := _note if _note != "" and Time.get_ticks_msec() / 1000.0 < _note_until else ""
	if msg == "" and phase == "showdown":
		msg = str(state.get("result", ""))
	elif msg == "" and state.get("starting", false):
		msg = "Next hand in %ds" % int(ceil(float(state.get("left", 0))))
	elif msg == "" and str(state.get("my_hand", "")) != "":
		msg = "You have: %s" % state["my_hand"]
	if msg != "":
		var m := A.label(msg, 19, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(m)
	var acts := A.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(acts)
	var legal: Array = state.get("legal", [])
	var mine := int(state.get("turn_seat", -1)) >= 0 and int(state.get("turn_seat", -1)) == int(state.get("my_seat", -1))
	for a in [["fold", "Fold"], ["check", "Check"], ["call", "Call %d" % int(state.get("to_call", 0))], ["raise", "Raise to %d" % _raise_to]]:
		var kind: String = a[0]
		var b := K.action(a[1], "secondary" if kind in ["fold", "check"] else "primary", 200 if kind == "raise" else 150)
		b.disabled = not (mine and kind in legal)
		b.tooltip_text = "" if not b.disabled else ("Not your turn" if not mine else "Not allowed right now")
		b.pressed.connect(_act.bind(kind))
		if kind == "call" and int(state.get("to_call", 0)) >= int(state.get("stack", 1 << 30)):
			b.text = "ALL IN %d" % int(state.get("to_call", 0))
		acts.add_child(b)
	if mine and "raise" in legal:
		var s := HSlider.new()
		s.custom_minimum_size = Vector2(180, 0)
		s.min_value = int(state.get("min_raise", 0))
		s.max_value = int(state.get("max_raise", 0))
		s.step = 1
		s.value = _raise_to
		s.value_changed.connect(func(val: float) -> void: _raise_to = int(val); (acts.get_child(3) as Button).text = "RAISE TO %d" % _raise_to)
		acts.add_child(s)
	var leave := K.action("Leave", "secondary", 150)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)


func _act(kind: String) -> void:
	var legal: Array = state.get("legal", [])
	if not kind in legal:
		return
	var amt := 0
	if kind == "raise":
		amt = clampi(_raise_to, int(state.get("min_raise", 0)), int(state.get("max_raise", 0)))
	intent.emit(kind, {"amount": amt})


func _table(table: Control) -> void:
	var board := A.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	A.pin(table, board, Vector4(0.5, 0.42, 0.5, 0.42), Vector4(-240, -60, 240, 60))
	var cards: Array = state.get("board", [])
	for i in 5:
		if i < cards.size():
			board.add_child(K.card(str(cards[i][0]), str(cards[i][1]), true, 76))
		else:
			var slot := PanelContainer.new()
			slot.custom_minimum_size = Vector2(76, 106)
			slot.add_theme_stylebox_override("panel", A.box(Color(1, 1, 1, 0.08), 8, 2, Color(1, 1, 1, 0.25), 0))
			board.add_child(slot)
	var pot := A.chip("Pot  %d" % int(state.get("pot", 0)), Color(0, 0, 0, 0.25), A.WHITE, "", 20, Vector2(16, 6))
	A.pin(table, pot, Vector4(0.17, 0.42, 0.17, 0.42), Vector4(-70, -20, 70, 20))
	var hole := A.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	A.pin(table, hole, Vector4(0.5, 0.78, 0.5, 0.78), Vector4(-80, -54, 80, 54))
	for c in state.get("hole", []):
		hole.add_child(K.card(str(c[0]), str(c[1]), true, 64))
	var seats: Array = state.get("seats", [])
	# rotated so your seat is always at the bottom, the rest clockwise around the felt
	var spots := [Vector2(0.5, 0.95), Vector2(0.1, 0.72), Vector2(0.1, 0.16), Vector2(0.5, -0.02), Vector2(0.9, 0.16), Vector2(0.9, 0.72)]
	for i in seats.size():
		var st: Dictionary = seats[i] if seats[i] is Dictionary else {}
		if st.is_empty() or i == int(state.get("my_seat", 0)):
			continue
		var p: Vector2 = spots[posmod(i - maxi(0, int(state.get("my_seat", 0))), spots.size())]
		var box := A.vbox(2)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		A.pin(table, box, Vector4(p.x, p.y, p.x, p.y), Vector4(-60, -66, 60, 66))
		var pv := PenguinView.new()
		pv.framing = "portrait"
		pv.custom_minimum_size = Vector2(100, 84)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.modulate = Color(1, 1, 1, 0.45 if st.get("folded", false) else 1.0)
		box.add_child(pv)
		pv.call_deferred("set_look", Net.coat_color(int(st.get("body", 0))), st.get("outfit", {}))
		var active := i == int(state.get("turn_seat", -1))
		var tag := A.chip("%s  %d" % [str(st.get("name", "")), int(st.get("chips", 0))], A.TEAL if active else A.WHITE, A.WHITE if active else A.NAVY, "", 15, Vector2(10, 3))
		box.add_child(tag)
		var extra := str(st.get("hand", "")) if st.has("hand") else str(st.get("last", ""))
		if st.get("button", false):
			extra = ("D  " + extra).strip_edges()
		if int(st.get("bet", 0)) > 0 and not st.has("hand"):
			extra += "  (%d)" % int(st.get("bet", 0))
		if extra != "":
			box.add_child(A.label(extra, 14, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
		if active:
			var ring := TurnRing.new()
			ring.frac = float(state.get("turn_left_s", 0)) / maxf(1.0, float(state.get("turn_total_s", 1)))
			ring.custom_minimum_size = Vector2(110, 110)
			A.pin(box, ring, Vector4(0.5, 0, 0.5, 0), Vector4(-55, -18, 55, 92))
		var backs := A.hbox(-30 if not st.has("shown") else 2, BoxContainer.ALIGNMENT_CENTER)
		var shown: Array = st.get("shown", [])
		for k in int(st.get("cards", 0)):   # hidden: counts only; values only once shown at showdown
			backs.add_child(K.card(str(shown[k][0]), str(shown[k][1]), true, 34) if k < shown.size() else K.card("", "", false, 30))
		box.add_child(backs)
	var me := int(state.get("my_seat", -1))
	if me >= 0 and int(state.get("turn_seat", -1)) == me:
		var ring := TurnRing.new()
		ring.frac = float(state.get("turn_left_s", 0)) / maxf(1.0, float(state.get("turn_total_s", 1)))
		A.pin(table, ring, Vector4(0.5, 0.78, 0.5, 0.78), Vector4(-96, -96, 96, 96))
		var t := A.chip("Your turn  %ds" % int(state.get("turn_left_s", 0)), A.CORAL_SOFT, Color("#D4483A"), "clock", 17, Vector2(12, 4))
		A.pin(table, t, Vector4(0.5, 1, 0.5, 1), Vector4(-90, -40, 90, -4))


## Waiting room: just who's seated.
func _seats_only(table: Control) -> void:
	var names := []
	for st in state.get("seats", []):
		if st is Dictionary and not st.is_empty():
			names.append("%s (%d)" % [st.get("name", ""), int(st.get("chips", 0))])
	if not names.is_empty():
		A.pin(table, A.label("At the table: " + ", ".join(names), 16, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER), Vector4(0, 1, 1, 1), Vector4(10, -36, -10, -6))


func close() -> void:
	intent.emit("leave", null)


func preview(s: String) -> void:
	var seats := [
		{"name": "You", "body": 0, "chips": 340, "cards": 2},
		{"name": "Pip", "body": 3, "chips": 180, "cards": 2},
		{"name": "Milo", "body": 1, "chips": 260, "cards": 2},
		{"name": "Coco", "body": 4, "chips": 95, "cards": 0, "folded": true},
		{"name": "Bea", "body": 2, "chips": 410, "cards": 2},
	]
	var base := {"phase": "betting", "balance": 340, "pot": 120, "board": [["Q", "spades"], ["8", "hearts"], ["3", "clubs"], ["J", "diamonds"], ["6", "hearts"]],
		"hole": [["A", "hearts"], ["10", "spades"]], "to_call": 20, "min_raise": 40, "max_raise": 340,
		"legal": ["fold", "call", "raise"], "turn_seat": 0, "my_seat": 0, "turn_left_s": 14, "turn_total_s": 20, "seats": seats}
	match s:
		"reconnecting", "waiting", "full":
			base["phase"] = s
		"not_turn":
			base["turn_seat"] = 2
	apply_state(base)


class TurnRing:
	extends Control
	var frac := 1.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.25), 6, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0, 1), 48, Color("#F2C230"), 6, true)
