extends SceneTree
## Headless check of the drawing-telephone rules with simulated peers.
##   Godot --headless --path . --script res://tools/tests/sketch_game_test.gd
## Covers chain rotation, privacy of views, timeout skips, rejoin and reveal order.

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	_stroke_roundtrip()
	_full_game(4)
	_full_game(3)
	_timeout_and_rejoin()
	print("SKETCH_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _stroke_roundtrip() -> void:
	var s := [{"c": "#3d7bd9", "w": 9.0, "p": PackedVector2Array([Vector2(0.1, 0.2), Vector2(0.5, 0.9)])}]
	var back := SketchStrokes.decode(SketchStrokes.encode(s))
	check(back.size() == 1 and (back[0]["p"] as PackedVector2Array)[1].distance_to(Vector2(0.5, 0.9)) < 0.001, "stroke roundtrip")
	check(SketchStrokes.decode(PackedByteArray([255, 255, 1])).is_empty(), "malformed strokes rejected")


func _draw_of(tag: String) -> PackedByteArray:
	# a drawing whose single point encodes which prompt it depicts, so privacy leaks are detectable
	return SketchStrokes.encode([{"c": "#000000", "w": 8.0, "p": PackedVector2Array([Vector2(0.123, 0.456)])}])


func _full_game(n: int) -> void:
	var g := SketchGame.new()
	var t := 0.0
	var peers := []
	for i in n:
		peers.append(100 + i)
		check(g.join(100 + i, "P%d" % i), "join %d" % i)
	for p in peers:
		g.set_ready(p, true, t)
	check(g.phase == SketchGame.PHASE_ROUND and g.round_kind() == "prompt", "game starts on all ready (n=%d)" % n)
	for r in n:
		var kind := g.round_kind()
		for s in n:
			var peer: int = peers[s]
			var v := g.view_for(peer, t)
			check(v["phase"] == kind, "round %d phase for slot %d" % [r, s])
			# privacy: a view holds at most its own assignment, never anyone else's secrets
			var dump := var_to_str(v)
			var allowed := ""
			if r > 0 and kind == "guess":
				allowed = ""  # guessing sees a drawing, no text at all
			elif r > 0:
				allowed = "secret-%d-%d" % [g.chain_for(s), r - 1]
			for c in n:
				for rr in r:
					var secret := "secret-%d-%d" % [c, rr]
					if secret != allowed:
						check(not dump.contains(secret), "slot %d round %d must not see %s" % [s, r, secret])
			if kind == "draw":
				check(g.submit(peer, _draw_of(""), t), "draw submit")
			else:
				check(g.submit(peer, "secret-%d-%d" % [g.chain_for(s), r], t), "text submit")
	check(g.phase == SketchGame.PHASE_REVEAL, "reveal after %d rounds" % n)
	# rotation: every chain has n entries, one from every slot, with alternating kinds
	for c in n:
		var chain: Array = g.chains[c]
		check(chain.size() == n, "chain %d length" % c)
		var who := chain.map(func(e): return e["slot"])
		who.sort()
		check(who == range(n), "chain %d has every slot once" % c)
		check(chain[0]["slot"] == c and chain[0]["kind"] == "text", "chain %d starts with its owner's prompt" % c)
		for i in range(1, n):
			check(chain[i]["kind"] == ("drawing" if i % 2 == 1 else "text"), "chain %d entry %d kind" % [c, i])
	# reveal order: chain by chain, entry by entry, then done
	var seen := []
	while true:
		var rv := g.reveal_view()
		seen.append([rv["chain"], rv["index"]])
		if rv["done"]:
			break
		g.next_entry()
	check(seen.size() == n * n and seen[0] == [0, 1] and seen[-1] == [n - 1, n], "reveal walks all %d entries in order" % (n * n))
	g.play_again()
	check(g.phase == SketchGame.PHASE_LOBBY and g.lobby.size() == n, "play again keeps the table")


func _timeout_and_rejoin() -> void:
	var g := SketchGame.new()
	for i in 3:
		g.join(200 + i, "Q%d" % i)
		g.set_ready(200 + i, true, 0.0)
	g.submit(200, "a cat", 0.0)
	g.submit(201, "a dog", 0.0)
	g.leave(202)  # drops mid-round: keeps the slot
	check(g.slots.size() == 3, "no reindex on leave")
	g.tick(31.0)  # prompt deadline passes
	check(g.round_kind() == "draw", "timeout advances the round")
	var skipped: Dictionary = g.chains[2][0]
	check(skipped["kind"] == "skipped" and skipped["slot"] == 2, "missing prompt recorded as skipped")
	# slot 0 now draws chain 2 (the skipped one) and gets the fallback instruction
	var v := g.view_for(200, 31.0)
	check(str(v["assignment"].get("fallback", "")) != "", "fallback instruction for skipped content")
	check(g.join(299, "Q2") and g.slot_of(299) == 2, "reconnect (new peer id, same name) restores the slot")
	check(g.view_for(299, 31.0)["phase"] == "draw", "rejoined player gets their current task")
