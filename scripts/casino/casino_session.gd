extends Node
## Client side of the casino: watches the room while you're inside it (so the tables show live
## play), opens the game screen when you sit at a table or machine, turns its intents into Casino
## requests and the host's views back into screen state, plays the synced seated reactions on
## whoever made them, and adds the table sounds. Replaces the old local-only roulette session.

const SCREENS := {
	"roulette": "res://ui/activities/casino/roulette_ui.gd",
	"blackjack": "res://ui/activities/casino/blackjack_ui.gd",
	"poker": "res://ui/activities/casino/poker_ui.gd",
	"slots": "res://ui/activities/casino/slots_ui.gd",
}
const FX := preload("res://scripts/casino/casino_table_fx.gd")
const Sfx := preload("res://scripts/casino/casino_sfx.gd")

var _ui: Control = null
var _table := ""
var _game := ""
var _inside := false
var _fx: Node3D = null
var _balance := 0
var _last := {}           # table -> last view (late-opening screens start from it)
var _slot_spin := -1


func _ready() -> void:
	Activities.requested.connect(_on_requested)
	Net.seat_denied.connect(func(_key: String) -> void: _close(false))
	Casino.view.connect(_on_view)
	Casino.gesture.connect(_on_gesture)
	Casino.balance.connect(_on_balance)
	Casino.notice.connect(_on_notice)


func _process(_delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var here := world != null and world.has_method("current_location_id") and str(world.call("current_location_id")) == "casino"
	if here == _inside and (not here or is_instance_valid(_fx)):
		return
	_inside = here
	if is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null
	if here:
		var room: Node = world.get_node("LocationHost").get_child(0) if world.has_node("LocationHost") and world.get_node("LocationHost").get_child_count() > 0 else null
		if room == null:
			_inside = false
			return
		_fx = FX.new()
		_fx.name = "CasinoTableFx"
		room.add_child(_fx)
		_fx.setup(room)
		Casino.watch(true)
	else:
		_close(false)
		Casino.watch(false)
		_last.clear()


func _on_requested(activity: String, anchor: Node, _player: Node) -> void:
	if not SCREENS.has(activity) or _ui != null:
		return
	_game = activity
	_table = activity
	var seat := 0
	var n := String(anchor.name)
	if activity == "slots":
		_table = "slot_" + n.trim_prefix("Slot_")
	elif n.contains("_seat_"):
		seat = int(n.get_slice("_seat_", 1))
	var ui: Control = (load(SCREENS[activity]) as GDScript).new()
	ui.set("live", true)
	_ui = ui
	ui.connect("intent", _on_intent)
	UIRouter.push(ui)
	_slot_spin = -1
	if _last.has(_table):
		_apply(_last[_table])
	elif ui.has_method("apply_state"):
		ui.call("apply_state", {"phase": "reconnecting", "balance": _balance})
	Casino.join(_table, seat, anchor.call("bench_key") if anchor.has_method("bench_key") else "")
	if activity == "roulette" and anchor.has_meta("table"):
		_frame(anchor.get_meta("table"))
	_own_tags(false)


func _on_intent(action: String, value = null) -> void:
	if _ui == null:
		return
	match action:
		"leave", "close":
			_close(true)
		"refill":
			Casino.refill()
		_:
			var data: Dictionary = value if value is Dictionary else {"amount": value}
			Casino.act(_table, action, data)
			if action in ["bet", "spin", "deal", "hit", "stand", "double", "split", "raise", "call", "check", "fold"]:
				_pay("casino", 5)
			if action in ["bet", "spin", "raise", "call"]:
				Sfx.play(self, "chip" if action != "spin" else "lever", -8.0)


func _pay(id: String, coins: int) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("note_activity"):
		world.call("note_activity", id, coins)


func _close(stand: bool) -> void:
	if _ui == null:
		return
	var ui := _ui
	_ui = null
	Casino.leave(_table)
	_table = ""
	if is_instance_valid(ui):
		UIRouter.remove(ui)
		ui.queue_free()
	var rig := _rig()
	if rig != null and rig.has_method("unpin_focus"):
		rig.call("unpin_focus")
	_own_tags(true)
	if stand:
		var player := get_tree().get_first_node_in_group("local_player")
		if player != null and player.has_method("stand_up"):
			player.call("stand_up")


func _on_view(table: String, v: Dictionary) -> void:
	_last[table] = v
	_balance = int(v.get("balance", _balance))
	if is_instance_valid(_fx):
		_fx.show_view(table, v)
	if table == _table and _ui != null:
		_apply(v)


## Host view -> the screen's apply_state contract (see each casino UI's header comment).
func _apply(v: Dictionary) -> void:
	var s := v.duplicate()
	s["balance"] = _balance
	if _game == "slots":
		var spin := int(v.get("spin", 0))
		if _slot_spin < 0:
			_slot_spin = spin
			s["phase"] = "idle"
		elif spin != _slot_spin:
			_slot_spin = spin
			s["phase"] = "result"
			var win := int(v.get("win", 0))
			get_tree().create_timer(1.7).timeout.connect(func() -> void:
				Sfx.play(self, "big_win" if win >= 50 else ("win" if win > 0 else "lose"), -6.0))
		else:
			s.erase("phase")
	elif _game == "blackjack" and v.get("my_seat", -1) < 0 and str(v.get("phase", "")) != "waiting":
		s["phase"] = "reconnecting"
	_ui.call("apply_state", s)


func _on_balance(n: int) -> void:
	_balance = n
	if _ui != null and _last.has(_table):
		var v: Dictionary = _last[_table].duplicate()
		v["balance"] = n
		_last[_table] = v
		_apply(v)


func _on_notice(table: String, message: String) -> void:
	if (table == _table or table == "") and _ui != null and _ui.has_method("notice"):
		_ui.call("notice", message)


## Synced seated reactions: the host names who and which casino clip; every client in the room plays it.
func _on_gesture(peer: int, clip: String) -> void:
	var who: Node = null
	if peer == Net.local_id():
		who = get_tree().get_first_node_in_group("local_player")
	else:
		var world := get_tree().get_first_node_in_group("world")
		var puppets = world.get("_puppets") if world != null else null
		if puppets is Dictionary:
			who = puppets.get(peer)
	if who == null or not is_instance_valid(who):
		return
	var ap: AnimationPlayer = null
	for n in who.find_children("*", "AnimationPlayer", true, false):
		if (n as AnimationPlayer).has_animation_library("casino"):
			ap = n
			break
	if ap == null:
		return
	var name := PenguinAnims.resolve(ap, clip, "casino")
	if name == "":
		return
	var idle := PenguinAnims.resolve(ap, "casino/casino_seated_idle", "")
	if idle == "":
		idle = PenguinAnims.resolve(ap, "casino/casino_seated_idle_loop", "")
	ap.speed_scale = 1.0
	ap.play(name, 0.12)
	if idle != "" and who.has_method("is_sitting") and bool(who.call("is_sitting")):
		ap.queue(idle)  # back to the seated loop afterwards
	if clip.ends_with("cheer_seated") and peer == Net.local_id():
		Sfx.play(self, "win", -6.0)


## Your own name tag sits between the pinned camera and the table: hide it while you play.
func _own_tags(show: bool) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	for l in player.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = show


func _frame(table: Node3D) -> void:
	var rig := _rig()
	if rig == null or not rig.has_method("pin_focus"):
		return
	var b: Array = AssetRegistry.sockets("casino/roulette_table").get("socket_wheel_center", [-1.2, 0.0, 0.758])
	rig.call("pin_focus", table.global_transform * Vector3(b[0], b[2], -b[1]), 2.6, 2.2, 0.72)


func _rig() -> Node:
	var world := get_tree().get_first_node_in_group("world")
	return world.get_node_or_null("CameraRig") if world != null else null
