extends Control
## Blackjack. Dealer's hole card stays face-down (and absent from state) until the reveal.
## Double / split only enabled when the server lists them as legal.
##   apply_state({phase: "betting"|"player"|"dealer"|"settled"|"waiting"|"reconnecting"|"full"|"insufficient",
##                balance, dealer: [[rank, suit] or null(hidden)], dealer_total (when revealed),
##                hands: [{cards: [[rank, suit]], total, soft, bet, result}], active_hand,
##                legal: ["hit","stand","double","split"]})
##   intent("action", {kind, hand})   intent("bet", amount)   intent("leave", null)

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")

var state := {}
var _root: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.is_empty():
		preview("player")


func apply_state(s: Dictionary) -> void:
	state = s
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
	v.add_child(K.header("Blackjack", "Play chips: %d" % int(state.get("balance", 0))))
	var felt := PanelContainer.new()
	felt.add_theme_stylebox_override("panel", A.box(K.FELT, 40, 12, K.WOOD, 24))
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(felt)
	var stack := Control.new()
	felt.add_child(stack)
	var phase := str(state.get("phase", ""))
	if phase in ["waiting", "reconnecting", "full", "insufficient"]:
		A.pin(stack, K.state_card(phase), Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-250, -140, 250, 140))
		_actions(v, [])
		return
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
	_actions(v, state.get("legal", []) if phase == "player" else [])


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
		b.pressed.connect(func() -> void: if a in legal: intent.emit("action", {"kind": a, "hand": int(state.get("active_hand", 0))}))
		acts.add_child(b)
	var leave := K.action("Leave", "secondary", 170)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)


func close() -> void:
	intent.emit("leave", null)
	queue_free()


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
