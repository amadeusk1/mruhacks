class_name CasinoRules
extends RefCounted
## Pure casino rules, no nodes and no network: cards and shoes, blackjack totals and settlement,
## Texas Hold'em hand ranking and side pots, roulette payouts, the slot reel strip and paytable.
## The host tables (scripts/casino/*_table.gd) call these; tools/casino_rules_test.gd checks them.
## Cards are ints 0..51: rank = c % 13 (0 = "2" ... 12 = "A"), suit = c / 13.

const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["spades", "hearts", "diamonds", "clubs"]
const HAND_NAMES := ["High Card", "Pair", "Two Pair", "Three of a Kind", "Straight", "Flush", "Full House",
	"Four of a Kind", "Straight Flush"]


static func card_view(c: int) -> Array:
	return [RANKS[c % 13], SUITS[c / 13]]


static func cards_view(cards: Array) -> Array:
	return cards.map(func(c): return card_view(int(c)))


## `decks` shuffled 52-card decks (Fisher-Yates on the host's rng).
static func shoe(decks: int, rng: RandomNumberGenerator) -> Array:
	var cards := []
	for d in decks:
		for c in 52:
			cards.append(c)
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cards[i]
		cards[i] = cards[j]
		cards[j] = t
	return cards


# --- blackjack: 6 decks, dealer stands on all 17s, blackjack pays 3:2, double on any first two
# cards, one split (any two cards of equal value), split aces take one card each, no surrender.

static func bj_card_value(c: int) -> int:
	var r := c % 13
	return 11 if r == 12 else mini(r + 2, 10)


## [total, soft]
static func bj_total(cards: Array) -> Array:
	var total := 0
	var aces := 0
	for c in cards:
		var v := bj_card_value(int(c))
		total += v
		if v == 11:
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return [total, aces > 0]


static func bj_natural(cards: Array, split := false) -> bool:
	return not split and cards.size() == 2 and int(bj_total(cards)[0]) == 21


static func bj_dealer_hits(cards: Array) -> bool:
	return int(bj_total(cards)[0]) < 17


## [result, amount returned to the player including the stake]; bet is the hand's total stake.
static func bj_settle(cards: Array, split: bool, bet: int, dealer: Array) -> Array:
	var p := int(bj_total(cards)[0])
	var d := int(bj_total(dealer)[0])
	var p_bj := bj_natural(cards, split)
	var d_bj := bj_natural(dealer)
	if p > 21:
		return ["bust", 0]
	if p_bj and d_bj:
		return ["push", bet]
	if p_bj:
		return ["blackjack", bet + bet * 3 / 2]
	if d_bj:
		return ["lose", 0]
	if d > 21 or p > d:
		return ["win", bet * 2]
	if p == d:
		return ["push", bet]
	return ["lose", 0]


# --- poker -----------------------------------------------------------------------------------

## Comparable rank of exactly five cards: [category, tiebreak ranks...] (higher wins).
static func rank5(cards: Array) -> Array:
	var ranks := []
	var suits := {}
	var counts := {}
	for c in cards:
		var r := int(c) % 13
		ranks.append(r)
		suits[int(c) / 13] = true
		counts[r] = int(counts.get(r, 0)) + 1
	var groups := []  # [count, rank], biggest group then highest rank first
	for r in counts:
		groups.append([counts[r], r])
	groups.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var flush := suits.size() == 1
	var uniq := counts.keys()
	uniq.sort()
	var high := -1
	if uniq.size() == 5:
		if uniq[4] - uniq[0] == 4:
			high = uniq[4]
		elif uniq == [0, 1, 2, 3, 12]:
			high = 3  # the wheel, A-2-3-4-5: five-high
	var order: Array = groups.map(func(g): return g[1])
	if high >= 0 and flush:
		return [8, high]
	if groups[0][0] == 4:
		return [7] + order
	if groups[0][0] == 3 and groups[1][0] == 2:
		return [6] + order
	if flush:
		return [5] + order
	if high >= 0:
		return [4, high]
	if groups[0][0] == 3:
		return [3] + order
	if groups[0][0] == 2 and groups[1][0] == 2:
		return [2] + order
	if groups[0][0] == 2:
		return [1] + order
	return [0] + order


## Best five of up to seven cards.
static func best_hand(cards: Array) -> Array:
	var best := []
	var n := cards.size()
	if n <= 5:
		return rank5(cards)
	for a in n:
		for b in range(a + 1, n):
			var five := []
			for i in n:
				if i != a and i != b:
					five.append(cards[i])
			var r := rank5(five)
			if best.is_empty() or compare(r, best) > 0:
				best = r
	return best


static func compare(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


static func hand_name(rank: Array) -> String:
	if rank.is_empty():
		return ""
	if rank[0] == 8 and rank[1] == 12:
		return "Royal Flush"
	return HAND_NAMES[rank[0]]


## Main pot and side pots from each seat's total contribution this hand.
## contrib: seat -> chips put in; live: seats still holding cards (not folded).
## Returns [{amount, eligible: [seats]}], main pot first.
static func side_pots(contrib: Dictionary, live: Array) -> Array:
	var levels := []
	for s in contrib:
		if int(contrib[s]) > 0 and not levels.has(int(contrib[s])):
			levels.append(int(contrib[s]))
	levels.sort()
	var pots := []
	var prev := 0
	for lvl in levels:
		var amount := 0
		var eligible := []
		for s in contrib:
			if int(contrib[s]) >= lvl:
				amount += lvl - prev
				if live.has(s):
					eligible.append(s)
		_merge_pot(pots, amount, eligible)
		prev = lvl
	return pots


## A level nobody live reached (a folded player's extra chips) joins the pot below it; levels with
## the same contenders merge.
static func _merge_pot(pots: Array, amount: int, eligible: Array) -> void:
	if not pots.is_empty() and (eligible.is_empty() or pots[-1]["eligible"] == eligible):
		pots[-1]["amount"] += amount
	elif eligible.is_empty():
		pots.append({"amount": amount, "eligible": []})
	else:
		pots.append({"amount": amount, "eligible": eligible})


# --- roulette (single zero) --------------------------------------------------------------------

const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]


static func roulette_color(n: int) -> String:
	if n == 0:
		return "green"
	return "red" if REDS.has(n) else "black"


## Valid spots: "n0".."n36", red, black, odd, even, d1/d2/d3 (dozens).
static func roulette_spot_ok(spot: String) -> bool:
	if spot in ["red", "black", "odd", "even", "d1", "d2", "d3"]:
		return true
	return spot.begins_with("n") and spot.substr(1).is_valid_int() and int(spot.substr(1)) >= 0 \
		and int(spot.substr(1)) <= 36 and str(int(spot.substr(1))) == spot.substr(1)


## Total returned per chip staked (stake included): 36 straight up, 3 dozens, 2 even money, 0 lose.
static func roulette_return(spot: String, pocket: int) -> int:
	if spot.begins_with("n"):
		return 36 if int(spot.substr(1)) == pocket else 0
	if pocket == 0:
		return 0
	match spot:
		"red", "black":
			return 2 if roulette_color(pocket) == spot else 0
		"odd":
			return 2 if pocket % 2 == 1 else 0
		"even":
			return 2 if pocket % 2 == 0 else 0
		"d1", "d2", "d3":
			var d := int(spot.substr(1))
			return 3 if pocket > (d - 1) * 12 and pocket <= d * 12 else 0
	return 0


# --- slots: three independent reels, 15 stops each. RTP 95.6% (tools/casino_rules_test.gd). ----

const SLOT_SYMBOLS := ["penguin", "star", "bell", "fish", "snowflake"]
const SLOT_WEIGHTS := [1, 2, 3, 4, 5]
const SLOT_COST := 5
## Multiplier of the cost: three of a kind, then penguins anywhere.
const SLOT_TRIPLE := {"penguin": 100, "star": 30, "bell": 15, "fish": 10, "snowflake": 6}
const SLOT_PENGUINS := {2: 12, 1: 1}


static func slot_spin(rng: RandomNumberGenerator) -> Array:
	var out := []
	for reel in 3:
		var roll := rng.randi_range(1, 15)
		for i in SLOT_SYMBOLS.size():
			roll -= SLOT_WEIGHTS[i]
			if roll <= 0:
				out.append(SLOT_SYMBOLS[i])
				break
	return out


static func slot_multiplier(symbols: Array) -> int:
	if symbols[0] == symbols[1] and symbols[1] == symbols[2]:
		return int(SLOT_TRIPLE[symbols[0]])
	return int(SLOT_PENGUINS.get(symbols.count("penguin"), 0))
