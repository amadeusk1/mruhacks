extends RefCounted
## One slot machine (host side): a spin debits the cost, draws three reels and pays out at once;
## the reels on screen only present the stored result. Reconnecting gets the same result back.

const R := preload("res://scripts/casino/casino_rules.gd")

var c: Node
var id := ""
var player := {}      # {peer, token, name, color} or empty
var last := {}        # token -> {result, win, spin}
var spins := 0


func _init(casino: Node, table_id: String) -> void:
	c = casino
	id = table_id


func has_peer(peer: int) -> bool:
	return not player.is_empty() and player["peer"] == peer


func holds_chips(_peer: int) -> bool:
	return false


func has_timer() -> bool:
	return false


func join(_seat: int, who: Dictionary) -> String:
	if not player.is_empty() and player["peer"] != who["peer"]:
		return "Someone is playing this machine."
	player = who
	return ""


func leave(peer: int) -> void:
	if has_peer(peer):
		player = {}


func act(peer: int, action: String, _data: Dictionary) -> String:
	if action != "spin":
		return "Unknown action."
	var token: String = player["token"]
	if not c.debit(token, R.SLOT_COST):
		return "Not enough play chips."
	var result := R.slot_spin(c.rng)
	var win := R.slot_multiplier(result) * R.SLOT_COST
	c.credit(token, win)
	spins += 1
	last[token] = {"result": result, "win": win, "spin": spins}
	c.emote(peer, "casino/pull_lever")
	return ""


func tick(_now: float) -> bool:
	return false


func view_for(peer: int) -> Dictionary:
	var token: String = c.token_of(peer)
	var mine: Dictionary = last.get(token, {})
	return {"busy": not player.is_empty(), "player": player.get("name", ""), "seated": has_peer(peer),
		"cost": R.SLOT_COST, "balance": c.chips(token) if token != "" else 0,
		"result": mine.get("result", ["penguin", "star", "bell"]), "win": int(mine.get("win", 0)),
		"spin": int(mine.get("spin", 0)), "table_spin": spins}
