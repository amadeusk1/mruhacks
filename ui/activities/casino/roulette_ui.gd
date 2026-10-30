extends Control
## Roulette screen in two modes, picked when you first sit (remembered in user://casino.cfg, and
## switchable from the board):
##   Simple: three big buttons, RED / GREEN / BLACK. Tap one to bet the chosen chip on it right away.
##           Red and black pay x2, green (the 0) pays x36.
##   Normal: the full betting board (Images/Casino - Game UI Mockups.png, roulette tile). Pick a chip,
##           tap spots to stack pending chips, PLACE sends them (accepted chips turn solid).
## UNDO takes back your last placed bet until the betting closes. While the ball spins the board
## folds into a side card with a drawn wheel (roulette_wheel.gd), so the spin is always in view
## along with the 3D table wheel (casino_table_fx.gd spins it for everyone); the host draws the pocket.
##   apply_state({phase: "betting"|"spinning"|"result"|"idle"|"reconnecting", left, pocket, history,
##                spin_id, spin_left, bets: {spot: chips} (accepted, mine), table_bets, staked,
##                result: {staked, won}, balance})
##   intent("bet", {bets: [[spot, chips], ...]})   intent("undo", null)   intent("leave", null)
## Spots: n0..n36, red, black, green, odd, even, d1/d2/d3.

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")
const R := preload("res://scripts/casino/casino_rules.gd")
const Sfx := preload("res://scripts/casino/casino_sfx.gd")
const Wheel := preload("res://ui/activities/casino/roulette_wheel.gd")
const CFG := "user://casino.cfg"
const SIMPLE_SPOTS := [["red", "RED", "pays x2"], ["green", "GREEN", "pays x36"], ["black", "BLACK", "pays x2"]]

var blocks_world := true
var live := false
var state := {}
var mode := saved_mode()  # "" (not picked yet) | simple | normal
var _chip := 1          # index into K.CHIP_VALUES
var _pending := {}      # spot -> chips not yet placed
var _root: Control
var _wheel: Control     # kept across rebuilds so a spin isn't cut short
var _spin_id := -1
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
	_sync_wheel()
	_build()


func set_mode(m: String) -> void:
	mode = m
	_pending.clear()
	var cf := ConfigFile.new()
	cf.load(CFG)
	cf.set_value("roulette", "mode", m)
	cf.save(CFG)
	_build()


static func saved_mode() -> String:
	var cf := ConfigFile.new()
	if cf.load(CFG) != OK:
		return ""
	var m := str(cf.get_value("roulette", "mode", ""))
	return m if m in ["simple", "normal"] else ""


static func forget_mode() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG) == OK and cf.has_section_key("roulette", "mode"):
		cf.erase_section_key("roulette", "mode")
		cf.save(CFG)


## Start the drawn wheel on a new spin (joining mid-spin catches up), or rest it on the last pocket.
func _sync_wheel() -> void:
	if _wheel == null:
		_wheel = Wheel.new()
	var phase := str(state.get("phase", ""))
	var pocket := int(state.get("pocket", -1))
	if phase == "spinning" and pocket >= 0 and int(state.get("spin_id", -1)) != _spin_id:
		_spin_id = int(state.get("spin_id", -1))
		_wheel.call("spin_to", pocket, float(state.get("spin_left", 6.0)) - 0.3)
	elif phase != "spinning":
		var hist: Array = state.get("history", [])
		_wheel.call("rest_on", pocket if pocket >= 0 else (int(hist[0]) if not hist.is_empty() else -1))


## Moves the persistent wheel into this rebuild's layout.
func _wheel_in(px: int) -> Control:
	if _wheel == null:
		_sync_wheel()
	if _wheel.get_parent():
		_wheel.get_parent().remove_child(_wheel)
	_wheel.custom_minimum_size = Vector2(px, px)
	_wheel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return _wheel


func notice(message: String) -> void:
	_note = message
	_note_until = Time.get_ticks_msec() / 1000.0 + 4.0
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_wheel) and _wheel.get_parent() == null:
		_wheel.free()


func _build() -> void:
	if _root:
		_root.queue_free()
	if is_instance_valid(_wheel) and _wheel.get_parent():
		_wheel.get_parent().remove_child(_wheel)
	_root = A.screen_root()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var phase := str(state.get("phase", ""))
	if mode == "":
		_picker()
	elif phase == "spinning":
		_spin_card()
	elif mode == "simple":
		_simple()
	else:
		_normal(phase)
	if phase == "reconnecting":
		A.pin(_root, K.state_card("reconnecting"), Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-230, -150, 230, 150))
	elif mode != "" and int(state.get("balance", 0)) < 1 and int(state.get("staked", 0)) == 0 and phase in ["betting", "idle"]:
		_broke()


func _status() -> String:
	var left := int(ceil(float(state.get("left", 0))))
	var status := {"betting": "Betting open  %s" % _clock(left), "spinning": "No more bets", "result": "Next spin  %s" % _clock(left),
		"idle": "Take a seat to play"}.get(str(state.get("phase", "")), "Connecting...") as String
	return "%s     Play chips: %d" % [status, int(state.get("balance", 0))]


## First visit: pick how to play. The wheel stays in view behind the card.
func _picker() -> void:
	var p := K.frame()
	A.pin(_root, p, Vector4(0.5, 1, 0.5, 1), Vector4(-430, -330, 430, -8))
	var v := A.vbox(10)
	p.add_child(v)
	v.add_child(K.header("Roulette", "How do you want to play?", false))
	var row := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(row)
	for opt in [["simple", "Simple", "Bet on Red, Black or Green.\nRed and Black pay x2, Green pays x36."],
			["normal", "Normal", "The full table: single numbers,\ndozens, odd / even, red / black."]]:
		var col := A.vbox(8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := K.action(opt[1], "primary" if opt[0] == "simple" else "secondary", 300)
		b.pressed.connect(set_mode.bind(opt[0]))
		col.add_child(b)
		var d := A.label(opt[2], 17, A.NAVY, false, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(d)
		row.add_child(col)
	var foot := A.hbox(10, BoxContainer.ALIGNMENT_END)
	foot.add_child(A.label("You can switch any time from the table.", 16, A.SUB))
	foot.add_child(A.expander())
	var leave := K.action("Leave", "secondary", 150)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	foot.add_child(leave)
	v.add_child(foot)


## Ball in motion: the board folds into a card at the side so the table wheel shows, with the drawn
## wheel in the card spinning onto the same pocket.
func _spin_card() -> void:
	var p := K.frame()
	A.pin(_root, p, Vector4(1, 1, 1, 1), Vector4(-440, -420, -8, -8))
	var v := A.vbox(6)
	p.add_child(v)
	v.add_child(K.header("Roulette", "No more bets!", false))
	var felt := K.felt(10)
	v.add_child(felt)
	var c := CenterContainer.new()
	c.add_child(_wheel_in(250))
	felt.add_child(c)
	var row := A.hbox(10)
	v.add_child(row)
	var m := A.label(_message("spinning"), 18, A.NAVY, true)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(m)
	var leave := K.action("Leave", "secondary", 130)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	row.add_child(leave)


## Simple mode: wheel on the left, three big colour buttons. One tap = one chip on that colour.
func _simple() -> void:
	var phase := str(state.get("phase", ""))
	var open := phase == "betting"
	var fr := K.frame()
	A.pin(_root, fr, Vector4(0.5, 1, 0.5, 1), Vector4(-540, -400, 540, -8))
	var v := A.vbox(6)
	fr.add_child(v)
	v.add_child(K.header("Roulette", _status()))
	var felt := K.felt(12)
	v.add_child(felt)
	var row := A.hbox(18)
	felt.add_child(row)
	row.add_child(_wheel_in(210))
	var right := A.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var hist := A.hbox(4)
	hist.add_child(A.label("Last:", 16, Color(1, 1, 1, 0.8), true))
	for h in (state.get("history", []) as Array).slice(0, 10):
		hist.add_child(_pocket_chip(int(h), 28))
	right.add_child(hist)
	var bets := A.hbox(12)
	bets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(bets)
	for s in SIMPLE_SPOTS:
		bets.add_child(_color_button(s[0], s[1], s[2], open))
	var acts := A.hbox(12)
	v.add_child(acts)
	var chips := A.hbox(4)
	for i in K.CHIP_VALUES.size():
		chips.add_child(_chip_button(i))
	acts.add_child(chips)
	var m := A.label(_message(phase), 18, A.NAVY, true)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acts.add_child(m)
	var undo := K.action("Undo", "secondary", 130)
	undo.disabled = not open or (state.get("bets", {}) as Dictionary).is_empty()
	undo.pressed.connect(_undo)
	acts.add_child(undo)
	acts.add_child(_mode_switch())
	var leave := K.action("Leave", "secondary", 130)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)


func _color_button(spot: String, text: String, pays: String, open: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(170 if spot == "green" else 200, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = not open or int(K.CHIP_VALUES[_chip]) > int(state.get("balance", 0))
	b.tooltip_text = "Bet %d on %s" % [K.CHIP_VALUES[_chip], text.capitalize()]
	var bg := _swatch(spot)
	var pocket := int(state.get("pocket", -1))
	var lit: bool = pocket >= 0 and str(state.get("phase", "")) == "result" and R.roulette_return(spot, pocket) > 0
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := A.box(bg.lightened(0.15) if st == "hover" else (bg.darkened(0.15) if st == "pressed" else bg), 18,
			6 if lit else 3, Color("#F2C230") if lit else Color(1, 1, 1, 0.6), 0)
		if st == "disabled" and not lit:
			sb.bg_color = bg.darkened(0.25)
		if st == "focus":
			sb.draw_center = false
			sb.border_color = Color("#F2C230")
		b.add_theme_stylebox_override(st, sb)
	var col := A.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(col)
	for l in [A.label(text, 30, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER), A.label(pays, 17, Color(1, 1, 1, 0.85), true, HORIZONTAL_ALIGNMENT_CENTER)]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	var mine := int((state.get("bets", {}) as Dictionary).get(spot, 0))
	var others := int((state.get("table_bets", {}) as Dictionary).get(spot, 0)) - mine
	var tag_text := "Your bet: %d" % mine if mine > 0 else ("Table: %d" % others if others > 0 else "")
	if tag_text != "":
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", A.box(Color("#F2C230") if mine > 0 else Color(1, 1, 1, 0.75), 10, 0, Color.TRANSPARENT, 4))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tl := A.label(tag_text, 15, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(tl)
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tag)
		col.add_child(c)
	b.pressed.connect(func() -> void:
		Sfx.play(self, "chip", -12.0)
		intent.emit("bet", {"bets": [[spot, int(K.CHIP_VALUES[_chip])]]}))
	return b


func _chip_button(i: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(46, 46)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = "Bet %d chips a tap" % K.CHIP_VALUES[i]
	b.focus_mode = Control.FOCUS_ALL
	var dot := K.chip(i, 44, i == _chip)
	b.add_child(dot)
	var t := A.label(str(K.CHIP_VALUES[i]), 12, A.NAVY if i == 0 else A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(t)
	b.pressed.connect(func() -> void:
		_chip = i
		_build())
	return b


func _mode_switch() -> Button:
	var to := "normal" if mode == "simple" else "simple"
	var b := K.action("%s mode" % to.capitalize(), "secondary", 200)
	b.add_theme_font_size_override("font_size", 19)
	b.tooltip_text = "Switch to the full table" if to == "normal" else "Switch to just Red, Black or Green"
	b.pressed.connect(set_mode.bind(to))
	return b


func _normal(phase: String) -> void:
	var fr := K.frame()
	A.pin(_root, fr, Vector4(0.5, 1, 0.5, 1), Vector4(-620, -446, 620, -8))
	var v := A.vbox(6)
	fr.add_child(v)
	v.add_child(K.header("Roulette", _status()))
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
	acts.add_child(_mode_switch())
	var leave := K.action("Leave", "secondary", 150)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)


func _message(phase: String) -> String:
	if _note != "" and Time.get_ticks_msec() / 1000.0 < _note_until:
		return _note
	var res: Dictionary = state.get("result", {})
	var pocket := int(state.get("pocket", -1))
	match phase:
		"spinning":
			var on := []
			var mine: Dictionary = state.get("bets", {})
			for spot in mine:
				on.append("%d on %s" % [int(mine[spot]), _spot_name(str(spot))])
			return "Spinning... you bet %s." % ", ".join(on) if not on.is_empty() else "Spinning... watch the wheel!"
		"result":
			var head := "%d %s" % [pocket, R.roulette_color(pocket).capitalize()]
			if res.is_empty():
				return head
			var won := int(res.get("won", 0))
			return "%s  ·  you won %d!" % [head, won] if won > 0 else "%s  ·  no luck this spin" % head
		"betting":
			if mode == "simple":
				return "%d on the table. Tap again to add more." % int(state.get("staked", 0)) if int(state.get("staked", 0)) > 0 else "Pick a chip, then tap a colour."
			if not _pending.is_empty():
				return "%d chips ready. Press PLACE." % _pending_total()
			return "Tap the board to bet. %d on the table." % int(state.get("staked", 0)) if int(state.get("staked", 0)) > 0 else "Pick a chip, tap the board."
	return ""


static func _spot_name(spot: String) -> String:
	if spot.begins_with("n"):
		return "#" + spot.substr(1)
	return {"d1": "1-12", "d2": "13-24", "d3": "25-36"}.get(spot, spot.capitalize())


func _side(phase: String) -> Control:
	var col := A.vbox(8)
	col.custom_minimum_size = Vector2(230, 0)
	col.add_child(A.label("Last results", 16, Color(1, 1, 1, 0.8), true))
	var hist := A.hbox(4)
	for p in (state.get("history", []) as Array).slice(0, 7):
		hist.add_child(_pocket_chip(int(p), 30))
	col.add_child(hist)
	var c := CenterContainer.new()
	c.add_child(_wheel_in(108))
	col.add_child(c)
	col.add_child(A.expander())
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
		Sfx.play(self, "chip", -12.0)
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
