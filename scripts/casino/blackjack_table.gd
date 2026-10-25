extends RefCounted
## Dealer blackjack for up to five seats (host side). Rules in casino_rules.gd: 6-deck shoe
## (reshuffled at the cut card), dealer stands on all 17s and peeks for blackjack, 3:2 naturals,
## double on any first two cards, one split, split aces take one card.
## Flow: betting (15 s, or until every bettor presses Deal) -> deal -> player turns (20 s each,
## then auto-stand) -> dealer draws -> settled (5 s). Seated players who don't bet sit the round out.
## Leaving mid-round stands your hands; they still settle to your purse.

const R := preload("res://scripts/casino/casino_rules.gd")
const BET_S := 15.0
const TURN_S := 20.0
const DEALER_STEP_S := 0.8
const SETTLE_S := 5.0
const MIN_BET := 5
const MAX_BET := 500
const DECKS := 6

var c: Node
var id := ""
var seat_count := 5
var seats := {}        # seat -> {peer, token, name, color, bet, ready, hands: [{cards, bet, split, done, result, paid}]}
var gone := {}         # seat -> seat entry of a player who left mid-round (hands still settle)
var shoe := []
var dealer := []
var phase := "idle"    # idle | betting | player | dealer | settled
var until := 0.0
var turn := [-1, 0]    # [seat, hand]


func _init(casino: Node, table_id: String, n: int) -> void:
	c = casino
	id = table_id
	seat_count = n


func has_peer(peer: int) -> bool:
	return _seat_of(peer) >= 0


func holds_chips(peer: int) -> bool:
	var s := _seat_of(peer)
	return s >= 0 and (int(seats[s]["bet"]) > 0 or not seats[s]["hands"].is_empty())


func has_timer() -> bool:
	return phase in ["betting", "player"]


func join(seat: int, who: Dictionary) -> String:
	if seat < 0 or seat >= seat_count:
		return "No such seat."
	if seats.has(seat) and seats[seat]["peer"] != who["peer"]:
		return "That seat is taken."
	if gone.has(seat):
		return "That seat frees up after this round."
	var e := who.duplicate()
	e.merge({"bet": 0, "ready": false, "hands": []})
	seats[seat] = e
	return ""


func leave(peer: int) -> void:
	var s := _seat_of(peer)
	if s < 0:
		return
	var e: Dictionary = seats[s]
	seats.erase(s)
	if phase in ["idle", "betting"]:
		c.credit(e["token"], int(e["bet"]))
		return
	if e["hands"].is_empty():
		return
	for h in e["hands"]:
		h["done"] = true  # stands; settles with the table
	gone[s] = e
	if turn[0] == s:
		_advance(c.now_s())


func act(peer: int, action: String, data: Dictionary) -> String:
	var s := _seat_of(peer)
	var e: Dictionary = seats[s]
	match action:
		"bet":
			if phase != "betting":
				return "Wait for the next round to bet."
			var amount := int(data.get("amount", 0))
			if amount < 1 or int(e["bet"]) + amount > MAX_BET:
				return "Bets are %d to %d chips." % [MIN_BET, MAX_BET]
			if not c.debit(e["token"], amount):
				return "Not enough play chips."
			e["bet"] = int(e["bet"]) + amount
			c.emote(peer, "casino/reach_table")
		"clear":
			if phase != "betting":
				return ""
			c.credit(e["token"], int(e["bet"]))
			e["bet"] = 0
			e["ready"] = false
		"deal":
			if phase != "betting":
				return ""
			if int(e["bet"]) < MIN_BET:
				return "Minimum bet is %d chips." % MIN_BET
			e["ready"] = true
			if _all_ready():
				_deal(c.now_s())
		"hit", "stand", "double", "split":
			if phase != "player" or turn[0] != s or int(data.get("hand", turn[1])) != turn[1]:
				return "Not your turn."
			if not action in _legal(s):
				return "You can't %s this hand." % action
			c.emote(peer, "casino/reach_table" if action != "stand" else "")
			_play(s, action)
		_:
			return "Unknown action."
	return ""


func tick(now: float) -> bool:
	match phase:
		"idle":
			if seats.is_empty():
				return false
			phase = "betting"
			until = now + BET_S
			return true
		"betting":
			if now < until:
				return false
			if seats.is_empty():
				phase = "idle"
				return true
			for s in seats:
				if int(seats[s]["bet"]) > 0 and int(seats[s]["bet"]) < MIN_BET:
					c.credit(seats[s]["token"], int(seats[s]["bet"]))  # under the minimum: returned
					seats[s]["bet"] = 0
			if _bettors().is_empty():
				until = now + BET_S
				return true
			_deal(now)
			return true
		"player":
			if now < until:
				return false
			_play(turn[0], "stand")  # turn timer ran out
			return true
		"dealer":
			if now < until:
				return false
			if _dealer_draws() and R.bj_dealer_hits(dealer):
				dealer.append(_draw())
				until = now + DEALER_STEP_S
				return true
			_settle(now)
			return true
		"settled":
			if now < until:
				return false
			gone.clear()
			dealer.clear()
			for s in seats:
				seats[s]["hands"] = []
				seats[s]["bet"] = 0
				seats[s]["ready"] = false
			phase = "idle" if seats.is_empty() else "betting"
			until = now + BET_S
			return true
	return false


func _bettors() -> Array:
	var out := []
	for s in range(seat_count):
		if seats.has(s) and int(seats[s]["bet"]) >= MIN_BET:
			out.append(s)
	return out


func _all_ready() -> bool:
	var any := false
	for s in seats:
		if int(seats[s]["bet"]) >= MIN_BET:
			any = true
			if not seats[s]["ready"]:
				return false
		elif int(seats[s]["bet"]) > 0:
			return false
	return any


func _draw() -> int:
	if shoe.size() < 52 * DECKS / 4:  # cut card: a fresh shoe
		shoe = R.shoe(DECKS, c.rng)
	return int(shoe.pop_back())


func _deal(now: float) -> void:
	var order := _bettors()
	for s in seats:
		if not order.has(s) and int(seats[s]["bet"]) > 0:
			c.credit(seats[s]["token"], int(seats[s]["bet"]))
			seats[s]["bet"] = 0
	for s in order:
		seats[s]["hands"] = [{"cards": [], "bet": int(seats[s]["bet"]), "split": false, "done": false, "result": ""}]
	dealer = []
	for round in 2:
		for s in order:
			seats[s]["hands"][0]["cards"].append(_draw())
		dealer.append(_draw())
	for s in order:
		if R.bj_natural(seats[s]["hands"][0]["cards"]):
			seats[s]["hands"][0]["done"] = true
	# the dealer peeks under an ace or ten: a natural ends the round at once
	if R.bj_card_value(dealer[0]) >= 10 and R.bj_natural(dealer):
		_settle(now)
		return
	phase = "player"
	turn = [-1, 0]
	_advance(now)


## Next unfinished hand in seat order, or the dealer's turn.
func _advance(now: float) -> void:
	for s in range(seat_count):
		if not seats.has(s):
			continue
		var hands: Array = seats[s]["hands"]
		for i in hands.size():
			if not hands[i]["done"]:
				if int(R.bj_total(hands[i]["cards"])[0]) >= 21:
					hands[i]["done"] = true  # 21 or bust: nothing left to decide
					continue
				turn = [s, i]
				until = now + TURN_S
				return
	turn = [-1, 0]
	phase = "dealer"
	until = now + DEALER_STEP_S


func _legal(s: int) -> Array:
	if phase != "player" or turn[0] != s:
		return []
	var e: Dictionary = seats[s]
	var h: Dictionary = e["hands"][turn[1]]
	var out := ["hit", "stand"]
	var two: bool = h["cards"].size() == 2
	if two and c.chips(e["token"]) >= int(h["bet"]):
		out.append("double")
		if e["hands"].size() == 1 and R.bj_card_value(h["cards"][0]) == R.bj_card_value(h["cards"][1]):
			out.append("split")
	return out


func _play(s: int, action: String) -> void:
	var e: Dictionary = seats[s]
	var h: Dictionary = e["hands"][turn[1]]
	match action:
		"hit":
			h["cards"].append(_draw())
			if int(R.bj_total(h["cards"])[0]) >= 21:
				h["done"] = true
		"stand":
			h["done"] = true
		"double":
			c.debit(e["token"], int(h["bet"]))
			h["bet"] = int(h["bet"]) * 2
			h["cards"].append(_draw())
			h["done"] = true
		"split":
			c.debit(e["token"], int(h["bet"]))
			var second := {"cards": [h["cards"].pop_back()], "bet": int(h["bet"]), "split": true, "done": false, "result": ""}
			h["split"] = true
			h["cards"].append(_draw())
			second["cards"].append(_draw())
			e["hands"].append(second)
			if R.bj_card_value(h["cards"][0]) == 11:  # split aces: one card each
				h["done"] = true
				second["done"] = true
	if h["done"]:
		_advance(c.now_s())
	else:
		until = c.now_s() + TURN_S


func _dealer_draws() -> bool:
	for e in seats.values() + gone.values():
		for h in e["hands"]:
			if int(R.bj_total(h["cards"])[0]) <= 21 and not R.bj_natural(h["cards"], h["split"]):
				return true
	return false


func _settle(now: float) -> void:
	for e in seats.values() + gone.values():
		var staked := 0
		var back := 0
		for h in e["hands"]:
			var res := R.bj_settle(h["cards"], h["split"], int(h["bet"]), dealer)
			h["result"] = res[0]
			staked += int(h["bet"])
			back += int(res[1])
		c.credit(e["token"], back)
		if _seat_of(int(e["peer"])) >= 0 and staked > 0:
			c.emote(int(e["peer"]), "casino/small_cheer_seated" if back > staked else ("casino/sad_slump_seated" if back < staked else ""))
	phase = "settled"
	until = now + SETTLE_S


func view_for(peer: int) -> Dictionary:
	var me := _seat_of(peer)
	var reveal := phase in ["dealer", "settled"]
	var dview := []
	for i in dealer.size():
		dview.append(R.card_view(dealer[i]) if reveal or i == 0 else null)
	var players := []
	for s in range(seat_count):
		var e: Dictionary = seats.get(s, gone.get(s, {}))
		if e.is_empty():
			continue
		players.append({"seat": s, "name": e["name"], "color": e["color"], "bet": int(e["bet"]), "ready": e["ready"],
			"hands": e["hands"].map(_hand_view), "turn": turn[0] == s})
	var v := {"phase": phase if phase != "idle" else "waiting", "left": maxf(0.0, until - c.now_s()), "turn_total": TURN_S,
		"dealer": dview, "players": players, "my_seat": me, "min_bet": MIN_BET, "max_bet": MAX_BET,
		"balance": c.chips(c.token_of(peer)) if c.token_of(peer) != "" else 0}
	if reveal and not dealer.is_empty():
		v["dealer_total"] = int(R.bj_total(dealer)[0])
	elif not dealer.is_empty():
		v["dealer_up"] = R.bj_card_value(dealer[0])
	if me >= 0:
		var e: Dictionary = seats[me]
		v["bet"] = int(e["bet"])
		v["ready"] = e["ready"]
		v["hands"] = e["hands"].map(_hand_view)
		v["active_hand"] = turn[1] if turn[0] == me else -1
		v["legal"] = _legal(me)
	return v


func _hand_view(h: Dictionary) -> Dictionary:
	var t := R.bj_total(h["cards"])
	return {"cards": R.cards_view(h["cards"]), "total": t[0], "soft": t[1] and int(t[0]) < 21, "bet": int(h["bet"]),
		"result": h["result"], "split": h["split"]}


func _seat_of(peer: int) -> int:
	for s in seats:
		if seats[s]["peer"] == peer:
			return s
	return -1
