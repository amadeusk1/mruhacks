class_name CasinoRules
extends RefCounted

## Payouts for the casino. Roulette is colors only: red, black, and one green.

const ROULETTE_POCKETS := 17
const SLOT_PAY := {
	"penguin": 20,
	"coin": 10,
	"igloo": 8,
	"sled": 8,
	"fish": 5,
}
const POKER_PAY := {
	"Jacks or better": 2,
	"Two pair": 3,
	"Three of a kind": 4,
	"Straight": 5,
	"Flush": 7,
	"Full house": 10,
	"Four of a kind": 25,
	"Straight flush": 50,
	"Royal flush": 100,
}


static func slot_roll() -> PackedStringArray:
	var bag := PackedStringArray([
		"sled", "sled", "sled", "sled", "sled", "sled",
		"igloo", "igloo", "igloo", "igloo", "igloo",
		"fish", "fish", "fish", "fish", "fish",
		"coin", "coin", "coin", "coin",
		"penguin", "penguin", "penguin",
	])
	var out := PackedStringArray()
	for _i in 3:
		out.append(bag[randi() % bag.size()])
	return out


static func slot_prize(reels: PackedStringArray, stake: int) -> int:
	if reels.size() < 3 or stake <= 0:
		return 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return stake * int(SLOT_PAY.get(reels[0], 0))
	if reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		return stake * 2
	return 0


static func roulette_roll() -> int:
	return randi() % ROULETTE_POCKETS


static func roulette_color(pocket: int) -> String:
	if pocket == 0:
		return "green"
	if pocket % 2 == 1:
		return "red"
	return "black"


static func roulette_prize(bet: String, pocket: int, stake: int) -> int:
	if stake <= 0:
		return 0
	if roulette_color(pocket) == bet:
		return stake * 2
	return 0


static func fresh_deck() -> Array:
	var deck: Array = []
	for suit in 4:
		for rank in range(2, 15):
			deck.append({"rank": rank, "suit": suit})
	deck.shuffle()
	return deck


static func card_label(card: Dictionary) -> String:
	var ranks := ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	var suits := ["S", "H", "D", "C"]
	return "%s%s" % [ranks[int(card["rank"])], suits[int(card["suit"])]]


static func card_red(card: Dictionary) -> bool:
	var suit := int(card["suit"])
	return suit == 1 or suit == 2


static func poker_title(cards: Array) -> String:
	var counts := {}
	var suits := {}
	var ranks: Array[int] = []
	for card in cards:
		var rank := int(card["rank"])
		var suit := int(card["suit"])
		ranks.append(rank)
		counts[rank] = int(counts.get(rank, 0)) + 1
		suits[suit] = int(suits.get(suit, 0)) + 1
	ranks.sort()
	var flush := false
	for suit in suits.keys():
		if int(suits[suit]) == 5:
			flush = true
	var unique: Array[int] = []
	for rank in ranks:
		if unique.is_empty() or unique[unique.size() - 1] != rank:
			unique.append(rank)
	var straight := unique.size() == 5 and unique[4] - unique[0] == 4
	var wheel := (
		unique.size() == 5
		and unique[0] == 2
		and unique[1] == 3
		and unique[2] == 4
		and unique[3] == 5
		and unique[4] == 14
	)
	if wheel:
		straight = true
	var groups: Array[int] = []
	for rank in counts.keys():
		groups.append(int(counts[rank]))
	groups.sort()
	if straight and flush and unique[0] == 10 and unique[4] == 14:
		return "Royal flush"
	if straight and flush:
		return "Straight flush"
	if groups == [1, 4]:
		return "Four of a kind"
	if groups == [2, 3]:
		return "Full house"
	if flush:
		return "Flush"
	if straight:
		return "Straight"
	if groups == [1, 1, 3]:
		return "Three of a kind"
	if groups == [1, 2, 2]:
		return "Two pair"
	if groups == [1, 1, 1, 2]:
		var pair := 0
		for rank in counts.keys():
			if int(counts[rank]) == 2:
				pair = int(rank)
		if pair >= 11:
			return "Jacks or better"
		return "No win"
	return "No win"


static func poker_prize(title: String, stake: int) -> int:
	return stake * int(POKER_PAY.get(title, 0))
