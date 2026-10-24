extends Control

## Zooms the room camera onto the cabinet, then plays that machine's game up close.

signal intent(action: String)

const A := preload("res://ui/activities/act_style.gd")
const _GAMES := {
	"pac": ["res://ui/activities/arcade/game_pac.gd", "Pac-Man", "Arrows or WASD"],
	"tetris": ["res://ui/activities/arcade/game_tetris.gd", "Tetris", "A/D move  ·  W rotate  ·  S drop  ·  Space slam"],
	"dino": ["res://ui/activities/arcade/game_dino.gd", "Dino Run", "Space or W jumps  ·  S ducks"],
}

var blocks_world := true
var game_id := "pac"
var anchor: Node
var _game: Control
var _score: Label
var _banner: Control
var _panel: Control
var _closed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.THEME
	_zoom()
	_build()
	_pop.call_deferred()


func _process(_delta: float) -> void:
	if _game == null or _score == null:
		return
	_score.text = str(int(_game.get("score")))
	var done := bool(_game.get("over"))
	if _banner:
		_banner.visible = done
		var note := _banner.get_node_or_null("Note") as Label
		if note and done:
			note.text = "Clear!" if bool(_game.get("won")) else "Game over"


func close() -> void:
	if _closed:
		return
	_closed = true
	_unpin()
	intent.emit("leave")
	UIRouter.remove(self)
	queue_free()


func _build() -> void:
	var info: Array = _GAMES.get(game_id, _GAMES["pac"])
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.14, 0.28)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = A.panel(18, 22)
	_panel.custom_minimum_size = Vector2(980, 640)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -490
	_panel.offset_top = -320
	_panel.offset_right = 490
	_panel.offset_bottom = 320
	add_child(_panel)
	var column := A.vbox(10)
	_panel.add_child(column)
	var head := A.hbox(12)
	column.add_child(head)
	head.add_child(A.title(str(info[1]), 36))
	head.add_child(A.expander())
	_score = A.title("0", 36)
	head.add_child(_score)
	var screen := SubViewportContainer.new()
	screen.custom_minimum_size = Vector2(0, 470)
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.stretch = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(screen)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(940, 470)
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.add_child(viewport)
	_game = (load(str(info[0])) as GDScript).new()
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(_game)
	var foot := A.hbox(12)
	column.add_child(foot)
	var leave := A.button("Leave", "secondary", "leave", 20, Vector2(160, 52))
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(close)
	foot.add_child(leave)
	foot.add_child(A.expander())
	foot.add_child(A.chip(str(info[2]), A.CARD, A.NAVY, "", 16))
	_banner = Control.new()
	_banner.visible = false
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.14, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(shade)
	var again := A.button("Play again", "primary", "rotate", 26, Vector2(280, 72))
	again.set_anchors_preset(Control.PRESET_CENTER)
	again.offset_left = -140
	again.offset_top = -70
	again.offset_right = 140
	again.offset_bottom = 2
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(_replay)
	_banner.add_child(again)
	var note := A.label("Game over", 28, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	note.name = "Note"
	note.set_anchors_preset(Control.PRESET_CENTER)
	note.offset_top = 16
	note.offset_bottom = 56
	note.offset_left = -160
	note.offset_right = 160
	_banner.add_child(note)


func _replay() -> void:
	if _game and _game.has_method("reset"):
		_game.call("reset")


func _pop() -> void:
	if _panel == null:
		return
	_panel.pivot_offset = Vector2(490, 320)
	_panel.scale = Vector2(0.22, 0.22)
	var tween := create_tween()
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _zoom() -> void:
	var rig := _rig()
	if rig == null or not rig.has_method("pin_focus"):
		return
	var point := _screen_point()
	rig.call("pin_focus", point, 1.15, 1.7, point.y)


func _unpin() -> void:
	var rig := _rig()
	if rig != null and rig.has_method("unpin_focus"):
		rig.call("unpin_focus")


func _screen_point() -> Vector3:
	if anchor != null and is_instance_valid(anchor) and anchor.has_meta("table") and anchor.has_meta("screen_local"):
		var cabinet := anchor.get_meta("table") as Node3D
		if cabinet != null and is_instance_valid(cabinet):
			return cabinet.global_transform * (anchor.get_meta("screen_local") as Vector3)
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player:
		return player.global_position + Vector3(0, 1.1, 0)
	return Vector3(0, 1.1, 0)


func _rig() -> Node:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return null
	return world.get_node_or_null("CameraRig")
