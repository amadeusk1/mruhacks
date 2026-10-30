extends Node
## Roulette review shots for both board modes (windowed, it renders): the mode picker, then a
## simple-mode and a normal-mode round through betting, mid-spin and result.
##   Godot --path . res://tools/roulette_capture.tscn -- --out=/abs/dir/
const UI := preload("res://ui/activities/casino/roulette_ui.gd")
var out := "user://"
var w: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_tree().create_timer(120.0).timeout.connect(func() -> void: get_tree().quit(1))
	UI.forget_mode()
	w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	await w.travel_to("casino", "Inside")
	await _wait(3.0)
	await _sit("roulette")
	await _shot("roulette_pick_mode")
	for mode in ["simple", "normal"]:
		_ui().call("set_mode", mode)
		await _wait(0.5)
		_ui().intent.emit("bet", {"bets": [["red", 10], ["green", 5]] if mode == "simple" else [["red", 10], ["n17", 5], ["d2", 25]]})
		await _wait(1.0)
		await _shot("roulette_%s_betting" % mode)
		Casino.table("roulette").until = 0.0  # skip the rest of the betting window
		await _wait(2.5)
		await _shot("roulette_%s_spin" % mode)
		await _wait(5.5)
		await _shot("roulette_%s_result" % mode)
		Casino.table("roulette").until = 0.0  # straight to the next betting window
		await _wait(1.0)
	print("ROULETTE_CAPTURE done")
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


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("SAVED ", name)
