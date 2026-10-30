extends Node
## Casino autoload: the play-chip ledger and the casino tables, run by the host (listen host,
## dedicated server, or this game itself in Solo). Clients only send intents; shuffles, results,
## timers, legality, balances and settlement all live here (vault: Casino - Gameplay and UI
## Requirements). Private state (hole cards, your own balance) only ever goes to its owner.
## Play chips are the table purse. Town coins buy chips at the chip window, and any chips
## cash back out there at the same rate.
##
## Client API: watch(on), join(table, seat, bench_key), leave(table), act(table, action, data),
## refill(), sync(), buy(coins), cash_out(chips).
## Client signals: view(table, state) per table you watch, gesture(peer, clip), balance(chips),
## purse(chips, cashable).

signal view(table: String, state: Dictionary)
signal gesture(peer_id: int, clip: String)
signal balance(chips: int)
signal purse(chips: int, cashable: int)
signal paid(coins: int)
signal notice(table: String, message: String)

const LEDGER := "user://casino_ledger.json"
const TOKEN_FILE := "user://casino_player.cfg"
const START_CHIPS := 500
const REFILL_TO := 200
const REFILL_BELOW := 10
const REFILL_COOLDOWN_S := 600
const COIN_CHIPS := 10   ## play chips one town coin buys, and the same rate back out
const SAVE_EVERY := 2.0
const RouletteTable := preload("res://scripts/casino/roulette_table.gd")
const BlackjackTable := preload("res://scripts/casino/blackjack_table.gd")
const PokerTable := preload("res://scripts/casino/poker_table.gd")
const SlotMachine := preload("res://scripts/casino/slot_machine.gd")

var rng := RandomNumberGenerator.new()
var _SLOT_ID := RegEx.create_from_string("^slot_[A-Za-z0-9_]{1,24}$")
var _token := ""
var _tables := {}        # host: id -> table
var _ledger := {}        # host: token -> {chips, house, refill_at}
var chips_shown := 0
var cashable_shown := 0
var _tokens := {}        # host: peer -> token
var _watchers := {}      # host: peer -> true (everyone inside the casino)
var _seen := {}          # host: token -> recent request ids (retries settle once)
var _dirty := false
var _save_wait := 0.0
var _beat := 0.0
var _token_file := TOKEN_FILE
var _ledger_file := LEDGER


func _ready() -> void:
	rng.randomize()
	for a in OS.get_cmdline_user_args():  # tests run several clients from one machine
		if a.begins_with("--casino-profile="):
			var tag := a.trim_prefix("--casino-profile=").validate_filename()
			_token_file = "user://casino_player_%s.cfg" % tag
			_ledger_file = "user://casino_ledger_%s.json" % tag
	_token = _load_token()
	_tables["roulette"] = RouletteTable.new(self, "roulette", 4)
	_tables["blackjack"] = BlackjackTable.new(self, "blackjack", 5)
	_tables["poker"] = PokerTable.new(self, "poker", 6)
	_load_ledger()
	multiplayer.peer_disconnected.connect(_on_peer_gone)
	multiplayer.server_disconnected.connect(func() -> void: _watchers.clear())


func _process(delta: float) -> void:
	if not _is_host():
		return
	var now := now_s()
	_beat += delta
	var second := _beat >= 1.0  # timers on screen count down once a second
	if second:
		_beat = 0.0
	for id in _tables:
		var t = _tables[id]
		if t.tick(now) or (second and t.has_timer()):
			_push(id)
	if _dirty:
		_save_wait -= delta
		if _save_wait <= 0.0:
			_save_ledger()


func _exit_tree() -> void:
	if _dirty:
		_save_ledger()


# --- client API ------------------------------------------------------------------------------

## Enter (true) or leave (false) the casino room: you then receive every table's public view.
func watch(on: bool) -> void:
	_to_host("c_watch", [_token, on])


func join(table: String, seat: int, bench_key: String) -> void:
	_to_host("c_join", [_token, table, seat, bench_key])


func leave(table: String) -> void:
	_to_host("c_leave", [table])


func act(table: String, action: String, data: Dictionary = {}) -> void:
	var rid := "%d-%d" % [Time.get_ticks_usec(), rng.randi()]
	_to_host("c_act", [table, action, data, rid])


func refill() -> void:
	_to_host("c_refill", [_token])


## Ask the host for the purse. The HUD does this on spawn, before anyone enters the casino.
func sync() -> void:
	_to_host("c_sync", [_token])


## Spend town coins (already taken from the local purse) for play chips.
func buy(coins: int) -> void:
	_to_host("c_buy", [_token, coins])


## Turn play chips back into town coins. The host pays whole coins and keeps the remainder.
func cash_out(amount: int) -> void:
	_to_host("c_cash", [_token, amount])


# --- host-side helpers the tables call ---------------------------------------------------------

func now_s() -> float:
	return Time.get_ticks_msec() / 1000.0


func chips(token: String) -> int:
	return int(_account(token)["chips"])


## Chips that make a whole coin at the window. The leftover under one coin stays in the purse.
func cashable(token: String) -> int:
	var n := chips(token)
	return n - (n % COIN_CHIPS)


func debit(token: String, amount: int) -> bool:
	if amount < 0 or chips(token) < amount:
		return false
	var acc := _account(token)
	acc["chips"] = int(acc["chips"]) - amount
	if int(acc["chips"]) < int(acc["house"]):
		acc["house"] = int(acc["chips"])
	_changed(token)
	return true


func credit(token: String, amount: int) -> void:
	if amount <= 0:
		return
	_account(token)["chips"] = chips(token) + amount
	_changed(token)


func emote(peer: int, clip: String) -> void:
	if clip == "":
		return
	for p in _watchers:
		_to_peer(p, "s_gesture", [peer, clip])


func tell(peer: int, table: String, message: String) -> void:
	_to_peer(peer, "s_notice", [table, message])


func table(id: String):
	return _tables.get(id)


# --- RPC: client -> host ---------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c_watch(token: String, on: bool) -> void:
	_h_watch(_sender(), token, on)


@rpc("any_peer", "call_remote", "reliable")
func c_join(token: String, table_id: String, seat: int, bench_key: String) -> void:
	_h_join(_sender(), token, table_id, seat, bench_key)


@rpc("any_peer", "call_remote", "reliable")
func c_leave(table_id: String) -> void:
	_h_leave(_sender(), table_id)


@rpc("any_peer", "call_remote", "reliable")
func c_act(table_id: String, action: String, data: Dictionary, rid: String) -> void:
	_h_act(_sender(), table_id, action, data, rid)


@rpc("any_peer", "call_remote", "reliable")
func c_refill(token: String) -> void:
	_h_refill(_sender(), token)


@rpc("any_peer", "call_remote", "reliable")
func c_sync(token: String) -> void:
	_h_sync(_sender(), token)


@rpc("any_peer", "call_remote", "reliable")
func c_buy(token: String, coins: int) -> void:
	_h_buy(_sender(), token, coins)


@rpc("any_peer", "call_remote", "reliable")
func c_cash(token: String, amount: int) -> void:
	_h_cash(_sender(), token, amount)


# --- RPC: host -> client ---------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func s_view(table_id: String, state: Dictionary) -> void:
	view.emit(table_id, state)


@rpc("authority", "call_remote", "reliable")
func s_gesture(peer: int, clip: String) -> void:
	gesture.emit(peer, clip)


@rpc("authority", "call_remote", "reliable")
func s_balance(amount: int, cashable_n: int) -> void:
	chips_shown = amount
	cashable_shown = cashable_n
	balance.emit(amount)
	purse.emit(amount, cashable_n)


@rpc("authority", "call_remote", "reliable")
func s_paid(coins: int) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("grant_coins") and coins > 0:
		world.call("grant_coins", coins)
	paid.emit(coins)


@rpc("authority", "call_remote", "reliable")
func s_refund(coins: int) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("grant_coins") and coins > 0:
		world.call("grant_coins", coins)


@rpc("authority", "call_remote", "reliable")
func s_notice(table_id: String, message: String) -> void:
	notice.emit(table_id, message)


# --- host handlers -----------------------------------------------------------------------------

func _h_watch(peer: int, token: String, on: bool) -> void:
	if not _token_ok(token):
		return
	_tokens[peer] = token
	if on:
		_watchers[peer] = true
		_send_balance(peer, token)
		for id in _tables:
			_to_peer(peer, "s_view", [id, _tables[id].view_for(peer)])
	else:
		_watchers.erase(peer)
		for id in _tables:
			if _tables[id].has_peer(peer):
				_h_leave(peer, id)


func _h_join(peer: int, token: String, table_id: String, seat: int, bench_key: String) -> void:
	if not _token_ok(token):
		return
	_tokens[peer] = token
	_watchers[peer] = true
	if not _tables.has(table_id) and _SLOT_ID.search(table_id) != null and _tables.size() < 24:
		_tables[table_id] = SlotMachine.new(self, table_id)
	var t = _tables.get(table_id)
	if t == null:
		return
	# the seat itself is claimed through Net's host-checked bench API: only its holder may sit here
	if Net.is_online() and bench_key != "" and Net._bench_owner(bench_key) != peer:
		tell(peer, table_id, "That seat is taken.")
		return
	for id in _tables:  # one table at a time
		if id != table_id and _tables[id].has_peer(peer):
			_h_leave(peer, id)
	var err: String = t.join(seat, _who(peer))
	if err != "":
		tell(peer, table_id, err)
	_push(table_id)


func _h_leave(peer: int, table_id: String) -> void:
	var t = _tables.get(table_id)
	if t == null or not t.has_peer(peer):
		return
	t.leave(peer)
	_push(table_id)


func _h_act(peer: int, table_id: String, action: String, data: Dictionary, rid: String) -> void:
	var t = _tables.get(table_id)
	var token := str(_tokens.get(peer, ""))
	if t == null or token == "" or not t.has_peer(peer):
		return
	var seen: Array = _seen.get(token, [])
	if rid != "" and seen.has(rid):
		return  # a retried request: it already counted once
	seen.append(rid)
	if seen.size() > 64:
		seen.pop_front()
	_seen[token] = seen
	var err: String = t.act(peer, action, data)
	if err != "":
		tell(peer, table_id, err)
	_push(table_id)


func _h_sync(peer: int, token: String) -> void:
	if not _token_ok(token):
		return
	_tokens[peer] = token
	_send_balance(peer, token)


func _h_buy(peer: int, token: String, coins: int) -> void:
	if not _token_ok(token) or coins < 1 or coins > 100:
		tell(peer, "", "That buy didn't go through.")
		if coins > 0:
			_to_peer(peer, "s_refund", [coins])
		return
	_tokens[peer] = token
	credit(token, coins * COIN_CHIPS)
	tell(peer, "", "Bought %d chips." % (coins * COIN_CHIPS))


func _h_cash(peer: int, token: String, amount: int) -> void:
	if not _token_ok(token):
		return
	_tokens[peer] = token
	var take := mini(maxi(0, amount), chips(token))
	take -= take % COIN_CHIPS
	if take < COIN_CHIPS:
		tell(peer, "", "Need %d chips for a coin." % COIN_CHIPS)
		_send_balance(peer, token)
		return
	if not debit(token, take):
		tell(peer, "", "Not enough chips.")
		return
	var coins_out := int(take / float(COIN_CHIPS))
	_to_peer(peer, "s_paid", [coins_out])
	tell(peer, "", "Cashed %d chips for %d coins." % [take, coins_out])


func _h_refill(peer: int, token: String) -> void:
	if not _token_ok(token):
		return
	_tokens[peer] = token
	var acc := _account(token)
	var now := int(Time.get_unix_time_from_system())
	var committed := false
	for id in _tables:
		committed = committed or _tables[id].has_peer(peer) and _tables[id].holds_chips(peer)
	if int(acc["chips"]) >= REFILL_BELOW or committed:
		tell(peer, "", "Refills are for empty purses.")
		return
	if now < int(acc.get("refill_at", 0)):
		tell(peer, "", "Next free refill in %d min." % ceili((int(acc["refill_at"]) - now) / 60.0))
		return
	acc["chips"] = REFILL_TO
	acc["house"] = REFILL_TO
	acc["refill_at"] = now + REFILL_COOLDOWN_S
	_changed(token)
	for id in _tables:
		_push(id)


func _on_peer_gone(peer: int) -> void:
	if not _is_host():
		return
	for id in _tables:
		if _tables[id].has_peer(peer):
			_tables[id].leave(peer)
			_push(id)
	_watchers.erase(peer)
	_tokens.erase(peer)


# --- plumbing ----------------------------------------------------------------------------------

func _push(table_id: String) -> void:
	var t = _tables.get(table_id)
	if t == null:
		return
	for peer in _watchers:
		_to_peer(peer, "s_view", [table_id, t.view_for(peer)])


func _who(peer: int) -> Dictionary:
	var name := "Penguin"
	var color := 0
	if Net.is_online() and Net._players.has(peer):
		name = str(Net._players[peer].get("name", name))
		color = int(Net._players[peer].get("color", 0))
	else:
		name = str(Net.local_profile()["name"])
		color = int(Net.local_profile()["color"])
	return {"peer": peer, "token": str(_tokens.get(peer, "")), "name": name, "color": color}


func token_of(peer: int) -> String:
	return str(_tokens.get(peer, ""))


func _account(token: String) -> Dictionary:
	if not _ledger.has(token):
		_ledger[token] = {"chips": START_CHIPS, "house": START_CHIPS, "refill_at": 0}
		_dirty = true
	var acc: Dictionary = _ledger[token]
	if not acc.has("house"):
		acc["house"] = mini(int(acc["chips"]), START_CHIPS)
	return acc


func _send_balance(peer: int, token: String) -> void:
	_to_peer(peer, "s_balance", [chips(token), cashable(token)])


func _changed(token: String) -> void:
	_dirty = true
	if _save_wait <= 0.0:
		_save_wait = SAVE_EVERY
	for peer in _tokens:
		if _tokens[peer] == token:
			_send_balance(peer, token)


func _token_ok(token: String) -> bool:
	return token.length() == 32 and token.is_valid_hex_number()


func _sender() -> int:
	return multiplayer.get_remote_sender_id()


func _is_host() -> bool:
	return multiplayer.is_server()


func _to_host(method: String, args: Array) -> void:
	if _is_host():
		callv("_h_" + method.trim_prefix("c_"), [Net.local_id()] + args)
	else:
		callv("rpc_id", [1, method] + args)


func _to_peer(peer: int, method: String, args: Array) -> void:
	if _is_host() and (peer == Net.local_id() and not Net.dedicated):
		callv(method, args)
	elif multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer):
		callv("rpc_id", [peer, method] + args)


func _load_token() -> String:
	var f := FileAccess.open(_token_file, FileAccess.READ)
	if f != null:
		var t := f.get_as_text().strip_edges()
		if _token_ok(t):
			return t
	var bytes := Crypto.new().generate_random_bytes(16)
	var t := bytes.hex_encode()
	f = FileAccess.open(_token_file, FileAccess.WRITE)
	if f != null:
		f.store_string(t)
	return t


func _load_ledger() -> void:
	var f := FileAccess.open(_ledger_file, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_ledger = d


## Written to a temp file and renamed, so a crash mid-write never loses the whole ledger.
func _save_ledger() -> void:
	_dirty = false
	var tmp := _ledger_file + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Casino: cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(_ledger))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(_ledger_file))
