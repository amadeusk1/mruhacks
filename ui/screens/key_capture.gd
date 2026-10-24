class_name KeyCapture
extends UIModal
## "Press a key" capture for ControlsScreen; Move captures four keys in order (up, left, down, right).

var actions: Array = []
var target: Button
var _i := 0
var _pending := -1
var _hint: Label
var _conflict: HBoxContainer
const NAMES := {"move_forward": "up", "move_left": "left", "move_back": "down", "move_right": "right",
	"aim_down": "a lower shot arc", "aim_up": "a higher shot arc"}


func _init() -> void:
	setup("Press a key", "", 380, true, false)
	_hint = UIKit.label("", "Subtitle", HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_hint)
	_conflict = UIKit.hbox(10)
	_conflict.visible = false
	body.add_child(_conflict)


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var a: String = actions[_i]
	_hint.text = "Key for %s" % NAMES.get(a, a.replace("_", " ")) if actions.size() > 1 else "Press the new key, or Esc to cancel."


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or _conflict.visible:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		close()
		return
	var code: int = event.physical_keycode
	var owner := ControlsScreen._owner_of(code, actions[_i])
	if owner != "" and not (owner in actions):
		_pending = code
		_hint.text = "%s is used for %s." % [OS.get_keycode_string(code), owner.replace("_", " ")]
		for c in _conflict.get_children():
			c.queue_free()
		var rep := UIKit.button("Replace", "primary")
		rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep.pressed.connect(func() -> void:
			ControlsScreen.unbind(owner)  # the key moves; the other action becomes unbound
			_conflict.visible = false
			_apply(_pending))
		var can := UIKit.button("Cancel", "secondary")
		can.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		can.pressed.connect(close)
		_conflict.add_child(rep)
		_conflict.add_child(can)
		_conflict.visible = true
		return
	_apply(code)


func _apply(code: int) -> void:
	ControlsScreen._set_key(actions[_i], code)
	_i += 1
	if _i >= actions.size():
		ControlsScreen._save()
		target.text = "  ".join(actions.map(func(a): return ControlsScreen.key_text(a)))
		close()
	else:
		_refresh()
