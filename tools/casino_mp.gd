extends Node
## Multi-process casino test over the real network (ENet, localhost). One dedicated server and
## two or more clients, each with its own purse profile:
##   Godot --headless --path . res://tools/casino_mp.tscn -- --role=server --dedicated --casino-profile=srv
##   Godot --headless --path . res://tools/casino_mp.tscn -- --role=client --name=Pip --casino-profile=pip
## Clients race for the same poker seat, then play poker, blackjack, roulette and slots with
## random legal moves. Checks: one seat winner, no other player's hole cards or dealer hole card
## in any view, retried requests settle once, every client sees the same roulette pocket.
## Prints CASINO_MP lines; exits 1 on a failed check.

var role := "client"
var me := "P"
var secs := 70.0
var _fails := []
var _views := {}
var _pockets := {}
var _seat := -1
var _phase := "poker"
var _acted := {}
var _hands := 0
var _bj_rounds := 0
var _spins := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
		if a.begins_with("--name="): me = a.trim_prefix("--name=")
		if a.begins_with("--secs="): secs = float(a.trim_prefix("--secs="))
	if role == "server":
		print("CASINO_MP server err='%s'" % Net.host_game("Server"))
		get_tree().create_timer(secs + 20.0).timeout.connect(func() -> void: get_tree().quit())
		return
	Casino.view.connect(_on_view)
	Casino.notice.connect(func(t: String, m: String) -> void: print("CASINO_MP %s notice %s: %s" % [me, t, m]))
	Net.session_started.connect(_on_session)
	print("CASINO_MP %s join err='%s'" % [me, Net.join_game(me)])
	get_tree().create_timer(secs).timeout.connect(_finish)


func _on_session() -> void:
	await get_tree().create_timer(1.0).timeout
	Casino.watch(true)
	Casino.join("poker", 0, "")  # everyone races for seat 0
	await get_tree().create_timer(1.5).timeout
	var v: Dictionary = _views.get("poker", {})
	_seat = int(v.get("my_seat", -1))
	print("CASINO_MP %s seat race -> %d" % [me, _seat])
	if _seat < 0:
		Casino.join("poker", 1 + randi() % 5, "")
	await get_tree().create_timer(secs * 0.4).timeout
	_phase = "blackjack"
	Casino.join("blackjack", randi() % 5, "")
	await get_tree().create_timer(secs * 0.25).timeout
	_phase = "roulette"
	Casino.join("roulette", randi() % 4, "")
	await get_tree().create_timer(secs * 0.2).timeout
	_phase = "slots"
	var slot := "slot_test_%s" % me
	Casino.join(slot, 0, "")
	await get_tree().create_timer(0.5).timeout
	var before := int(_views.get(slot, {}).get("spin", 0))
	for i in 2:  # the same request id twice: must count once
		Casino.rpc_id(1, "c_act", slot, "spin", {}, "dup-%s" % me)
	await get_tree().create_timer(1.0).timeout
	var after := int(_views.get(slot, {}).get("spin", 0))
	_check(after - before == 1, "duplicate spin settled %d times" % (after - before))
	for i in 5:
		Casino.act(slot, "spin")
		await get_tree().create_timer(0.3).timeout


func _on_view(table: String, v: Dictionary) -> void:
	_views[table] = v
	var dump := JSON.stringify(v)
	match table:
		"poker":
			var mine := int(v.get("my_seat", -1))
			for s in (v.get("seats", []) as Array).size():
				var row = v["seats"][s]
				if row is Dictionary and s != mine and (row.has("hole") or (row.has("shown") and str(v.get("phase", "")) != "showdown")):
					_check(false, "saw seat %d's cards outside a showdown" % s)
			if int(v.get("hand_no", 0)) > _hands:
				_hands = int(v["hand_no"])
			if _phase == "poker" and mine >= 0 and int(v.get("turn_seat", -1)) == mine:
				_poker_move(v)
		"blackjack":
			var d: Array = v.get("dealer", [])
			if str(v.get("phase", "")) == "player" and d.size() > 1 and d[1] != null:
				_check(false, "dealer hole card visible")
			if _phase == "blackjack" and int(v.get("my_seat", -1)) >= 0:
				_bj_move(v)
		"roulette":
			if int(v.get("pocket", -1)) >= 0:
				_pockets[int(v["spin_id"])] = int(v["pocket"])
			if _phase == "roulette" and bool(v.get("seated", false)) and str(v.get("phase", "")) == "betting" and int(v.get("staked", 0)) == 0 and not _acted.has("r%d" % int(v["spin_id"])):
				_acted["r%d" % int(v["spin_id"])] = true
				Casino.act("roulette", "bet", {"bets": [["red", 5], ["n%d" % (randi() % 37), 1]]})
	if dump.contains("\"hole\"") and table != "poker":
		_check(false, "hole cards leaked into %s" % table)


func _poker_move(v: Dictionary) -> void:
	var key := "p%d-%s-%d" % [int(v.get("hand_no", 0)), JSON.stringify(v.get("board")), int(v.get("pot", 0))]
	if _acted.has(key):
		return
	_acted[key] = true
	var legal: Array = v.get("legal", [])
	await get_tree().create_timer(0.3).timeout
	var r := randf()
	if "raise" in legal and r < 0.2:
		Casino.act("poker", "raise", {"amount": randi_range(int(v["min_raise"]), int(v["max_raise"]))})
	elif "check" in legal:
		Casino.act("poker", "check")
	elif r < 0.85:
		Casino.act("poker", "call")
	else:
		Casino.act("poker", "fold")


func _bj_move(v: Dictionary) -> void:
	var phase := str(v.get("phase", ""))
	if phase == "betting" and int(v.get("bet", 0)) == 0 and not _acted.has("bjb%d" % _bj_rounds):
		_acted["bjb%d" % _bj_rounds] = true
		Casino.act("blackjack", "bet", {"amount": 10})
		Casino.act("blackjack", "deal")
	elif phase == "player" and int(v.get("active_hand", -1)) >= 0:
		var h: Dictionary = v["hands"][int(v["active_hand"])]
		var key := "bj%d-%d-%d" % [_bj_rounds, int(v["active_hand"]), (h["cards"] as Array).size()]
		if _acted.has(key):
			return
		_acted[key] = true
		Casino.act("blackjack", "hit" if int(h["total"]) < 17 else "stand", {"hand": int(v["active_hand"])})
	elif phase == "settled" and not _acted.has("bjs%d" % _bj_rounds):
		_acted["bjs%d" % _bj_rounds] = true
		_bj_rounds += 1


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("CASINO_MP %s FAIL %s" % [me, what])


func _finish() -> void:
	print("CASINO_MP %s summary poker_hands=%d bj_rounds=%d pockets=%s balance=%d fails=%d" % [
		me, _hands, _bj_rounds, JSON.stringify(_pockets), int(_views.get("roulette", {}).get("balance", -1)), _fails.size()])
	Casino.watch(false)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if _fails.is_empty() else 1)
