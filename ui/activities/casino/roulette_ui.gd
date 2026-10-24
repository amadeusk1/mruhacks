extends Control
## Roulette betting board (Images/Casino - Game UI Mockups.png, roulette tile). The 3D wheel stays
## visible above it (casino_table_fx.gd spins it for everyone); the host draws the pocket.
## Pick a chip, tap spots to stack pending chips, PLACE sends them (accepted chips turn solid),
## UNDO clears pending chips or takes back your last placed batch until the betting closes.
##   apply_state({phase: "betting"|"spinning"|"result"|"idle"|"reconnecting", left, pocket, history,
##                bets: {spot: chips} (accepted, mine), table_bets, staked, result: {staked, won}, balance})
##   intent("bet", {bets: [[spot, chips], ...]})   intent("undo", null)   intent("leave", null)
## Spots: n0..n36, red, black, odd, even, d1/d2/d3.

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")
const R := preload("res://scripts/casino/casino_rules.gd")

var blocks_world := true
var live := false
var state := {}
var _chip := 1          # index into K.CHIP_VALUES
var _pending := {}      # spot -> chips not yet placed
var _root: Control
var _note := ""
var _note_until := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.is_empty() and not live:
		preview("betting")


func apply_state(s: Dictionary) -> void:
	if str(s.get("phase", "")) != "betting":
		_pending.clear()
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
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var fr := K.frame()
	A.pin(_root, fr, Vector4(0.5, 1, 0.5, 1), Vector4(-620, -372, 620, -10))
	var v := A.vbox(6)
	fr.add_child(v)
	var phase := str(state.get("phase", ""))
	var left := int(ceil(float(state.get("left", 0))))
	var status := {"betting": "Betting open  %s" % _clock(left), "spinning": "No more bets", "result": "Next spin  %s" % _clock(left),
		"idle": "Take a seat to play"}.get(phase, "Connecting...") as String
	v.add_child(K.header("Roulette", "%s     Play chips: %d" % [status, int(state.get("balance", 0))]))
	var felt := K.felt(12)
	v.add_child(felt)
	var row := A.hbox(16)
	felt.add_child(row)
	row.add_child(_side(phase))
	row.add_child(_board(phase == "betting"))
	var acts := A.hbox(14, BoxContainer.ALIGNMENT_END)
	v.add_child(acts)
	var msg := _message(phase)
	var m := A.label(msg, 19, A.NAVY, true)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acts.add_child(m)
	var undo := K.action("Undo", "secondary", 150)
	undo.disabled = phase != "betting" or (_pending.is_empty() and (state.get("bets", {}) as Dictionary).is_empty())
	undo.pressed.connect(_undo)
	acts.add_child(undo)
	var place := K.action("Place", "primary", 220)
	var cost := _pending_total()
	place.disabled = phase != "betting" or _pending.is_empty() or cost > int(state.get("balance", 0))
	place.tooltip_text = "Not enough play chips" if cost > int(state.get("balance", 0)) else ""
	place.pressed.connect(_place)
	acts.add_child(place)
	var leave := K.action("Leave", "secondary", 150)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)
	if phase == "reconnecting":
		A.pin(_root, K.state_card("reconnecting"), Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-230, -150, 230, 150))
	elif int(state.get("balance", 0)) < 1 and int(state.get("staked", 0)) == 0 and phase in ["betting", "idle"]:
		_broke()


func _message(phase: String) -> String:
	if _note != "" and Time.get_ticks_msec() / 1000.0 < _note_until:
		return _note
	var res: Dictionary = state.get("result", {})
	var pocket := int(state.get("pocket", -1))
	match phase:
		"spinning":
			return "Spinning... you have %d chips on the table." % int(state.get("staked", 0)) if int(state.get("staked", 0)) > 0 else "Spinning..."
		"result":
			var head := "%d %s" % [pocket, R.roulette_color(pocket).capitalize()]
			if res.is_empty():
				return head
			var won := int(res.get("won", 0))
			return "%s  ·  you won %d!" % [head, won] if won > 0 else "%s  ·  no luck this spin" % head
		"betting":
			if not _pending.is_empty():
				return "%d chips ready. Press PLACE." % _pending_total()
			return "Tap the board to bet. %d on the table." % int(state.get("staked", 0)) if int(state.get("staked", 0)) > 0 else "Pick a chip, tap the board."
	return ""


func _side(phase: String) -> Control:
	var col := A.vbox(8)
	col.custom_minimum_size = Vector2(250, 0)
	col.add_child(A.label("Last results", 16, Color(1, 1, 1, 0.8), true))
	var hist := A.hbox(4)
	for p in (state.get("history", []) as Array).slice(0, 7):
		hist.add_child(_pocket_chip(int(p), 30))
	col.add_child(hist)
	if phase in ["spinning", "result"] and int(state.get("pocket", -1)) >= 0 and phase == "result":
		var big := A.hbox(8)
		big.add_child(_pocket_chip(int(state["pocket"]), 56))
		col.add_child(big)
	col.add_child(A.expander())
	col.add_child(A.label("Play chip:", 16, A.WHITE, true))
	var chips := A.hbox(6)
	for i in K.CHIP_VALUES.size():
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(42, 42)
		b.tooltip_text = "%d chips" % K.CHIP_VALUES[i]
		b.focus_mode = Control.FOCUS_ALL
		var dot := K.chip(i, 40, i == _chip)
		b.add_child(dot)
		var t := A.label(str(K.CHIP_VALUES[i]), 12, A.NAVY if i == 0 else A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(t)
		b.pressed.connect(func() -> void:
			_chip = i
			_build())
		chips.add_child(b)
	col.add_child(chips)
	return col


func _pocket_chip(n: int, px: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(px, px)
	p.add_theme_stylebox_override("panel", A.box(_swatch(R.roulette_color(n)), px / 2, 2, Color(1, 1, 1, 0.7), 0))
	var l := A.label(str(n), int(px * 0.45), A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _board(open: bool) -> Control:
	var g := GridContainer.new()
	g.columns = 1
	var wrap := A.hbox(0)
	var zero := _cell("n0", "0", Vector2(52, 150), open)
	wrap.add_child(zero)
	var right := A.vbox(0)
	wrap.add_child(right)
	var nums := GridContainer.new()
	nums.columns = 12
	nums.add_theme_constant_override("h_separation", 0)
	nums.add_theme_constant_override("v_separation", 0)
	for r in 3:
		for col in 12:
			var n := col * 3 + (3 - r)
			nums.add_child(_cell("n%d" % n, str(n), Vector2(56, 50), open))
	right.add_child(nums)
	var dozens := A.hbox(0)
	for d in 3:
		dozens.add_child(_cell("d%d" % (d + 1), ["1 - 12", "13 - 24", "25 - 36"][d], Vector2(224, 40), open))
	right.add_child(dozens)
	var outs := A.hbox(0)
	for o in ["red", "black", "odd", "even"]:
		outs.add_child(_cell(o, o.to_upper(), Vector2(168, 40), open))
	right.add_child(outs)
	return wrap


func _cell(spot: String, text: String, sz: Vector2, open: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = not open
	var bg := K.FELT_DARK
	if spot.begins_with("n"):
		bg = _swatch(R.roulette_color(int(spot.substr(1))))
	elif spot == "red":
		bg = _swatch("red").darkened(0.1)
	elif spot == "black":
		bg = _swatch("black")
	var lit: bool = int(state.get("pocket", -1)) >= 0 and str(state.get("phase", "")) == "result" and R.roulette_return(spot, int(state["pocket"])) > 0
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := A.box(bg.lightened(0.15) if st == "hover" else bg, 2, 2 if not lit else 4, Color("#F2C230") if lit else Color(1, 1, 1, 0.55), 0)
		if st == "focus":
			sb.draw_center = false
			sb.border_color = Color("#F2C230")
		b.add_theme_stylebox_override(st, sb)
	for cname in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		b.add_theme_color_override(cname, A.WHITE)
	b.add_theme_font_size_override("font_size", 18 if spot.begins_with("n") else 16)
	b.pressed.connect(func() -> void:
		_pending[spot] = int(_pending.get(spot, 0)) + int(K.CHIP_VALUES[_chip])
		CasinoSfx.play(self, "chip", -12.0)
		_build())
	var mine := int((state.get("bets", {}) as Dictionary).get(spot, 0))
	var pend := int(_pending.get(spot, 0))
	var others := int((state.get("table_bets", {}) as Dictionary).get(spot, 0)) - mine
	if mine + pend > 0 or others > 0:
		var tag := PanelContainer.new()
		var solid := mine > 0
		tag.add_theme_stylebox_override("panel", A.box(Color("#F2C230") if solid else Color(1, 1, 1, 0.85), 10, 0, Color.TRANSPARENT, 0))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var amount := mine + pend if mine + pend > 0 else others
		var l := A.label(str(amount), 12, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(26, 0)
		tag.add_child(l)
		tag.modulate.a = 1.0 if (mine + pend > 0) else 0.55
		b.add_child(tag)
		tag.position = Vector2(sz.x - 30, 2)
	return b


func _place() -> void:
	if _pending.is_empty():
		return
	var list := []
	for spot in _pending:
		var left := int(_pending[spot])
		for i in range(K.CHIP_VALUES.size() - 1, -1, -1):  # break into table chips
			while left >= int(K.CHIP_VALUES[i]):
				list.append([spot, int(K.CHIP_VALUES[i])])
				left -= int(K.CHIP_VALUES[i])
	_pending.clear()
	intent.emit("bet", {"bets": list})
	_build()


func _undo() -> void:
	if not _pending.is_empty():
		_pending.clear()
		_build()
		return
	intent.emit("undo", null)


func _broke() -> void:
	var card := K.state_card("insufficient", "Your purse is empty. Grab a free refill of play chips.")
	A.pin(_root, card, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-240, -170, 240, 170))
	var b := K.action("Free refill", "primary", 220)
	b.pressed.connect(func() -> void: intent.emit("refill", null))
	(card.get_child(0) as VBoxContainer).add_child(b)


func _pending_total() -> int:
	var n := 0
	for s in _pending:
		n += int(_pending[s])
	return n


func _clock(sec: int) -> String:
	return "%02d:%02d" % [sec / 60, sec % 60]


func close() -> void:
	intent.emit("leave", null)


static func _swatch(color: String) -> Color:
	match color:
		"red":
			return Color("#D6453C")
		"green":
			return Color("#2E9E5E")
		_:
			return Color("#232733")


func preview(s: String) -> void:
	match s:
		"result":
			apply_state({"phase": "result", "left": 3, "pocket": 17, "history": [17, 4, 0, 32, 21], "bets": {"n17": 10, "red": 5},
				"result": {"staked": 15, "won": 360}, "balance": 820})
		_:
			apply_state({"phase": "betting", "left": 12, "pocket": -1, "history": [4, 0, 32, 21, 15], "bets": {"red": 10, "n17": 5},
				"table_bets": {"red": 35, "n17": 5, "d2": 25}, "staked": 15, "balance": 340})
