extends Node

## Settings > Hide UI, then Escape. Needs a window (screenshots):
##   Godot --path . res://tools/hide_ui_check.tscn -- --out=C:/some/dir
## Prints HIDE_UI lines and saves hide_ui_before/settings/hidden/after.png; exits 1 on a failed check.

var _w: Node
var _out := OS.get_environment("TEMP")
var _fail := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	while not _w.get("_in_game") or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(3.0).timeout
	await _shot("before")
	UIRouter.open_pause()
	UIRouter.push(SettingsScreen.new())
	await get_tree().create_timer(0.5).timeout
	var btn := UIRouter.top().find_child("HideUi", true, false) as Button
	_check("button in settings", btn != null)
	if btn == null:
		get_tree().quit(1)
		return
	await _shot("settings")
	btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	var tag := _w.get_node("Penguin").get_node_or_null("NameLabel") as Label3D
	_check("menus closed", not UIRouter.is_open())
	_check("hud culled", get_viewport().canvas_cull_mask == UIRouter.EFFECT_LAYER)
	_check("name tag hidden", tag != null and tag.layers == 0)
	await _shot("hidden")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().create_timer(0.8).timeout
	_check("ui back", not UIRouter.ui_hidden and get_viewport().canvas_cull_mask == 0xFFFFF)
	_check("name tag back", tag.layers != 0)
	_check("pause menu open", UIRouter.top() is PauseMenu)
	await _shot("after")
	print("HIDE_UI %s" % ("PASS" if _fail == 0 else "FAIL %d" % _fail))
	get_tree().quit(1 if _fail else 0)


func _check(what: String, ok: bool) -> void:
	print("HIDE_UI %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hide_ui_%s.png" % [_out, tag])
