extends Control
## Roulette (single zero). State in / intent out; the server spins and settles.
##   apply_state({phase: "open"|"locked"|"spinning"|"result", seconds_left, balance,
##                accepted: [{bet, amount}], last_results: [int], result: int})
##   intent("place_bets", [{bet, amount}])   pending bets -> server (accepted ones come back in state)
##   intent("cancel_bet", {bet, amount})     undo an ACCEPTED bet; only offered while betting is open
##   intent("leave", null)
## bet ids: "n<0-36>", "dozen1|2|3", "red", "black", "odd", "even".

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const WHEEL := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]

var state := {"phase": "open", "seconds_left": 12, "balance": 340, "accepted": [], "last_results": [17, 4, 32, 0, 21], "result": -1}
var _chip := 2
var _pending: Array = []
var _root: Control
var _cells := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func apply_state(s: Dictionary) -> void:
	state.merge(s, true)
	if str(state["phase"]) != "open":
		_pending.clear()   # late bets are rejected by the server; never keep them looking placed
	_build()


static func color_of(n: int) -> String:
	return "green" if n == 0 else ("red" if n in REDS else "black")


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	var fr := K.frame()
	A.pin(_root, fr, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-620, -300, 620, 300))
	var v := A.vbox(8)
	fr.add_child(v)
	var phase := str(state["phase"])
	var status := {"open": "Betting open   %s" % _mmss(int(state.get("seconds_left", 0))), "locked": "Bets locked",
		"spinning": "Spinning...", "result": "Result: %d %s" % [int(state.get("result", 0)), color_of(int(state.get("result", 0))).to_upper()]}.get(phase, phase) as String
	var head := K.header("Roulette", "%s     Play chips: %d" % [status, _balance_left()])
	v.add_child(head)
	var felt := K.felt(14)
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(felt)
	var row := A.hbox(16)
	felt.add_child(row)
	var left := A.vbox(10)
	left.custom_minimum_size.x = 300
	row.add_child(left)
	var wheel := RouletteWheel.new()
	wheel.custom_minimum_size = Vector2(300, 300)
	wheel.result = int(state.get("result", -1)) if phase == "result" else -1
	wheel.spinning = phase == "spinning"
	left.add_child(wheel)
	left.add_child(A.label("Play chip:", 19, A.WHITE, true))
	var chips := A.hbox(10)
	left.add_child(chips)
	for i in K.CHIP_VALUES.size():
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(52, 52)
		b.tooltip_text = "%d chip" % K.CHIP_VALUES[i]
		b.disabled = phase != "open" or K.CHIP_VALUES[i] > _balance_left()
		b.add_child(K.chip(i, 48, i == _chip))
		(b.get_child(0) as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lbl := A.label(str(K.CHIP_VALUES[i]), 13, A.NAVY if i == 0 else A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(lbl)
		b.pressed.connect(func() -> void: _chip = i; _build())
		chips.add_child(b)
	var right := A.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_board(phase == "open"))
	right.add_child(_last_results())
	right.add_child(A.expander())
	var acts := A.hbox(14, BoxContainer.ALIGNMENT_END)
	right.add_child(acts)
	var undo := K.action("Undo", "secondary", 170)
	undo.disabled = phase != "open" or (_pending.is_empty() and (state.get("accepted", []) as Array).is_empty())
	undo.pressed.connect(_undo)
	acts.add_child(undo)
	var place := K.action("Place", "primary", 260)
	place.disabled = phase != "open" or _pending.is_empty()
	place.pressed.connect(func() -> void: intent.emit("place_bets", _pending.duplicate(true)))
	acts.add_child(place)
	var leave := K.action("Leave", "secondary", 170)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)
	if phase == "open" and K.CHIP_VALUES[0] > _balance_left():
		var st := K.state_card("insufficient")
		A.pin(_root, st, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-230, -170, 230, 170))


func _balance_left() -> int:
	var b := int(state.get("balance", 0))
	for p in _pending:
		b -= int(p["amount"])
	return b


func _bet_total(bet: String) -> Vector2i:   # (accepted, pending)
	var acc := 0
	for a in state.get("accepted", []):
		if a["bet"] == bet: acc += int(a["amount"])
	var pen := 0
	for p in _pending:
		if p["bet"] == bet: pen += int(p["amount"])
	return Vector2i(acc, pen)


func _add_bet(bet: String) -> void:
	if str(state["phase"]) != "open":
		return
	var amt: int = K.CHIP_VALUES[_chip]
	if amt > _balance_left():
		return
	_pending.append({"bet": bet, "amount": amt})
	_build()


func _undo() -> void:
	if not _pending.is_empty():
		_pending.pop_back()
	else:
		var acc: Array = state.get("accepted", [])
		if not acc.is_empty() and str(state["phase"]) == "open":
			intent.emit("cancel_bet", acc.back())
	_build()


func _cell(text: String, bet: String, bg: Color, w: float, h: float, enabled: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.text = text
	b.tooltip_text = bet
	b.add_theme_font_override("font", A.title_font())
	b.add_theme_font_size_override("font_size", 23 if text.length() <= 2 else 19)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, A.WHITE)
	var sb := A.box(bg, 3, 1, Color(1, 1, 1, 0.75), 0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)
	var hv := A.box(bg.lightened(0.15), 3, 2, A.WHITE, 0)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 3, 3, Color("#F2C230"), 0))
	b.disabled = not enabled
	b.pressed.connect(_add_bet.bind(bet))
	var tot := _bet_total(bet)
	if tot.x + tot.y > 0:   # chip marker: solid = accepted, dashed ring = pending
		var mark := K.chip(_chip if tot.y > 0 else 2, 32, false)
		mark.modulate = Color(1, 1, 1, 1.0 if tot.x > 0 else 0.65)
		A.pin(b, mark, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-16, -16, 16, 16))
	return b


func _board(enabled: bool) -> Control:
	var grid := A.vbox(0)
	var top := A.hbox(0)
	grid.add_child(top)
	var zero := _cell("0", "n0", Color("#2E8B57"), 62, 3 * 62, enabled)
	top.add_child(zero)
	var nums := GridContainer.new()
	nums.columns = 12
	nums.add_theme_constant_override("h_separation", 0)
	nums.add_theme_constant_override("v_separation", 0)
	top.add_child(nums)
	for r in 3:
		for c in 12:
			var n := c * 3 + (3 - r)   # top row 3,6..36 / middle 2,5..35 / bottom 1,4..34
			nums.add_child(_cell(str(n), "n%d" % n, K.RED if n in REDS else K.BLACK, 60, 62, enabled))
	var doz := A.hbox(0)
	grid.add_child(doz)
	doz.add_child(A.spacer(62, 0))
	for d in [["1 - 12", "dozen1"], ["13 - 24", "dozen2"], ["25 - 36", "dozen3"]]:
		doz.add_child(_cell(d[0], d[1], K.FELT_DARK, 60 * 4, 50, enabled))
	var even := A.hbox(0)
	grid.add_child(even)
	even.add_child(A.spacer(62, 0))
	for d in [["RED", "red", K.RED], ["BLACK", "black", K.BLACK], ["ODD", "odd", K.FELT_DARK], ["EVEN", "even", K.FELT_DARK]]:
		even.add_child(_cell(d[0], d[1], d[2], 60 * 3, 50, enabled))
	return grid


func _last_results() -> Control:
	var h := A.hbox(8)
	h.add_child(A.label("Last:", 18, A.WHITE, true))
	for n in state.get("last_results", []):
		var col := {"red": K.RED, "black": K.BLACK, "green": Color("#2E8B57")}[color_of(int(n))] as Color
		var c := A.chip(str(n), col, A.WHITE, "", 17, Vector2(12, 4))
		h.add_child(c)
	return h


static func _mmss(s: int) -> String:
	return "%02d:%02d" % [s / 60, s % 60]


func close() -> void:
	intent.emit("leave", null)
	queue_free()


func preview(s: String) -> void:
	match s:
		"result":
			apply_state({"phase": "result", "result": 17, "accepted": [{"bet": "n17", "amount": 10}]})
		"broke":
			apply_state({"phase": "open", "balance": 0})
		_:
			_pending = [{"bet": "n14", "amount": 10}, {"bet": "red", "amount": 25}]
			apply_state({"phase": "open", "accepted": [{"bet": "n23", "amount": 5}]})


class RouletteWheel:
	extends Control
	var result := -1
	var spinning := false
	var _ang := 0.0

	func _process(delta: float) -> void:
		if spinning:
			_ang += delta * 3.2
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4
		draw_circle(c, r, Color("#6B3E22"))
		draw_circle(c, r * 0.93, Color("#8A5530"))
		var n := WHEEL.size()
		var r1 := r * 0.88
		var r0 := r * 0.62
		var off := _ang
		if result >= 0:
			off = -TAU * float(WHEEL.find(result)) / n - PI * 0.5   # winning pocket at the top
		for i in n:
			var a0 := off + TAU * i / n
			var a1 := off + TAU * (i + 1) / n
			var num: int = WHEEL[i]
			var col := Color("#2E8B57") if num == 0 else (CasinoKit.RED if num in REDS else CasinoKit.BLACK)
			var pts := PackedVector2Array()
			for k in 5:
				var a := lerpf(a0, a1, k / 4.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r1)
			for k in 5:
				var a := lerpf(a1, a0, k / 4.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r0)
			draw_colored_polygon(pts, col)
		draw_circle(c, r0, Color("#9A6237"))
		draw_circle(c, r * 0.36, Color("#C98A45"))
		draw_circle(c, r * 0.12, Color("#E2B45A"))
		for k in 4:
			var a := off * 0.3 + TAU * k / 4.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.34, Color("#E2B45A"), 6)
		if result >= 0:
			draw_circle(c + Vector2(0, -r * 0.8), r * 0.05, Color.WHITE)
			draw_string(CasinoKit.A.title_font(), c + Vector2(-r, r * 0.12), str(result), HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 0.22), Color("#3B2210"))
