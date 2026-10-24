extends Node
## Launch the authenticated cinema overlay from a kiosk or claimed auditorium seat.
const Player := preload("res://ui/activities/cinema/cinema_player.gd")
var _overlay: Control
var _player: Node
var _seat: Node

func _ready() -> void:
	Activities.requested.connect(_on_activity)

func _on_activity(activity: String, anchor: Node, player: Node) -> void:
	if activity != "cinema" or is_instance_valid(_overlay):
		return
	_player = player
	_seat = anchor if anchor is SeatSpot else null
	_overlay = Player.new()
	_overlay.finished.connect(_on_finished)
	UIRouter.push(_overlay)
	if is_instance_valid(_player) and _player.has_method("set_typing_locked"):
		_player.call("set_typing_locked", true)

func _on_finished() -> void:
	if is_instance_valid(_player):
		if is_instance_valid(_seat) and _player.has_method("current_bench") and _player.call("current_bench") == _seat:
			_player.call("stand_up")
		if _player.has_method("set_typing_locked"):
			_player.call("set_typing_locked", false)
	_overlay = null
	_player = null
	_seat = null
