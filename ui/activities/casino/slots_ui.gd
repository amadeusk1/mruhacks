extends Control
## Slots (three reels). The server decides the outcome; reels only present it.
##   apply_state({phase: "idle"|"pending"|"result", balance, cost, result: [sym, sym, sym], win})
##   intent("spin", {request_id})   - one request per press; disabled while pending (dedup)
##   intent("leave", null)
## Reconnecting during a spin: send the same result again and the reels land on it.

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const K := preload("res://ui/activities/casino/casino_kit.gd")
const Sfx := preload("res://scripts/casino/casino_sfx.gd")
const SYMBOLS := ["penguin", "star", "bell", "fish", "snowflake"]

var state := {"phase": "idle", "balance": 120, "cost": 5, "result": ["penguin", "star", "bell"], "win": 0}
var live := false
var _root: Control
var _reels: Array = []
var _note := ""
var _req := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func apply_state(s: Dictionary) -> void:
	var was := str(state.get("phase", ""))
	state.merge(s, true)
	_build()
	if str(state["phase"]) == "pending":
		for r in _reels:
			r.spinning = true
	elif str(state["phase"]) == "result" and was == "pending":
		for i in _reels.size():   # staggered stop on the server's symbols
			_reels[i].stop_on(str(state["result"][i]), 0.45 + i * 0.4)


func notice(message: String) -> void:
	_note = message
	if str(state.get("phase", "")) == "pending":
		state["phase"] = "idle"  # refused: stop the reels
	_build()
	_note = ""


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	var fr := K.frame()
	A.pin(_root, fr, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-330, -300, 330, 300))
	var v := A.vbox(8)
	fr.add_child(v)
	v.add_child(K.header("Slots", "Play chips: %d" % int(state.get("balance", 0))))
	var cab := PanelContainer.new()
	cab.add_theme_stylebox_override("panel", A.box(Color("#6B3E22"), 26, 8, Color("#D9A548"), 22))
	cab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cab)
	var cv := A.vbox(12)
	cab.add_child(cv)
	var win := int(state.get("win", 0))
	var msg := "Spin to play  ·  %d chips" % int(state.get("cost", 0))
	if str(state["phase"]) == "pending":
		msg = "Spinning..."
	elif str(state["phase"]) == "result":
		msg = ("You win %d chips!" % win) if win > 0 else "No match. Try again!"
	cv.add_child(A.label(_note if _note != "" else msg, 22, Color("#FBE7B5"), true, HORIZONTAL_ALIGNMENT_CENTER))
	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", A.box(Color("#3A2312"), 18, 0, Color.TRANSPARENT, 10))
	cv.add_child(window)
	var reels := A.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	window.add_child(reels)
	_reels.clear()
	for i in 3:
		var r := Reel.new()
		r.clip_contents = true
		r.custom_minimum_size = Vector2(170, 230)
		r.symbol = str(state["result"][i])
		reels.add_child(r)
		_reels.append(r)
	var acts := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(acts)
	var spin := K.action("Spin", "primary", 280)
	var broke := int(state.get("balance", 0)) < int(state.get("cost", 0))
	spin.disabled = str(state["phase"]) == "pending" or broke
	spin.tooltip_text = "Not enough play chips" if broke else ""
	spin.pressed.connect(_spin)
	acts.add_child(spin)
	var leave := K.action("Leave", "secondary", 200)
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	acts.add_child(leave)
	if broke and str(state["phase"]) != "pending":
		var card := K.state_card("insufficient", "Your purse is empty. Grab a free refill of play chips.")
		A.pin(_root, card, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-230, -170, 230, 170))
		var refill := K.action("Free refill", "primary", 220)
		refill.pressed.connect(func() -> void: intent.emit("refill", null))
		(card.get_child(0) as VBoxContainer).add_child(refill)


func _spin() -> void:
	_req += 1
	apply_state({"phase": "pending"})  # before the intent: in Solo the result comes back synchronously
	intent.emit("spin", {"request_id": "%d-%d" % [Time.get_ticks_msec(), _req]})


func close() -> void:
	intent.emit("leave", null)


func preview(s: String) -> void:
	if s == "spinning":
		apply_state({"phase": "pending"})
	else:
		apply_state({"phase": "idle", "result": ["penguin", "star", "bell"]})


class Reel:
	extends Control
	var symbol := "penguin"
	var spinning := false
	var _offset := 0.0
	var _stop_in := -1.0
	var _target := ""

	func stop_on(sym: String, delay: float) -> void:
		_target = sym
		_stop_in = delay
		spinning = true

	func _process(delta: float) -> void:
		if not spinning:
			return
		_offset = fmod(_offset + delta * 9.0, 1.0)
		if _stop_in >= 0.0:
			_stop_in -= delta
			if _stop_in <= 0.0:
				Sfx.play(self, "reel_stop", -10.0)
				spinning = false
				symbol = _target
				_offset = 0.0
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FBF6EC")
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var syms: Array = SYMBOLS
		var idx := syms.find(symbol)
		for k in [-1, 0, 1]:
			var s: String = syms[posmod(idx + k + (int(_offset * 5) if spinning else 0), syms.size())]
			var y: float = size.y * (0.5 + k * 0.62 + (_offset if spinning else 0.0) * 0.62)
			_glyph(s, Vector2(size.x * 0.5, y), size.x * 0.33, 0.35 if k != 0 else 1.0)

	func _glyph(s: String, c: Vector2, rad: float, alpha: float) -> void:
		match s:
			"penguin":
				draw_circle(c, rad, Color(0.2, 0.42, 0.8, alpha))
				draw_circle(c + Vector2(0, rad * 0.2), rad * 0.65, Color(0.98, 0.95, 0.88, alpha))
				draw_circle(c + Vector2(-rad * 0.3, -rad * 0.2), rad * 0.1, Color(0.1, 0.1, 0.12, alpha))
				draw_circle(c + Vector2(rad * 0.3, -rad * 0.2), rad * 0.1, Color(0.1, 0.1, 0.12, alpha))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.15, 0), c + Vector2(rad * 0.15, 0), c + Vector2(0, rad * 0.2)]), Color(0.95, 0.6, 0.2, alpha))
			"star":
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI * 0.5 + TAU * i / 10.0
					pts.append(c + Vector2(cos(a), sin(a)) * rad * (1.0 if i % 2 == 0 else 0.45))
				draw_colored_polygon(pts, Color(0.88, 0.25, 0.25, alpha))
			"bell":
				draw_circle(c + Vector2(0, -rad * 0.2), rad * 0.62, Color(0.95, 0.72, 0.2, alpha))
				draw_rect(Rect2(c + Vector2(-rad * 0.85, rad * 0.05), Vector2(rad * 1.7, rad * 0.45)), Color(0.95, 0.72, 0.2, alpha))
				draw_circle(c + Vector2(0, rad * 0.62), rad * 0.18, Color(0.8, 0.52, 0.12, alpha))
			"fish":
				draw_circle(c, rad * 0.62, Color(0.95, 0.55, 0.2, alpha))
				draw_colored_polygon(PackedVector2Array([c + Vector2(rad * 0.5, 0), c + Vector2(rad, -rad * 0.5), c + Vector2(rad, rad * 0.5)]), Color(0.95, 0.55, 0.2, alpha))
				draw_circle(c + Vector2(-rad * 0.25, -rad * 0.15), rad * 0.1, Color(0.1, 0.1, 0.12, alpha))
			_:
				for i in 3:
					var a := PI * i / 3.0
					draw_line(c - Vector2(cos(a), sin(a)) * rad, c + Vector2(cos(a), sin(a)) * rad, Color(0.35, 0.7, 0.9, alpha), rad * 0.18)
