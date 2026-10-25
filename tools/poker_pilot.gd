extends Node

## Plays poker through the real table screen, for follow bots and film hosts: takes the free
## refill when out of chips, and on its turn checks when it can, else calls, now and then raising,
## after a short think like a player would.

const THINK := 1.2       # seconds before acting on a new turn
const RAISE_ODDS := 0.15

var _turn_key := ""
var _wait := 0.0


func _process(delta: float) -> void:
	var ui := _screen()
	if ui == null:
		_turn_key = ""
		return
	var s: Dictionary = ui.get("state")
	var phase := str(s.get("phase", ""))
	if phase == "waiting" and s.has("stack") and int(s.get("stack", 0)) == 0 and int(s.get("balance", 0)) == 0:
		_wait -= delta
		if _wait <= 0.0:
			_wait = 2.0
			ui.emit_signal("intent", "refill", null)
		return
	var legal: Array = s.get("legal", [])
	if legal.is_empty() or int(s.get("turn_seat", -1)) != int(s.get("my_seat", -2)):
		_turn_key = ""
		return
	var key := "%s|%s|%s" % [phase, s.get("pot", 0), (s.get("board", []) as Array).size()]
	if key != _turn_key:
		_turn_key = key
		_wait = THINK + randf() * 0.8
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 3.0  # once per turn; a new state resets it
	var kind := "check" if "check" in legal else "call"
	if "raise" in legal and randf() < RAISE_ODDS:
		kind = "raise"
	ui.call("_act", kind)


func _screen() -> Control:
	for c in UIRouter.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("poker_ui.gd"):
			return c
	return null
