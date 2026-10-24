class_name SketchGame
extends RefCounted
## Drawing-telephone rules (GAME_DESIGN_CONTEXT §15), with no networking: the host feeds it
## joins/submits/time and asks it what each peer may see. Everything private stays in here;
## view_for(peer) only ever exposes that peer's own assignment until the reveal.
##
## Slots are fixed at start (order locked, never reindexed). Round r (0..N-1):
##   slot s works on chain (s - r) mod N;  r == 0 prompt, odd draw, even guess.
## So chain c is handled by slot (c + r) mod N and every slot contributes once to every chain.

const PHASE_LOBBY := "lobby"
const PHASE_ROUND := "round"
const PHASE_REVEAL := "reveal"

var min_players := 3
var max_players := 6          # communal_table seats
var times := {"prompt": 30.0, "draw": 75.0, "guess": 30.0}
const MAX_TEXT := 100

var phase := PHASE_LOBBY
var lobby: Array = []         # [{peer, name, ready}] before start
var slots: Array = []         # [{peer, name, connected}] locked at start
var chains: Array = []        # chains[c] = [{slot, kind, text|strokes(bytes)}]
var round_index := 0
var deadline := 0.0           # host clock seconds
var submitted := {}           # slot -> true for this round
var reveal_chain := 0
var reveal_entry := 0
var version := 0              # bumps on every change, so the host knows when to resend


# ---------------------------------------------------------------- lobby --
func join(peer: int, player_name: String) -> bool:
	if phase != PHASE_LOBBY:
		return _rejoin(peer, player_name)
	if _lobby_index(peer) >= 0:
		return true
	if lobby.size() >= max_players:
		return false
	lobby.append({"peer": peer, "name": player_name, "ready": false})
	_bump()
	return true


func leave(peer: int) -> void:
	var i := _lobby_index(peer)
	if i >= 0:
		lobby.remove_at(i)
		_bump()
	var s := slot_of(peer)
	if s >= 0:  # in a game: keep the slot (no reindexing); its turns time out as skipped
		slots[s]["connected"] = false
		_bump()


func set_ready(peer: int, ready: bool, now: float) -> void:
	var i := _lobby_index(peer)
	if i < 0 or phase != PHASE_LOBBY:
		return
	lobby[i]["ready"] = ready
	_bump()
	if lobby.size() >= min_players and lobby.all(func(p): return p["ready"]):
		start(now)


func start(now: float) -> void:
	slots = []
	for p in lobby:
		slots.append({"peer": p["peer"], "name": p["name"], "connected": true})
	chains = []
	for _i in slots.size():
		chains.append([])
	phase = PHASE_ROUND
	_begin_round(0, now)


## A disconnected player coming back (new peer id, same name) gets their slot and task back.
func _rejoin(peer: int, player_name: String) -> bool:
	for s in slots:
		if not s["connected"] and s["name"] == player_name:
			s["peer"] = peer
			s["connected"] = true
			_bump()
			return true
	return false


# --------------------------------------------------------------- rounds --
func round_kind(r: int = -1) -> String:
	r = round_index if r < 0 else r
	return "prompt" if r == 0 else ("draw" if r % 2 == 1 else "guess")


func chain_for(slot: int, r: int = -1) -> int:
	r = round_index if r < 0 else r
	return posmod(slot - r, slots.size())


func submit(peer: int, payload: Variant, now: float) -> bool:
	var s := slot_of(peer)
	if phase != PHASE_ROUND or s < 0 or submitted.has(s):
		return false
	var kind := round_kind()
	var entry := {"slot": s, "kind": "drawing" if kind == "draw" else "text"}
	if kind == "draw":
		if not (payload is PackedByteArray) or (payload as PackedByteArray).size() > SketchStrokes.MAX_BYTES:
			return false
		entry["strokes"] = payload
	else:
		var t := str(payload).strip_edges().substr(0, MAX_TEXT)
		if t == "":
			return false
		entry["text"] = t
	chains[chain_for(s)].append(entry)
	submitted[s] = true
	_bump()
	if submitted.size() == slots.size():
		_advance(now)
	return true


## Host calls this every frame; closes a round at its deadline with explicit skipped entries.
func tick(now: float) -> void:
	if phase == PHASE_ROUND and now >= deadline:
		for s in slots.size():
			if not submitted.has(s):
				chains[chain_for(s)].append({"slot": s, "kind": "skipped", "expected": "drawing" if round_kind() == "draw" else "text"})
		_advance(now)


func _advance(now: float) -> void:
	if round_index + 1 >= slots.size():
		phase = PHASE_REVEAL
		reveal_chain = 0
		reveal_entry = 0
		_bump()
	else:
		_begin_round(round_index + 1, now)


func _begin_round(r: int, now: float) -> void:
	round_index = r
	submitted = {}
	deadline = now + float(times[round_kind()])
	_bump()


# --------------------------------------------------------------- reveal --
func next_entry() -> void:
	if phase != PHASE_REVEAL:
		return
	if reveal_entry + 1 < (chains[reveal_chain] as Array).size():
		reveal_entry += 1
	elif reveal_chain + 1 < chains.size():
		reveal_chain += 1
		reveal_entry = 0
	_bump()


func is_reveal_done() -> bool:
	return phase == PHASE_REVEAL and reveal_chain == chains.size() - 1 \
		and reveal_entry == (chains[reveal_chain] as Array).size() - 1


func play_again() -> void:
	lobby = []
	for s in slots:
		if s["connected"]:
			lobby.append({"peer": s["peer"], "name": s["name"], "ready": false})
	slots = []
	chains = []
	phase = PHASE_LOBBY
	_bump()


# ---------------------------------------------------------------- views --
## Everything `peer` may see right now. Privacy: during rounds this holds only the peer's own
## assignment (the entry right before theirs in their chain); other chains never appear.
func view_for(peer: int, now: float) -> Dictionary:
	var v := {"phase": "lobby", "players": names(), "host_peer": host_peer()}
	if phase == PHASE_LOBBY:
		v["ready"] = lobby.map(func(p): return p["ready"])
		v["min_players"] = min_players
		v["seated"] = _lobby_index(peer) >= 0
		return v
	if phase == PHASE_REVEAL:
		v["phase"] = "reveal"
		v["reveal"] = reveal_view()
		return v
	var s := slot_of(peer)
	v["round"] = round_index
	v["rounds"] = slots.size()
	v["submitted"] = submitted.size()
	v["deadline_s"] = maxf(0.0, deadline - now)
	if s < 0:  # spectator: public progress only
		v["phase"] = "spectate"
		return v
	if submitted.has(s):
		v["phase"] = "wait"
		return v
	var kind := round_kind()
	v["phase"] = kind
	if kind != "prompt":
		var prev: Dictionary = chains[chain_for(s)][round_index - 1]
		var a := {"kind": prev["kind"]}
		if prev["kind"] == "skipped":  # fallback instruction for the content type we did not get
			a["fallback"] = "Draw anything you like!" if kind == "draw" else "Make up a title for a mystery drawing!"
			a["text"] = a["fallback"]
		elif prev.has("text"):
			a["text"] = prev["text"]
		else:
			a["strokes"] = prev["strokes"]
		v["assignment"] = a
	return v


## Public: entries of the current chain up to the reveal position, with contributor names.
func reveal_view() -> Dictionary:
	var entries := []
	var chain: Array = chains[reveal_chain]
	for i in reveal_entry + 1:
		var e: Dictionary = chain[i]
		var who := str(slots[int(e["slot"])]["name"])
		var out := {"kind": e["kind"], "who": who}
		match str(e["kind"]):
			"text":
				out["text"] = e["text"]
				out["caption"] = ("%s's prompt" if i == 0 else "%s guessed") % who
			"drawing":
				out["strokes"] = e["strokes"]
				out["caption"] = "%s drew" % who
			_:
				out["caption"] = "%s ran out of time" % who
		entries.append(out)
	return {"chain": reveal_chain, "chains": chains.size(), "entries": entries,
		"index": reveal_entry + 1, "total": chain.size(), "done": is_reveal_done(),
		"owner": str(slots[reveal_chain]["name"])}


func names() -> Array:
	var src := lobby if phase == PHASE_LOBBY else slots
	return src.map(func(p): return p["name"])


func host_peer() -> int:
	var src := lobby if phase == PHASE_LOBBY else slots
	for p in src:
		if p.get("connected", true):
			return int(p["peer"])
	return 0


func slot_of(peer: int) -> int:
	for i in slots.size():
		if slots[i]["peer"] == peer and slots[i]["connected"]:
			return i
	return -1


func members() -> Array:
	var src := lobby if phase == PHASE_LOBBY else slots
	return src.filter(func(p): return p.get("connected", true)).map(func(p): return int(p["peer"]))


## Voice proposal §15.7: quiet while anyone is privately writing or drawing.
func is_quiet() -> bool:
	return phase == PHASE_ROUND


func _lobby_index(peer: int) -> int:
	for i in lobby.size():
		if lobby[i]["peer"] == peer:
			return i
	return -1


func _bump() -> void:
	version += 1
