extends Node
## Casino review shots (windowed, it renders). Solo: sits at each game, plays through its states
## and saves the screen. A house bot takes a poker seat so a real hand can be dealt.
##   Godot --path . res://tools/casino_capture.tscn -- --out=/abs/dir/
var out := "user://"
var w: Node
var _bot_seat := 3


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_tree().create_timer(240.0).timeout.connect(func() -> void: get_tree().quit(1))
	w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	await w.travel_to("casino", "Inside")
	await _wait(3.0)
	await _shot("casino_room")
	# roulette
	await _sit("roulette")
	await _shot("casino_roulette_open")
	_ui().intent.emit("bet", {"bets": [["red", 10], ["n17", 5], ["d2", 25]]})
	await _wait(1.0)
	await _shot("casino_roulette_betting")
	Casino.table("roulette").until = 0.0  # skip the rest of the betting window
	await _wait(3.5)
	await _shot("casino_roulette_spin")
	await _wait(5.0)
	await _shot("casino_roulette_result")
	await _leave()
	# slots
	await _sit("slots")
	_ui().call("_spin")
	await _wait(0.6)
	await _shot("casino_slots_spin")
	await _wait(2.5)
	await _shot("casino_slots_result")
	await _leave()
	# blackjack
	await _sit("blackjack")
	await _shot("casino_blackjack_betting")
	_ui().intent.emit("bet", {"amount": 25})
	_ui().intent.emit("deal", null)
	await _wait(1.0)
	await _shot("casino_blackjack_turn")
	var v: Dictionary = _ui().get("state")
	if "hit" in v.get("legal", []) and int(v["hands"][0]["total"]) < 15:
		_ui().intent.emit("hit", {"hand": 0})
		await _wait(0.8)
	if "stand" in _ui().get("state").get("legal", []):
		_ui().intent.emit("stand", {"hand": 0})
	await _wait(3.0)
	await _shot("casino_blackjack_settled")
	await _leave()
	# poker with a house bot
	var p = Casino.table("poker")
	var bot := "b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0"
	Casino.credit(bot, maxi(0, 500 - Casino.chips(bot)))  # the bot's purse persists between runs
	p.join(_bot_seat, {"peer": 999, "token": "b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0", "name": "Milo", "color": 3})
	await _sit("poker")
	await _shot("casino_poker_waiting")
	await _wait(6.0)
	await _shot("casino_poker_preflop")
	for i in 40:  # check/call down to a showdown
		if p.phase == "showdown":
			break
		if p.phase == "betting":
			var me := Casino.table("poker").view_for(Net.local_id()) as Dictionary
			if p.to_act == _bot_seat:
				p.act(999, "check" if "check" in p._legal(_bot_seat) else "call", {})
			elif int(me.get("turn_seat", -1)) == int(me.get("my_seat", -2)):
				_ui().intent.emit("check" if "check" in me["legal"] else "call", {"amount": 0})
			if p.board.size() == 3 and i < 30:
				await _wait(0.6)
				await _shot("casino_poker_flop")
		await _wait(0.4)
	await _wait(0.6)
	await _shot("casino_poker_showdown")
	await _leave()
	print("CASINO_CAPTURE done")
	get_tree().quit()


func _ui() -> Control:
	return w.get_node("CasinoSession").get("_ui")


func _sit(game: String) -> void:
	var player: Node = w.get_node("Penguin")
	for s in get_tree().get_nodes_in_group("interactables"):
		if s is SeatSpot and s.activity == game:
			player.global_position = (s as SeatSpot).seat_point
			if s.interact(player):
				break
	await _wait(2.0)


func _leave() -> void:
	w.get_node("CasinoSession").call("_close", true)
	await _wait(1.5)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("SAVED ", name)
