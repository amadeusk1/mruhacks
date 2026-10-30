extends SceneTree
## Casino rule fixtures and long random table simulations (no network, fake purse).
## Godot --headless --path . --script res://tools/tests/casino_rules_test.gd
## Prints CASINO TESTS PASS or the failures; exits 1 on failure.

const R := preload("res://scripts/casino/casino_rules.gd")
const Roulette := preload("res://scripts/casino/roulette_table.gd")
const Blackjack := preload("res://scripts/casino/blackjack_table.gd")
const Poker := preload("res://scripts/casino/poker_table.gd")
const Slots := preload("res://scripts/casino/slot_machine.gd")

var fails := 0


class FakeCasino:
	extends Node
	var rng := RandomNumberGenerator.new()
	var ledger := {}
	var t := 0.0
	var emotes := []

	func now_s() -> float:
		return t

	func chips(tok: String) -> int:
		return int(ledger.get(tok, 500))

	func debit(tok: String, n: int) -> bool:
		if n < 0 or chips(tok) < n:
			return false
		ledger[tok] = chips(tok) - n
		return true

	func credit(tok: String, n: int) -> void:
		if n > 0:
			ledger[tok] = chips(tok) + n

	func emote(p: int, clip: String) -> void:
		emotes.append([p, clip])

	func tell(_p: int, _t: String, _m: String) -> void:
		pass

	func token_of(peer: int) -> String:
		return "t%d" % peer


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func c(rank: String, suit: String) -> int:
	return R.RANKS.find(rank) + 13 * R.SUITS.find(suit)


func hand(spec: String) -> Array:  # "As Kh 10d" -> cards
	var out := []
	for t in spec.split(" "):
		var suit: String = {"s": "spades", "h": "hearts", "d": "diamonds", "c": "clubs"}[t.right(1)]
		out.append(c(t.left(t.length() - 1), suit))
	return out


func who(peer: int) -> Dictionary:
	return {"peer": peer, "token": "t%d" % peer, "name": "P%d" % peer, "color": peer}


func _init() -> void:
	rules()
	roulette()
	slots()
	blackjack()
	poker()
	print("CASINO TESTS PASS" if fails == 0 else "CASINO TESTS FAILED: %d" % fails)
	quit(0 if fails == 0 else 1)


func rules() -> void:
	check(R.bj_total(hand("Ah 6d")) == [17, true], "soft 17")
	check(R.bj_total(hand("Ah 6d 9c")) == [16, false], "ace drops to 1")
	check(R.bj_total(hand("Ah Ad 9c")) == [21, true], "two aces")
	check(R.bj_settle(hand("As Kd"), false, 10, hand("9c 8d")) == ["blackjack", 25], "natural pays 3:2")
	check(R.bj_settle(hand("As Kd"), true, 10, hand("9c 8d")) == ["win", 20], "split 21 is not a natural")
	check(R.bj_settle(hand("As Kd"), false, 10, hand("Ac Qd")) == ["push", 10], "naturals push")
	check(R.bj_settle(hand("9s 9d"), false, 10, hand("Ac Qd")) == ["lose", 0], "dealer natural")
	check(R.bj_settle(hand("9s 8d 7c"), false, 10, hand("10c 10d")) == ["bust", 0], "player bust loses first")
	check(R.bj_settle(hand("9s 8d"), false, 10, hand("10c 6d 9h")) == ["win", 20], "dealer bust")
	check(R.bj_settle(hand("9s 8d"), false, 10, hand("10c 7d")) == ["push", 10], "push")
	check(not R.bj_dealer_hits(hand("Ah 6d")), "stand on soft 17")
	var names := {"As Ks Qs Js 10s": "Royal Flush", "5d 4d 3d 2d Ad": "Straight Flush", "9c 9d 9h 9s 2c": "Four of a Kind",
		"3c 3d 3h 7s 7c": "Full House", "2h 7h 9h Jh Kh": "Flush", "5c 4d 3h 2s Ac": "Straight", "Qc Qd Qh 7s 2c": "Three of a Kind",
		"Jc Jd 4h 4s 2c": "Two Pair", "10c 10d 4h 8s 2c": "Pair", "Ac Jd 4h 8s 2c": "High Card"}
	for k in names:
		check(R.hand_name(R.rank5(hand(k))) == names[k], "hand name %s" % k)
	check(R.compare(R.rank5(hand("6c 5d 4h 3s 2c")), R.rank5(hand("5c 4d 3h 2s Ac"))) > 0, "six-high straight beats the wheel")
	check(R.compare(R.rank5(hand("Ac Ad Kh Ks 2c")), R.rank5(hand("Ac Ad Kh Ks 3c"))) < 0, "kicker decides two pair")
	check(R.compare(R.best_hand(hand("As Ks 2d 3c Qs Js 10s")), R.rank5(hand("As Ks Qs Js 10s"))) == 0, "best of seven")
	check(R.hand_name(R.best_hand(hand("2c 2d 2h 5s 5c 5d 9h"))) == "Full House", "two trips make a full house")
	# side pots: A all-in 50, B and C 200, D folded after putting in 100
	var pots := R.side_pots({0: 50, 1: 200, 2: 200, 3: 100}, [0, 1, 2])
	check(pots.size() == 2 and pots[0]["amount"] == 200 and pots[0]["eligible"] == [0, 1, 2], "main pot %s" % [pots])
	check(pots.size() == 2 and pots[1]["amount"] == 350 and pots[1]["eligible"] == [1, 2], "side pot %s" % [pots])
	var refund := R.side_pots({0: 100, 1: 300}, [0, 1])
	check(refund[-1]["amount"] == 200 and refund[-1]["eligible"] == [1], "uncalled chips return")
	check(R.roulette_return("n17", 17) == 36 and R.roulette_return("n17", 18) == 0, "straight up")
	check(R.roulette_return("red", 1) == 2 and R.roulette_return("red", 2) == 0 and R.roulette_return("red", 0) == 0, "red")
	check(R.roulette_return("green", 0) == 36 and R.roulette_return("green", 17) == 0 and R.roulette_spot_ok("green"), "green")
	check(R.roulette_return("even", 0) == 0 and R.roulette_return("odd", 35) == 2, "zero loses even money")
	check(R.roulette_return("d2", 24) == 3 and R.roulette_return("d2", 25) == 0 and R.roulette_return("d1", 0) == 0, "dozens")
	check(R.roulette_spot_ok("n36") and not R.roulette_spot_ok("n37") and not R.roulette_spot_ok("n-1") and not R.roulette_spot_ok("n07"), "spot names")
	# slots: exact return over every reel stop combination
	var total := 0
	var n := 0
	var stops := []
	for i in R.SLOT_SYMBOLS.size():
		for w in R.SLOT_WEIGHTS[i]:
			stops.append(R.SLOT_SYMBOLS[i])
	for a in stops:
		for b in stops:
			for d in stops:
				total += R.slot_multiplier([a, b, d])
				n += 1
	var rtp := float(total) / n
	print("slots RTP %.4f" % rtp)
	check(rtp > 0.93 and rtp < 0.97, "slot RTP %.3f" % rtp)


func roulette() -> void:
	var fc := FakeCasino.new()
	fc.rng.seed = 7
	var t := Roulette.new(fc, "roulette", 4)
	check(t.join(0, who(1)) == "" and t.join(1, who(2)) == "", "roulette seats")
	check(t.join(1, who(3)) != "", "taken roulette seat refused")
	t.tick(fc.t)
	check(t.phase == "betting", "betting opens")
	check(t.act(1, "bet", {"bets": [["red", 10], ["n17", 5]]}) == "", "bet accepted")
	check(t.act(1, "bet", {"bets": [["n37", 5]]}) != "", "off-board bet refused")
	check(t.act(1, "bet", {"bets": [["red", 7]]}) != "", "odd chip refused")
	check(t.act(2, "bet", {"bets": [["black", 25]]}) == "" and t.act(2, "undo", {}) == "", "undo")
	check(fc.chips("t2") == 500 and fc.chips("t1") == 485, "debits and undo refund")
	fc.t = 21.0
	t.tick(fc.t)
	check(t.phase == "spinning" and t.view_for(1)["pocket"] >= 0, "locks and spins")
	check(t.act(2, "bet", {"bets": [["red", 5]]}) != "", "late bet refused")
	fc.t = 29.0
	t.tick(fc.t)
	var p: int = t.pocket
	var expect := 485 + 10 * R.roulette_return("red", p) + 5 * R.roulette_return("n17", p)
	check(t.phase == "result" and fc.chips("t1") == expect, "roulette settles %d vs %d" % [fc.chips("t1"), expect])


func slots() -> void:
	var fc := FakeCasino.new()
	var m := Slots.new(fc, "slot_a")
	check(m.join(0, who(1)) == "" and m.join(0, who(2)) != "", "one player per machine")
	var spent := 0
	var won := 0
	for i in 2000:
		fc.ledger["t1"] = 500
		m.act(1, "spin", {})
		won += int(m.last["t1"]["win"])
		spent += R.SLOT_COST
		check(fc.chips("t1") == 500 - R.SLOT_COST + int(m.last["t1"]["win"]), "slot settles once")
	print("slots sim return %.3f over 2000 spins" % (float(won) / spent))


func blackjack() -> void:
	var fc := FakeCasino.new()
	fc.rng.seed = 11
	var t := Blackjack.new(fc, "blackjack", 5)
	for p in [1, 2, 3]:
		t.join(p, who(p))
	var rounds := 0
	var leaks := 0
	for step in 40000:
		fc.t += 0.25
		t.tick(fc.t)
		if t.phase == "betting":
			for p in [1, 2, 3]:
				var v: Dictionary = t.view_for(p)
				if int(v.get("bet", 0)) == 0 and fc.chips("t%d" % p) >= 10:
					t.act(p, "bet", {"amount": [5, 10, 25][fc.rng.randi() % 3]})
				if not v.get("ready", false):
					t.act(p, "deal", {})
		elif t.phase == "player":
			var seat: int = t.turn[0]
			var p := seat
			var v: Dictionary = t.view_for(p)
			var legal: Array = v.get("legal", [])
			var h: Dictionary = v["hands"][v["active_hand"]]
			var other := 1 + (p % 3)
			if t.view_for(other)["dealer"].size() > 1 and t.view_for(other)["dealer"][1] != null:
				leaks += 1
			if "split" in legal and fc.rng.randf() < 0.5:
				t.act(p, "split", {"hand": v["active_hand"]})
			elif "double" in legal and int(h["total"]) in [10, 11]:
				t.act(p, "double", {"hand": v["active_hand"]})
			else:
				t.act(p, "hit" if int(h["total"]) < 17 else "stand", {"hand": v["active_hand"]})
		elif t.phase == "settled" and t.until - fc.t > 4.7:
			rounds += 1
		for p in [1, 2, 3]:
			check(fc.chips("t%d" % p) >= 0, "no negative purse")
			if fc.chips("t%d" % p) < 30:
				fc.ledger["t%d" % p] = 500
	print("blackjack rounds %d" % rounds)
	check(rounds > 100, "blackjack keeps dealing (%d rounds)" % rounds)
	check(leaks == 0, "hole card hidden from other seats")
	# leaving mid-hand still settles: purse ends >= what it was minus the bet
	t.leave(1)
	check(not t.has_peer(1), "left the table")


func poker() -> void:
	var fc := FakeCasino.new()
	fc.rng.seed = 3
	var t := Poker.new(fc, "poker", 6)
	var players := [1, 2, 3, 4]
	for p in players:
		t.join(p, who(p))
	var hands := 0
	var leaks := 0
	var last_hand := 0
	var outside_start := 0
	for p in players:
		outside_start += fc.chips("t%d" % p) + int(t.seats[p]["stack"])
	for step in 60000:
		fc.t += 0.5
		t.tick(fc.t)
		if t.phase == "betting":
			var s: int = t.to_act
			var v: Dictionary = t.view_for(s)
			for p in players:
				if p != s:
					var row: Dictionary = t.view_for(p)["seats"][s] if t.view_for(p)["seats"][s] is Dictionary else {}
					if row.has("shown") or row.has("hole"):
						leaks += 1
			var legal: Array = v.get("legal", [])
			var r := fc.rng.randf()
			if r < 0.03:
				pass  # let the timer act
			elif "raise" in legal and r < 0.25:
				var amt := int(v["min_raise"]) if fc.rng.randf() < 0.8 else fc.rng.randi_range(int(v["min_raise"]), int(v["max_raise"]))
				check(t.act(s, "raise", {"amount": amt}) == "", "legal raise accepted")
			elif "check" in legal:
				t.act(s, "check", {})
			elif r < 0.8:
				t.act(s, "call", {})
			else:
				t.act(s, "fold", {})
			if t.to_act == s and t._raise_limits(s)[1] > 1:  # a 1-chip stack may legally shove 1
				check(t.act(s, "raise", {"amount": 1}) != "", "tiny raise refused")
		if t.hand_no != last_hand:
			last_hand = t.hand_no
			hands += 1
		# conservation: purses + stacks + chips in the pot never change
		var total := 0
		for p in players:
			total += fc.chips("t%d" % p)
		for s in t.seats:
			total += int(t.seats[s]["stack"])
		for s in t.contrib:
			total += int(t.contrib[s])
		if t.phase == "showdown" or t.phase == "idle" or t.phase == "waiting":
			total -= _pot(t)  # paid out already: pot entries are history until cleared
		check(total == outside_start, "chips conserved (%d vs %d) phase %s" % [total, outside_start, t.phase])
		if fails > 5:
			return
		for p in players:
			if fc.chips("t%d" % p) == 0 and t.seats.has(p) and int(t.seats[p]["stack"]) == 0 and t.phase == "idle":
				fc.ledger["t%d" % p] = 500  # the free refill a broke player would take
				outside_start += 500
	print("poker hands %d" % hands)
	check(hands > 200, "poker keeps dealing (%d hands)" % hands)
	check(leaks == 0, "other players' hole cards never in your view")
	t.leave(2)
	check(not t.has_peer(2), "left poker")


func _pot(t) -> int:
	var n := 0
	for s in t.contrib:
		n += int(t.contrib[s])
	return n
