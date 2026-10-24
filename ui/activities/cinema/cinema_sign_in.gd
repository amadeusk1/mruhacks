extends Control
## Cinema sign-in (one place for every "sign in needed": the HUD pill, the library, the close-up).
## The invite code goes straight to the gateway once and is never stored; the session then lasts for
## the whole game session (CinemaService keeps the client), across rooms.

const A := preload("res://ui/activities/act_style.gd")

var _code: LineEdit
var _go: Button
var _msg: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.12, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := A.panel(28, 28)
	A.pin(self, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-300, -190, 300, 190))
	var v := A.vbox(14)
	p.add_child(v)
	v.add_child(A.title("Sign in to the cinema", 32))
	var help := A.label("Enter the host code to pick movies, or the viewer code to watch.", 19, A.NAVY)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var f := UIKit.field("Invite code", "", false)
	_code = f["field"]
	_code.secret = true
	_code.custom_minimum_size.y = 50
	_code.text_submitted.connect(func(_t: String) -> void: _submit())
	v.add_child(f["root"])
	_msg = A.label("Ask whoever runs movie night for a code.", 16, A.SUB)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	var row := A.hbox(12)
	v.add_child(row)
	var cancel := A.button("Not now", "ghost", "", 18, Vector2(140, 52))
	cancel.pressed.connect(close)
	row.add_child(cancel)
	_go = A.button("Sign in", "primary", "users", 22, Vector2(0, 52))
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.pressed.connect(_submit)
	row.add_child(_go)
	_code.grab_focus.call_deferred()


func _submit() -> void:
	var c := _code.text.strip_edges()
	if c == "":
		_msg.text = "Type the code first."
		return
	_code.text = ""
	_go.disabled = true
	_go.text = "Signing in..."
	CinemaService.sign_in(c, _on_result)


func _on_result(ok: bool, err: String) -> void:
	if not is_inside_tree():
		return
	if ok:
		var host := bool(CinemaService.client.me.get("eligible", false))
		UIWidgets.toast(self, "Signed in · %s" % ("you can pick movies" if host else "watching along"), "check")
		close()
		return
	_go.disabled = false
	_go.text = "Sign in"
	_msg.text = err if err != "" else "That code didn't work. Check it and try again."
	_msg.add_theme_color_override("font_color", A.CORAL_DARK)
	_code.grab_focus()


func close() -> void:
	UIRouter.remove(self)
	queue_free()
