extends Node

## Fishes like a player, for follow bots and film hosts. While `active` it walks to the nearest
## free spot on the pier, sits down, and sends the same phases the fishing minigame does
## (cast, wait, bite, reel, catch), so everyone sees the rod, the bobber dip and the fish come up.
## The minigame's own screen is left alone; on a film host it is hidden by Hide UI.

const MODELS := ["fish_round", "fish_slim", "fish_spiky"]
const REACH := 8.0  # only spots this close: a bot left over stands by instead of leaving the group
const STEPS := [["cast", 0.5], ["wait", 1.1], ["bite", 0.6], ["reel", 1.4], ["catch", 2.0]]

var active := false
var drive_hud := false  # film host with the UI shown: play the minigame's own screen instead of sending phases
var offset := 0.0  # seconds to wait after sitting down, so pilots don't cast in step

var _step := 0
var _left := 0.0
var _catches := 0
var _seek_in := 0.0
var _hud_phase := ""
var _space_down := false


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	if not active or me == null:
		return
	if not bool(me.call("is_fishing")):
		_step = 0
		_left = offset
		_seek_in -= delta
		if _seek_in <= 0.0:
			_seek_in = 0.5
			_seek(me)
		return
	if drive_hud:
		_play_hud(me, delta)
		return
	_left -= delta
	if _left > 0.0:
		return
	var phase := str(STEPS[_step][0])
	if phase == "catch":
		phase = "catch:" + str(MODELS[_catches % MODELS.size()])
		_catches += 1
	me.call("set_fish_phase", phase)
	_left = float(STEPS[_step][1])
	_step = (_step + 1) % STEPS.size()


## Sits at the nearest spot nobody holds within REACH, walking there first.
func _seek(me: Node3D) -> void:
	var best: Node3D = null
	for spot in get_tree().get_nodes_in_group("fish_spot"):
		if Net.bench_held_by_other(str(spot.call("bench_key"))) or me.global_position.distance_to(spot.global_position) > REACH:
			continue
		if best == null or me.global_position.distance_to(spot.global_position) < me.global_position.distance_to(best.global_position):
			best = spot
	if best == null:
		return
	get_viewport().gui_release_focus()  # sitting is refused while the chat box has focus,
	me.call("set_typing_locked", false)  # and its typing lock can outlive the focus
	if not bool(best.call("try_fish", true)):
		me.call("command_walk_to", best.call("approach_point"))


## Plays fishing_hud.gd like a player: Cast, Space on the bite, then hold or release Space to keep
## the band on the fish, then Cast again once the card has been read.
func _play_hud(me: Node3D, delta: float) -> void:
	var hud: Node = me.get("_fish_hud")
	if hud == null:
		return
	var phase := str(hud.get("_phase"))
	if phase != _hud_phase:
		_hud_phase = phase
		_left = {"ready": 1.5, "card": 2.6, "bite": 0.35}.get(phase, 0.0)
	_left -= delta
	match phase:
		"ready", "card":
			if _left <= 0.0:
				_press_button(hud, "Cast" if phase == "ready" else "Cast again")
		"bite":
			if _left <= 0.0 and not _space_down:
				_space(true)
		"reel":
			var band_mid := float(hud.get("_band_y")) + float(hud.get("_band_h")) * 0.5
			_space(band_mid < float(hud.get("_fish_y")) + float(hud.get("_fish_v")) * 0.2)
		_:
			if _space_down:
				_space(false)


func _press_button(hud: Node, text: String) -> void:
	for b in hud.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
			return


func _space(down: bool) -> void:
	if down == _space_down:
		return
	_space_down = down
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = down
	Input.parse_input_event(e)
