extends RefCounted
## Shared single-zero roulette (host side). While anyone is seated: betting (20 s) -> lock and
## spin (7 s, the pocket is drawn at lock) -> result (5 s) -> betting. Bets are debited when
## accepted; Undo refunds your last placed batch until the lock. Leaving before the lock refunds
## your bets; after it they still settle to your purse.

const R := preload("res://scripts/casino/casino_rules.gd")
const BET_S := 20.0
const SPIN_S := 7.0
const RESULT_S := 5.0
const MAX_ROUND := 1000
const CHIPS := [1, 5, 10, 25, 100]

var c: Node
var id := ""
var seat_count := 4
var seats := {}       # seat -> {peer, token, name, color}
var phase := "idle"   # idle | betting | spinning | result
var until := 0.0
var batches := {}     # token -> [[[spot, amount], ...], ...] accepted batches, in order
var pocket := -1
var spin_id := 0
var history := []     # last pockets, newest first
var results := {}     # token -> {staked, won}


func _init(casino: Node, table_id: String, n: int) -> void:
	c = casino
	id = table_id
	seat_count = n


func has_peer(peer: int) -> bool:
	return _seat_of(peer) >= 0


func holds_chips(peer: int) -> bool:
	return _staked(c.token_of(peer)) > 0


func has_timer() -> bool:
	return phase != "idle"


func join(seat: int, who: Dictionary) -> String:
	if seat < 0 or seat >= seat_count:
		return "No such seat."
	if seats.has(seat) and seats[seat]["peer"] != who["peer"]:
		return "That seat is taken."
	seats[seat] = who
	return ""


func leave(peer: int) -> void:
	var s := _seat_of(peer)
	if s < 0:
		return
	var token: String = seats[s]["token"]
	if phase == "betting":
		c.credit(token, _staked(token))
		batches.erase(token)
	seats.erase(s)


func act(peer: int, action: String, data: Dictionary) -> String:
	var token: String = seats[_seat_of(peer)]["token"]
	match action:
		"bet":
			if phase != "betting":
				return "Bets are closed for this spin."
			var list = data.get("bets", [])
			if not list is Array or list.is_empty() or list.size() > 60:
				return "No bets to place."
			var batch := []
			var total := 0
			for b in list:
				if not b is Array or b.size() != 2 or not R.roulette_spot_ok(str(b[0])) or not CHIPS.has(int(b[1])):
					return "That bet isn't on the board."
				batch.append([str(b[0]), int(b[1])])
				total += int(b[1])
			if _staked(token) + total > MAX_ROUND:
				return "Table limit is %d chips a spin." % MAX_ROUND
			if not c.debit(token, total):
				return "Not enough play chips."
			var mine: Array = batches.get(token, [])
			mine.append(batch)
			batches[token] = mine
			c.emote(peer, "casino/reach_table")
		"undo":
			if phase != "betting":
				return "Too late to undo: the wheel is spinning."
			var mine: Array = batches.get(token, [])
			if mine.is_empty():
				return ""
			var last: Array = mine.pop_back()
			c.credit(token, last.reduce(func(acc, b): return acc + int(b[1]), 0))
		_:
			return "Unknown action."
	return ""


func tick(now: float) -> bool:
	match phase:
		"idle":
			if seats.is_empty():
				return false
			_open(now)
			return true
		"betting":
			if now < until:
				return false
			if seats.is_empty() and batches.is_empty():
				phase = "idle"
				return true
			if batches.is_empty():
				_open(now)  # nobody bet: keep the window open
				return true
			pocket = c.rng.randi_range(0, 36)
			spin_id += 1
			phase = "spinning"
			until = now + SPIN_S
			return true
		"spinning":
			if now < until:
				return false
			_settle()
			phase = "result"
			until = now + RESULT_S
			return true
		"result":
			if now < until:
				return false
			batches.clear()
			results.clear()
			if seats.is_empty():
				phase = "idle"
			else:
				_open(now)
			return true
	return false


func _open(now: float) -> void:
	phase = "betting"
	until = now + BET_S


func _settle() -> void:
	history.push_front(pocket)
	if history.size() > 10:
		history.pop_back()
	for token in batches:
		var staked := _staked(token)
		var won := 0
		for batch in batches[token]:
			for b in batch:
				won += int(b[1]) * R.roulette_return(str(b[0]), pocket)
		c.credit(token, won)
		results[token] = {"staked": staked, "won": won}
		var peer := _peer_of(token)
		if peer != 0:
			c.emote(peer, "casino/small_cheer_seated" if won > staked else ("casino/sad_slump_seated" if won == 0 else ""))


func view_for(peer: int) -> Dictionary:
	var token: String = c.token_of(peer)
	var all := {}
	for t in batches:
		for batch in batches[t]:
			for b in batch:
				all[b[0]] = int(all.get(b[0], 0)) + int(b[1])
	var mine := {}
	for batch in batches.get(token, []):
		for b in batch:
			mine[b[0]] = int(mine.get(b[0], 0)) + int(b[1])
	var players := []
	for s in seats:
		players.append({"seat": s, "name": seats[s]["name"], "color": seats[s]["color"]})
	return {
		"phase": phase, "left": maxf(0.0, until - c.now_s()), "seated": _seat_of(peer) >= 0,
		"pocket": pocket if phase in ["spinning", "result"] else -1, "spin_id": spin_id,
		"spin_left": maxf(0.0, until - c.now_s()) if phase == "spinning" else 0.0, "spin_total": SPIN_S,
		"history": history, "bets": mine, "table_bets": all, "staked": _staked(token),
		"result": results.get(token, {}), "balance": c.chips(token) if token != "" else 0, "players": players,
	}


func _staked(token: String) -> int:
	var n := 0
	for batch in batches.get(token, []):
		for b in batch:
			n += int(b[1])
	return n


func _seat_of(peer: int) -> int:
	for s in seats:
		if seats[s]["peer"] == peer:
			return s
	return -1


func _peer_of(token: String) -> int:
	for s in seats:
		if seats[s]["token"] == token:
			return int(seats[s]["peer"])
	return 0
