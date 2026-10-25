extends Control

## Zooms the room camera onto the cabinet, then plays that machine's game up close:
## a 3-2-1 start, sounds and screen shake, the cabinet's high score table (ArcadeNet, shared by
## everyone) and your personal best. The score is shown on the cabinet's 3D screen while you play.

signal intent(action: String)

const A := preload("res://ui/activities/act_style.gd")
const _GAMES := {
	"pac": ["res://ui/activities/arcade/game_pac.gd", "Pac-Man", "Arrows or WASD"],
	"tetris": ["res://ui/activities/arcade/game_tetris.gd", "Tetris", "A/D move  ·  W rotate  ·  S drop  ·  Space slam"],
	"dino": ["res://ui/activities/arcade/game_dino.gd", "Dino Run", "Space or W jumps  ·  S ducks"],
	"fish": ["res://ui/activities/arcade/game_fish.gd", "Fish Frenzy", "WASD or arrows swim  ·  eat smaller fish"],
	"star": ["res://ui/activities/arcade/game_star.gd", "Star Patrol", "A/D move  ·  Space fires"],
}
const MOBILE_HINTS := {
	"pac": "Stick steers",
	"tetris": "Stick moves · up rotates · down drops · Jump slams",
	"dino": "Jump hops · stick down ducks",
	"fish": "Stick swims",
	"star": "Stick moves · Jump shoots",
}

var blocks_world := true
var game_id := "pac"
var anchor: Node
var cab_key := ""
var _game: Control
var _score: Label
var _banner: Control
var _panel: Control
var _closed := false
var _screen: Control
var _count: Label
var _board_rows: VBoxContainer
var _best: Label
var _last_score := 0
var _was_over := false
var _shake := 0.0
var _report := 0.0
var _start_left := 3.0


func _ready() -> void:
	add_to_group("touch_play")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.THEME
	_zoom()
	_build()
	_pop.call_deferred()


func _process(delta: float) -> void:
	if _game == null or _score == null:
		return
	if _start_left > 0.0:
		var before := int(ceil(_start_left))
		_start_left -= delta
		var n := int(ceil(_start_left))
		if n != before or _count.text == "":
			_count.text = str(n) if n > 0 else "GO!"
			Sfx.play(self, "count" if n > 0 else "go", -5.0)
		if _start_left <= 0.0:
			_game.process_mode = Node.PROCESS_MODE_INHERIT
			get_tree().create_timer(0.5).timeout.connect(func() -> void: _count.text = "")
	var score := int(_game.get("score"))
	_score.text = str(score)
	if score > _last_score and score - _last_score >= 10:
		Sfx.play(self, "blip", -12.0, 1.0 + minf(0.5, float(score - _last_score) / 400.0))
	_last_score = score
	var done := bool(_game.get("over"))
	if done and not _was_over:
		_game_over(score)
	_was_over = done
	if _banner:
		_banner.visible = done
	_shake = maxf(0.0, _shake - delta * 2.5)
	if _screen:
		_screen.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * _shake * _shake
	_report -= delta
	if _report <= 0.0 and not done:
		_report = 1.0
		ArcadeNet.report_playing(cab_key, game_id, score)


func _game_over(score: int) -> void:
	_shake = 1.0
	Sfx.play(self, "lose", -4.0)
	var best := ArcadeNet.note_local_best(game_id, score)
	ArcadeNet.submit_score(game_id, score)
	ArcadeNet.report_playing(cab_key, game_id, score)
	var note := _banner.get_node_or_null("Note") as Label
	if note:
		note.text = ("New personal best! %d" % score) if best else ("Game over  ·  %d" % score)
	_best.text = "Your best  %d" % ArcadeNet.best_of(game_id)


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
	if Mobile.active():
		_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.offset_left = 10
		_panel.offset_top = 10
		_panel.offset_right = -10
		_panel.offset_bottom = -(Mobile.pad() + 8.0)
		_panel.custom_minimum_size = Vector2.ZERO
	add_child(_panel)
	var column := A.vbox(10)
	_panel.add_child(column)
	var head := A.hbox(12)
	column.add_child(head)
	head.add_child(A.title(str(info[1]), 36))
	head.add_child(A.expander())
	_score = A.title("0", 36)
	head.add_child(_score)
	var body := A.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 220) if Mobile.active() else Vector2(700, 470)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	body.add_child(frame)
	var screen := SubViewportContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.stretch = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(screen)
	_screen = screen
	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 470)
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.add_child(viewport)
	_game = (load(str(info[0])) as GDScript).new()
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game.process_mode = Node.PROCESS_MODE_DISABLED  # until the 3-2-1
	viewport.add_child(_game)
	if Mobile.active():
		_best = A.label("Best %d" % ArcadeNet.best_of(game_id), 18, A.TEAL_DARK, true)
		head.add_child(_best)
	else:
		body.add_child(_side_panel())
	_count = A.title("", 120, HORIZONTAL_ALIGNMENT_CENTER)
	_count.add_theme_color_override("font_color", A.WHITE)
	_count.add_theme_color_override("font_outline_color", A.NAVY)
	_count.add_theme_constant_override("outline_size", 20)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_count)
	var foot := A.hbox(12)
	column.add_child(foot)
	var leave := A.button("Leave", "secondary", "leave", 20, Vector2(160, 52))
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(close)
	foot.add_child(leave)
	foot.add_child(A.expander())
	var hint := str(MOBILE_HINTS.get(game_id, "Stick moves · Jump button")) if Mobile.active() else str(info[2])
	foot.add_child(A.chip(hint, A.CARD, A.NAVY, "", 16))
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
	var out := A.button("Leave", "secondary", "leave", 22, Vector2(200, 56))  # leave without replaying
	out.set_anchors_preset(Control.PRESET_CENTER)
	out.offset_left = -100
	out.offset_top = 70
	out.offset_right = 100
	out.offset_bottom = 126
	out.focus_mode = Control.FOCUS_NONE
	out.pressed.connect(close)
	_banner.add_child(out)


func _replay() -> void:
	if _game and _game.has_method("reset"):
		_game.call("reset")
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		_start_left = 3.0
		_last_score = 0
		_was_over = false


## High score table for this game (everyone's) and your own best.
func _side_panel() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.box(A.CARD, 16, 0, Color.TRANSPARENT, 12))
	p.custom_minimum_size = Vector2(220, 0)
	var v := A.vbox(6)
	p.add_child(v)
	var head := A.hbox(8)
	head.add_child(A.icon("trophy", 24, A.CORAL))
	head.add_child(A.label("High scores", 20, A.NAVY, true))
	v.add_child(head)
	_board_rows = A.vbox(2)
	v.add_child(_board_rows)
	v.add_child(A.expander())
	_best = A.label("Your best  %d" % ArcadeNet.best_of(game_id), 18, A.TEAL_DARK, true)
	v.add_child(_best)
	ArcadeNet.boards_changed.connect(_fill_board)
	_fill_board()
	return p


func _fill_board() -> void:
	if _board_rows == null or not is_instance_valid(_board_rows):
		return
	for c in _board_rows.get_children():
		c.queue_free()
	var list: Array = ArcadeNet.boards.get(game_id, [])
	if list.is_empty():
		_board_rows.add_child(A.label("No scores yet!", 16, A.SUB))
	for i in mini(list.size(), 8):
		var row := A.hbox(6)
		row.add_child(A.label("%d" % (i + 1), 16, A.CORAL if i == 0 else A.NAVY, true))
		var n := A.label(str(list[i]["name"]), 16, A.NAVY)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		row.add_child(n)
		row.add_child(A.label(str(int(list[i]["score"])), 16, A.NAVY, true))
		_board_rows.add_child(row)


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
