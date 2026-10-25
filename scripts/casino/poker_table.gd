extends RefCounted
## No-limit Texas Hold'em for up to six seats (host side). Blinds 5/10. Sitting down buys in up to
## 500 of your play chips; your stack goes back to your purse when you stand up. A stack under the
## big blind tops itself up from your purse before each hand. A hand starts 5 s after two players
## with chips are seated. 25 s per decision, then the timer checks if it can, else folds.
## Full raises reopen the betting; an all-in short of a full raise doesn't. Side pots at showdown;
## odd chips go to the first winner after the button. Leaving mid-hand folds your hand.

const R := preload("res://scripts/casino/casino_rules.gd")
const SB := 5
const BB := 10
const BUY_IN := 500
const TURN_S := 25.0
const NEXT_S := 5.0
const SHOW_S := 7.0

var c: Node
var id := ""
var seat_count := 6
var seats := {}       # seat -> {peer, token, name, color, stack, hole, in_hand, folded, allin, bet, acted, last}
var contrib := {}     # seat -> chips put in this hand (stays when a player leaves)
var deck := []
var board := []
var button := -1
var street := 0
var to_act := -1
var max_bet := 0
var min_raise := BB
var phase := "idle"   # idle | waiting | betting | showdown
var until := 0.0
var shown := {}       # seat -> {cards, hand}
var result_text := ""
var hand_no := 0


func _init(casino: Node, table_id: String, n: int) -> void:
	c = casino
	id = table_id
	seat_count = n


func has_peer(peer: int) -> bool:
	return _seat_of(peer) >= 0


func holds_chips(peer: int) -> bool:
	var s := _seat_of(peer)
	return s >= 0 and int(seats[s]["stack"]) > 0


func has_timer() -> bool:
	return phase in ["waiting", "betting"]


func join(seat: int, who: Dictionary) -> String:
	if seat < 0 or seat >= seat_count:
		return "No such seat."
	if seats.has(seat) and seats[seat]["peer"] != who["peer"]:
		return "That seat is taken."
	if seats.has(seat):
		return ""
	var e := who.duplicate()
	e.merge({"stack": 0, "hole": [], "in_hand": false, "folded": false, "allin": false, "bet": 0, "acted": false, "last": ""})
	seats[seat] = e
	_top_up(seat)
	return ""


func leave(peer: int) -> void:
	var s := _seat_of(peer)
	if s < 0:
		return
	var e: Dictionary = seats[s]
	var was_turn := phase == "betting" and to_act == s
	seats.erase(s)
	c.credit(e["token"], int(e["stack"]))
	if phase == "betting" and e["in_hand"] and not e["folded"]:
		_after_action(c.now_s(), was_turn)


func act(peer: int, action: String, data: Dictionary) -> String:
	var s := _seat_of(peer)
	if phase != "betting" or to_act != s:
		return "Not your turn."
	if not action in _legal(s):
		return "You can't %s right now." % action
	if action == "raise":
		var lim := _raise_limits(s)
		var to := int(data.get("amount", 0))
		if to != lim[1] and (to < lim[0] or to > lim[1]):
			return "Raise to between %d and %d." % [lim[0], lim[1]]
	_apply(s, action, int(data.get("amount", 0)))
	c.emote(peer, "casino/reach_table" if action in ["call", "raise"] else "")
	_after_action(c.now_s(), true)
	return ""


func tick(now: float) -> bool:
	match phase:
		"idle":
			if _ready_players().size() >= 2:
				phase = "waiting"
				until = now + NEXT_S
				return true
		"waiting":
			if _ready_players().size() < 2:
				phase = "idle"
				return true
			if now >= until:
				_start(now)
				return true
		"betting":
			if now >= until:
				_apply(to_act, "check" if "check" in _legal(to_act) else "fold", 0)  # turn timer ran out
				_after_action(now, true)
				return true
		"showdown":
			if now >= until:
				for s in seats:
					var e: Dictionary = seats[s]
					e.merge({"hole": [], "in_hand": false, "folded": false, "allin": false, "bet": 0, "acted": false, "last": ""}, true)
				contrib.clear()
				board.clear()
				shown.clear()
				result_text = ""
				phase = "idle"
				return true
	return false


# --- hand flow ---------------------------------------------------------------------------------

func _ready_players() -> Array:
	var out := []
	for s in range(seat_count):
		if seats.has(s) and (int(seats[s]["stack"]) > 0 or c.chips(seats[s]["token"]) > 0):
			out.append(s)
	return out


func _top_up(s: int) -> void:
	var e: Dictionary = seats[s]
	if int(e["stack"]) >= BB:
		return
	var buy := mini(BUY_IN - int(e["stack"]), c.chips(e["token"]))
	if buy > 0 and c.debit(e["token"], buy):
		e["stack"] = int(e["stack"]) + buy


func _start(now: float) -> void:
	for s in seats:
		_top_up(s)
	var players := []
	for s in range(seat_count):
		if seats.has(s) and int(seats[s]["stack"]) > 0:
			players.append(s)
	if players.size() < 2:
		phase = "idle"
		return
	hand_no += 1
	contrib.clear()
	board.clear()
	shown.clear()
	result_text = ""
	deck = R.shoe(1, c.rng)
	for s in players:
		seats[s].merge({"hole": [], "in_hand": true, "folded": false, "allin": false, "bet": 0, "acted": false, "last": ""}, true)
	button = _next(button, func(s): return players.has(s))
	var sb := button if players.size() == 2 else _next(button, func(s): return players.has(s))
	var bb := _next(sb, func(s): return players.has(s))
	_put(sb, mini(SB, int(seats[sb]["stack"])))
	seats[sb]["last"] = "Small blind"
	_put(bb, mini(BB, int(seats[bb]["stack"])))
	seats[bb]["last"] = "Big blind"
	max_bet = BB
	min_raise = BB
	street = 0
	for k in 2:
		for s in players:
			seats[s]["hole"].append(deck.pop_back())
	for s in players:
		c.emote(int(seats[s]["peer"]), "casino/look_cards")
	phase = "betting"
	to_act = bb
	_after_action(now, true)


func _can_act(s: int) -> bool:
	return seats.has(s) and seats[s]["in_hand"] and not seats[s]["folded"] and not seats[s]["allin"]


func _needs_to_act(s: int) -> bool:
	return _can_act(s) and (not seats[s]["acted"] or int(seats[s]["bet"]) < max_bet)


func _live() -> Array:
	var out := []
	for s in range(seat_count):
		if seats.has(s) and seats[s]["in_hand"] and not seats[s]["folded"]:
			out.append(s)
	return out


func _next(from: int, pred: Callable) -> int:
	for k in range(1, seat_count + 1):
		var s := posmod(from + k, seat_count)
		if pred.call(s):
			return s
	return -1


## After any action, leave or blind: end the hand, close the street, or pass the turn on.
func _after_action(now: float, moved: bool) -> void:
	var live := _live()
	if live.size() <= 1:
		_finish(now, false)
		return
	var waiting := range(seat_count).filter(func(s): return _needs_to_act(s))
	var actors := range(seat_count).filter(func(s): return _can_act(s))
	if waiting.is_empty() or (actors.size() == 1 and int(seats[actors[0]]["bet"]) >= max_bet):
		_next_street(now)
		return
	if moved or not waiting.has(to_act):
		to_act = _next(to_act, func(s): return _needs_to_act(s))
		until = now + TURN_S


func _next_street(now: float) -> void:
	for s in seats:
		seats[s]["bet"] = 0
		seats[s]["acted"] = false
		if seats[s]["in_hand"] and not seats[s]["folded"] and not seats[s]["allin"]:
			seats[s]["last"] = ""
	max_bet = 0
	min_raise = BB
	street += 1
	var actors := range(seat_count).filter(func(s): return _can_act(s))
	while street <= 3:
		var n := 3 if street == 1 else 1
		for k in n:
			board.append(deck.pop_back())
		if actors.size() >= 2:
			to_act = _next(button, func(s): return _can_act(s))
			until = now + TURN_S
			return
		street += 1  # nobody left to bet: run the board out
	_finish(now, true)


func _finish(now: float, showdown: bool) -> void:
	var live := _live()
	var lines := []
	var won := {}
	if not showdown or live.size() == 1:
		var pot := 0
		for s in contrib:
			pot += int(contrib[s])
		if live.size() == 1:
			won[live[0]] = pot
			lines.append("%s wins %d" % [seats[live[0]]["name"], pot])
	else:
		var ranks := {}
		for s in live:
			ranks[s] = R.best_hand(seats[s]["hole"] + board)
			shown[s] = {"cards": R.cards_view(seats[s]["hole"]), "hand": R.hand_name(ranks[s])}
		for pot in R.side_pots(contrib, live):
			var best := []
			var winners := []
			for s in pot["eligible"]:
				var cmp := R.compare(ranks[s], best) if not best.is_empty() else 1
				if cmp > 0:
					best = ranks[s]
					winners = [s]
				elif cmp == 0:
					winners.append(s)
			if winners.is_empty():
				continue
			var share := int(pot["amount"]) / winners.size()
			var odd := int(pot["amount"]) - share * winners.size()
			var first := _next(button, func(s): return winners.has(s))
			for s in winners:
				won[s] = int(won.get(s, 0)) + share + (odd if s == first else 0)
		for s in won:
			if shown.has(s):
				lines.append("%s wins %d with %s" % [seats[s]["name"], won[s], shown[s]["hand"]])
	for s in won:
		seats[s]["stack"] = int(seats[s]["stack"]) + int(won[s])
		c.emote(int(seats[s]["peer"]), "casino/small_cheer_seated")
	for s in live:
		if not won.has(s):
			c.emote(int(seats[s]["peer"]), "casino/sad_slump_seated")
	result_text = "\n".join(lines)
	to_act = -1
	phase = "showdown"
	until = now + SHOW_S


# --- actions -----------------------------------------------------------------------------------

func _legal(s: int) -> Array:
	if phase != "betting" or to_act != s or not _can_act(s):
		return []
	var e: Dictionary = seats[s]
	var out := ["fold"]
	out.append("check" if int(e["bet"]) >= max_bet else "call")
	if not e["acted"] and int(e["stack"]) + int(e["bet"]) > max_bet:
		out.append("raise")
	return out


## [smallest legal raise-to, all-in raise-to]
func _raise_limits(s: int) -> Array:
	var all_in := int(seats[s]["stack"]) + int(seats[s]["bet"])
	return [mini(max_bet + min_raise, all_in), all_in]


func _apply(s: int, action: String, amount: int) -> void:
	var e: Dictionary = seats[s]
	match action:
		"fold":
			e["folded"] = true
			e["last"] = "Fold"
		"check":
			e["last"] = "Check"
		"call":
			_put(s, mini(max_bet - int(e["bet"]), int(e["stack"])))
			e["last"] = "All in" if e["allin"] else "Call %d" % int(e["bet"])
		"raise":
			var lim := _raise_limits(s)
			var to := clampi(amount, lim[0], lim[1])
			var opening := max_bet == 0
			_put(s, to - int(e["bet"]))
			if to - max_bet >= min_raise:  # a full raise reopens the betting for everyone else
				min_raise = to - max_bet
				for o in seats:
					if o != s:
						seats[o]["acted"] = false
			max_bet = maxi(max_bet, to)
			e["last"] = ("All in %d" % to) if e["allin"] else (("Bet %d" % to) if opening else ("Raise to %d" % to))
	e["acted"] = true


func _put(s: int, n: int) -> void:
	var e: Dictionary = seats[s]
	e["stack"] = int(e["stack"]) - n
	e["bet"] = int(e["bet"]) + n
	contrib[s] = int(contrib.get(s, 0)) + n
	if int(e["stack"]) == 0:
		e["allin"] = true


func view_for(peer: int) -> Dictionary:
	var me := _seat_of(peer)
	var pot := 0
	for s in contrib:
		pot += int(contrib[s])
	var list := []
	for s in range(seat_count):
		if not seats.has(s):
			list.append({})
			continue
		var e: Dictionary = seats[s]
		var row := {"name": e["name"], "body": e["color"], "chips": int(e["stack"]), "bet": int(e["bet"]),
			"cards": 2 if e["in_hand"] and not e["folded"] else 0, "folded": e["folded"], "allin": e["allin"],
			"button": s == button and phase != "idle", "last": e["last"]}
		if shown.has(s):
			row["shown"] = shown[s]["cards"]
			row["hand"] = shown[s]["hand"]
		list.append(row)
	var ui_phase := "waiting" if phase in ["idle", "waiting"] else phase
	var v := {"phase": ui_phase, "starting": phase == "waiting", "left": maxf(0.0, until - c.now_s()), "turn_left_s": maxf(0.0, until - c.now_s()),
		"turn_total_s": TURN_S, "pot": pot, "board": R.cards_view(board), "seats": list, "my_seat": me,
		"turn_seat": to_act if phase == "betting" else -1, "result": result_text, "blinds": [SB, BB], "hand_no": hand_no,
		"balance": c.chips(c.token_of(peer)) if c.token_of(peer) != "" else 0}
	if me >= 0:
		var e: Dictionary = seats[me]
		v["hole"] = R.cards_view(e["hole"])
		v["stack"] = int(e["stack"])
		v["legal"] = _legal(me)
		v["to_call"] = mini(maxi(0, max_bet - int(e["bet"])), int(e["stack"]))
		var lim := _raise_limits(me)
		v["min_raise"] = lim[0]
		v["max_raise"] = lim[1]
		if not e["hole"].is_empty() and e["in_hand"]:
			v["my_hand"] = R.hand_name(R.best_hand(e["hole"] + board)) if board.size() >= 3 else ""
	return v


func _seat_of(peer: int) -> int:
	for s in seats:
		if seats[s]["peer"] == peer:
			return s
	return -1
