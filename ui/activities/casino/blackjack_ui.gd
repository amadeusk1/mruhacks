extends Control
## Blackjack. Dealer's hole card stays face-down (and absent from state) until the reveal.
## Double / split only enabled when the server lists them as legal.
##   apply_state({phase: "betting"|"player"|"dealer"|"settled"|"waiting"|"reconnecting"|"full"|"insufficient",
##                left, turn_total, balance, bet, ready, min_bet, max_bet,
##                dealer: [[rank, suit] or null(hidden)], dealer_total (when revealed),
##                hands: [{cards: [[rank, suit]], total, soft, bet, result}], active_hand,
##                legal: ["hit","stand","double","split"], players: [{seat, name, bet, hands, turn}], my_seat})
##   intent(kind, {hand}) for hit/stand/double/split   intent("bet", {amount})   intent("clear"|"deal"|"leave", null)

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")

var state := {}
var live := false
var _root: Control
var _chip := 1
var _note := ""
var _note_until := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.is_empty() and not live:
		preview("player")


func apply_state(s: Dictionary) -> void:
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
	A.pin(_root, fr, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-560, -250, 560, 250))
	var v := A.vbox(8)
	fr.add_child(v)
	var phase := str(state.get("phase", ""))
	var left := int(ceil(float(state.get("left", 0))))
	var status := {"betting": "Place your bets  %ds" % left, "player": "Your turn  %ds" % left if int(state.get("active_hand", -1)) >= 0 else "Players' turn",
		"dealer": "Dealer's turn", "settled": "Round over", "waiting": "Waiting for players"}.get(phase, "") as String
	v.add_child(K.header("Blackjack", "%s     Play chips: %d" % [status, int(state.get("balance", 0))]))
	var felt := PanelContainer.new()
	felt.add_theme_stylebox_override("panel", A.box(K.FELT, 40, 12, K.WOOD, 24))
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(felt)
	var stack := Control.new()
	felt.add_child(stack)
	if phase == "betting" and int(state.get("balance", 0)) + int(state.get("bet", 0)) < int(state.get("min_bet", 5)):
		phase = "insufficient"
	if phase in ["waiting", "reconnecting", "full", "insufficient"]:
		var card := K.state_card(phase, "Sit tight: the next round starts as soon as bets are in." if phase == "waiting" else "")
		A.pin(stack, card, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-250, -150, 250, 150))
		if phase == "insufficient":
			var refill := K.action("Free refill", "primary", 220)
			refill.pressed.connect(func() -> void: intent.emit("refill", null))
			(card.get_child(0) as VBoxContainer).add_child(refill)
		_actions(v, [])
		return
	_others(stack)
	# dealer
	var drow := A.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	A.pin(stack, drow, Vector4(0.5, 0, 0.5, 0), Vector4(-240, 0, 240, 120))
	drow.add_child(A.label("Dealer", 22, A.WHITE, true))
	for c in state.get("dealer", []):
		drow.add_child(K.card(str(c[0]), str(c[1]), true, 70) if c != null else K.card("", "", false, 70))
	if state.has("dealer_total"):
		drow.add_child(_total(int(state["dealer_total"]), false))
	# player hands
	var hrow := A.hbox(40)
	A.pin(stack, hrow, Vector4(0, 1, 1, 1), Vector4(10, -170, -10, 0))
	var hands: Array = state.get("hands", [])
	for i in hands.size():
		var h: Dictionary = hands[i]
		var col := A.vbox(6)
		hrow.add_child(col)
		var cap := A.hbox(8)
		cap.add_child(A.label("Your hand" if hands.size() == 1 else "Hand %d" % (i + 1), 20, A.WHITE, true))
		cap.add_child(_total(int(h.get("total", 0)), bool(h.get("soft", false))))
		col.add_child(cap)
		var cards := A.hbox(8)
		for c in h.get("cards", []):
			cards.add_child(K.card(str(c[0]), str(c[1]), true, 72))
		col.add_child(cards)
		var res := str(h.get("result", ""))
		if res != "":
			col.add_child(A.chip({"win": "Win!", "lose": "Lose", "push": "Push", "bust": "Bust", "blackjack": "Blackjack!"}.get(res, res), A.WHITE, A.NAVY, "", 18, Vector2(12, 4)))
		if i == int(state.get("active_hand", 0)) and phase == "player" and hands.size() > 1:
			col.modulate = Color(1, 1, 1)
		elif hands.size() > 1:
			col.modulate = Color(1, 1, 1, 0.6)
	if phase == "betting":
		_bets(v)
		return
	_actions(v, state.get("legal", []) if phase == "player" else [])


## Everyone else at the table, small, along the top corners.
func _others(stack: Control) -> void:
	var row := A.vbox(4)
	A.pin(stack, row, Vector4(1, 0, 1, 0), Vector4(-300, 0, -6, 160))
	for p in state.get("players", []):
		if int(p.get("seat", -1)) == int(state.get("my_seat", -1)):
			continue
		var line := A.hbox(6, BoxContainer.ALIGNMENT_END)
		var name := A.label(str(p.get("name", "")), 15, Color("#F2C230") if p.get("turn", false) else A.WHITE, true)
		line.add_child(name)
		for h in p.get("hands", []):
			for c in h.get("cards", []):
				line.add_child(K.card(str(c[0]), str(c[1]), true, 26))
			line.add_child(A.label(("%d" % int(h.get("total", 0))) + (" · %s" % str(h["result"]) if str(h.get("result", "")) != "" else ""), 14, A.WHITE))
		if (p.get("hands", []) as Array).is_empty():
			line.add_child(A.label("bet %d" % int(p.get("bet", 0)) if int(p.get("bet", 0)) > 0 else "sitting out", 14, Color(1, 1, 1, 0.7)))
		row.add_child(line)


## Betting row: chip picker, BET adds the chip, CLEAR takes it back, DEAL says you're ready.
func _bets(v: VBoxContainer) -> void:
	var acts := A.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(acts)
	for i in K.CHIP_VALUES.size():
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(46, 46)
		b.tooltip_text = "%d chips" % K.CHIP_VALUES[i]
		b.add_child(K.chip(i, 44, i == _chip))
		var t := A.label(str(K.CHIP_VALUES[i]), 13, A.NAVY if i == 0 else A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(t)
		b.pressed.connect(func() -> void:
			_chip = i
			_build())
		acts.add_child(b)
	var bet := int(state.get("bet", 0))
	var add := K.action("Bet +%d" % K.CHIP_VALUES[_chip], "primary", 170)
	add.disabled = bool(state.get("ready", false)) or int(K.CHIP_VALUES[_chip]) > int(state.get("balance", 0)) \
		or bet + int(K.CHIP_VALUES[_chip]) > int(state.get("max_bet", 500))
	add.pressed.connect(func() -> void: intent.emit("bet", {"amount": int(K.CHIP_VALUES[_chip])}))
	acts.add_child(add)
	var clear := K.action("Clear", "secondary", 120)
	clear.disabled = bet == 0 or bool(state.get("ready", false))
	clear.pressed.connect(func() -> void: intent.emit("clear", null))
	acts.add_child(clear)
	var deal := K.action("Ready" if not state.get("ready", false) else "Waiting...", "primary", 150)
	deal.disabled = bet < int(state.get("min_bet", 5)) or bool(state.get("ready", false))
	deal.tooltip_text = "Minimum bet %d" % int(state.get("min_bet", 5)) if bet < int(state.get("min_bet", 5)) else ""
	deal.pressed.connect(func() -> void: intent.emit("deal", null))
	acts.add_child(deal)
	var leave := K.action("Leave", "secondary", 120)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)
	v.add_child(A.label(_note_text("Your bet: %d" % bet if bet > 0 else "Pick a chip and press BET (min %d)." % int(state.get("min_bet", 5))), 18, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))


func _note_text(fallback: String) -> String:
	return _note if _note != "" and Time.get_ticks_msec() / 1000.0 < _note_until else fallback


func _total(n: int, soft: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.box(K.FELT_DARK, 10, 0, Color.TRANSPARENT, 6))
	p.add_child(A.label(("Soft %d" % n) if soft else str(n), 20, A.WHITE, true))
	return p


func _actions(v: VBoxContainer, legal: Array) -> void:
	var acts := A.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(acts)
	for a in ["hit", "stand", "double", "split"]:
		var b := K.action(a, "primary", 170)
		b.disabled = not a in legal
		b.tooltip_text = "" if a in legal else "Not available for this hand"
		b.pressed.connect(func() -> void: if a in legal: intent.emit(a, {"hand": int(state.get("active_hand", 0))}))
		acts.add_child(b)
	var leave := K.action("Leave", "secondary", 170)
	leave.tooltip_text = "Hands in play stand and still pay out" if not legal.is_empty() else ""
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)
	var msg := _note_text("")
	if msg == "" and str(state.get("phase", "")) == "settled":
		msg = _summary()
	if msg != "":
		v.add_child(A.label(msg, 18, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))


func _summary() -> String:
	var parts := []
	for h in state.get("hands", []):
		var r := str(h.get("result", ""))
		parts.append({"win": "You win %d!" % (int(h["bet"]) * 2), "blackjack": "Blackjack! You win %d!" % (int(h["bet"]) + int(h["bet"]) * 3 / 2),
			"push": "Push: bet returned", "lose": "Dealer wins", "bust": "Bust"}.get(r, r))
	return "  ·  ".join(parts)


func close() -> void:
	intent.emit("leave", null)


func preview(s: String) -> void:
	match s:
		"settled":
			apply_state({"phase": "settled", "balance": 230, "dealer": [["7", "clubs"], ["K", "spades"]], "dealer_total": 17,
				"hands": [{"cards": [["9", "clubs"], ["6", "clubs"], ["4", "hearts"]], "total": 19, "result": "win"}], "legal": []})
		"waiting", "reconnecting", "full", "insufficient":
			apply_state({"phase": s, "balance": 210})
		_:
			apply_state({"phase": "player", "balance": 210, "dealer": [["7", "clubs"], null],
				"hands": [{"cards": [["9", "clubs"], ["6", "clubs"]], "total": 15}], "active_hand": 0, "legal": ["hit", "stand"]})
