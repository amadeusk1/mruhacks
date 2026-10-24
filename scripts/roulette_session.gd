extends Node

## Opens roulette when a penguin sits at the wheel, and moves the camera onto it.


const WHEEL := Vector3(-1.2, 0.758, 0.0)

var _ui = null


func _ready() -> void:
	Activities.requested.connect(_on_requested)
	Net.seat_denied.connect(_on_denied)


func _on_requested(activity: String, anchor: Node, _player: Node) -> void:
	if activity != "roulette" or _ui != null:
		return
	var table: Node3D = anchor.get_meta("table") if anchor.has_meta("table") else null
	var ui := preload("res://ui/activities/casino/roulette_ui.gd").new()
	ui.setup(table)
	ui.intent.connect(_on_intent)
	_ui = ui
	UIRouter.push(ui)
	_frame(table, false)


func _on_denied(_key: String) -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.close()


func _on_intent(action: String) -> void:
	if _ui == null:
		return
	if action == "spin":
		var table: Node3D = _ui.call("wheel_table")
		_frame(table, true)
		return
	if action != "leave":
		return
	_ui = null
	var rig := _rig()
	if rig != null and rig.has_method("unpin_focus"):
		rig.call("unpin_focus")
	var player := get_tree().get_first_node_in_group("local_player")
	if player != null and player.has_method("stand_up"):
		player.call("stand_up")


func _frame(table: Node3D, tight: bool) -> void:
	var rig := _rig()
	if rig == null or table == null or not rig.has_method("pin_focus"):
		return
	var point: Vector3 = table.global_transform * WHEEL
	if tight:
		rig.call("pin_focus", point, 1.85, 1.25, 0.74)
	else:
		rig.call("pin_focus", point, 3.1, 2.35, 0.7)


func _rig() -> Node:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return null
	return world.get_node_or_null("CameraRig")
