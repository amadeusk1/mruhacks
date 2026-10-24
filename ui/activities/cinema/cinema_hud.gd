extends Control
## Auditorium HUD while seated (Images/Moonbound Watch Party.png + Movie Night Scene.png):
## slim dark playback bar (host-only play/pause and scrub), "Movie night · N friends" chip,
## seat actions + "Leave seat", and chat speech bubbles over penguins' heads.
## The film itself plays in-world on the big screen (scene side, via CinemaSession).

const A := preload("res://ui/activities/act_style.gd")
const INK := Color(0.05, 0.08, 0.15, 0.86)
const EDGE := Color(1, 1, 1, 0.2)
const SKY := Color("#5BC0F0")
const DIM := Color("#C9D3E6")
const GOLD := Color("#E9C46A")
const BUBBLE_S := 5.0

var blocks_world := false     ## UIRouter: chat and camera stay live while seated
var seat: Node
var player: Node
var _pp: Button
var _title: Label
var _time: Label
var _bar: ScrubBar
var _watching: Label
var _friends: Label
var _host_btn: Button
var _popcorn: Button
var _snack_in := 0.0
var _bubbles: Array = []      # [{panel, node, until}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var s := CinemaSession
	# method callables (not lambdas) so the autoload drops them when this HUD is freed
	s.film_selected.connect(_sync.unbind(2))
	s.playback_changed.connect(_sync.unbind(2))
	s.watchers_changed.connect(_sync.unbind(1))
	Net.chat_received.connect(_on_chat)
	_sync()


func _build() -> void:
	# --- playback bar ---
	var bar := PanelContainer.new()
	var sb := A.box(INK, 24, 0, Color.TRANSPARENT, 0)
	sb.set_border_width_all(2)
	sb.border_color = EDGE
	sb.content_margin_left = 16
	sb.content_margin_right = 7
	bar.add_theme_stylebox_override("panel", sb)
	A.pin(self, bar, Vector4(0.5, 1, 0.5, 1), Vector4(-536, -72, 536, -24))
	var row := A.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	_pp = _round("pause", 36)
	_pp.pressed.connect(func() -> void: CinemaSession.set_playing(not CinemaSession.playing))
	row.add_child(_pp)
	_title = A.label("", 18, A.WHITE, true)
	_title.custom_minimum_size.x = 150
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	_bar = ScrubBar.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size = Vector2(200, 30)
	_bar.seek.connect(func(f: float) -> void: CinemaSession.seek(f * float(CinemaSession.film.get("duration_s", 0.0))))
	row.add_child(_bar)
	_time = A.label("", 15, DIM, false)
	_time.custom_minimum_size.x = 118
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_time)
	var pill := _pill(EDGE)
	var ph := A.hbox(10)
	pill.add_child(ph)
	ph.add_child(A.icon("users", 24, A.WHITE))
	_watching = A.label("", 16, A.WHITE, false)
	ph.add_child(_watching)
	row.add_child(pill)
	# --- bottom-left: movie night chip (+ host menu) ---
	var left := A.hbox(10)
	A.pin(self, left, Vector4(0, 1, 0, 1), Vector4(24, -132, 600, -84))
	var chip := _pill(Color(1, 1, 1, 0.32))
	var ch := A.hbox(12)
	chip.add_child(ch)
	ch.add_child(A.icon("users", 26, A.WHITE))
	_friends = A.label("", 17, A.WHITE, false)
	ch.add_child(_friends)
	left.add_child(chip)
	_host_btn = _round("star", 46, "Host options")
	_host_btn.pressed.connect(_host_menu)
	left.add_child(_host_btn)
	# --- bottom-right: seat actions + leave ---
	var right := A.hbox(10, BoxContainer.ALIGNMENT_END)
	A.pin(self, right, Vector4(1, 1, 1, 1), Vector4(-700, -132, -24, -84))
	_popcorn = _round("popcorn", 46, "Popcorn")
	_popcorn.toggle_mode = true
	_popcorn.toggled.connect(_toggle_popcorn)
	right.add_child(_popcorn)
	var save := _round("seat_plus", 46, "Save a seat for a friend")
	save.pressed.connect(_save_seat)
	right.add_child(save)
	var close_up := _round("eye", 46, "Close-up (Esc to return)")
	close_up.pressed.connect(CinemaSession.open_closeup)
	right.add_child(close_up)
	var leave := Button.new()
	leave.text = "Leave seat"
	leave.icon = A.icon_tex("sofa")
	leave.focus_mode = Control.FOCUS_ALL
	leave.custom_minimum_size = Vector2(0, 48)
	leave.add_theme_font_override("font", A.title_font())
	leave.add_theme_font_size_override("font_size", 18)
	leave.add_theme_constant_override("icon_max_width", 24)
	leave.add_theme_constant_override("h_separation", 12)
	for st in [["normal", INK], ["hover", Color(0.1, 0.14, 0.24, 0.92)], ["pressed", Color(0.03, 0.05, 0.1, 0.95)], ["focus", INK]]:
		var b := A.box(st[1], 24, 2, GOLD, 0)
		b.content_margin_left = 22
		b.content_margin_right = 24
		leave.add_theme_stylebox_override(st[0], b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		leave.add_theme_color_override(c, A.WHITE)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		leave.add_theme_color_override(c, Color("#F4DFA4"))
	leave.pressed.connect(close)
	right.add_child(leave)


func _pill(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var b := A.box(INK, 24, 2, border, 0)
	b.content_margin_left = 18
	b.content_margin_right = 20
	b.content_margin_top = 5
	b.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", b)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _round(icon_name: String, size: int, tip := "") -> Button:
	var b := Button.new()
	b.icon = A.icon_tex(icon_name)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	var pad := int(size * 0.27)
	for st in [["normal", Color(1, 1, 1, 0.0) if size < 40 else INK], ["hover", Color(1, 1, 1, 0.14)],
			["pressed", Color(SKY, 0.35)], ["disabled", Color(1, 1, 1, 0.0) if size < 40 else INK], ["focus", Color.TRANSPARENT]]:
		var s := A.box(st[1], size / 2, 2, Color(1, 1, 1, 0.55) if size < 40 else EDGE, pad)
		if st[0] == "focus":
			s.border_color = SKY
		b.add_theme_stylebox_override(st[0], s)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, A.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
	return b


func _sync() -> void:
	var s := CinemaSession
	var host := s.is_host()
	var has_film := not s.film.is_empty()
	_pp.icon = A.icon_tex("pause" if s.playing else "play")
	_pp.disabled = not host or not has_film
	_pp.tooltip_text = "Pause for everyone" if host else "Only the host controls playback"
	_title.text = str(s.film.get("title", "Waiting for the host")).to_upper() if has_film else "WAITING FOR A FILM"
	_bar.editable = host and has_film
	var n := maxi(s.watchers.size(), 1)
	_watching.text = "%d watching" % n
	_friends.text = "Movie night · %d friend%s" % [n, "" if n == 1 else "s"]
	_host_btn.visible = host
	_tick()


func _tick() -> void:
	var s := CinemaSession
	var dur := float(s.film.get("duration_s", 0.0))
	var pos := s.position_now()
	_bar.value = pos / dur if dur > 0.0 else 0.0
	_time.text = "%s / %s" % [clock(pos), clock(dur)] if dur > 0.0 else "--:-- / --:--"


static func clock(t: float) -> String:
	var x := int(t)
	return "%d:%02d:%02d" % [x / 3600, (x / 60) % 60, x % 60] if x >= 3600 else "%d:%02d" % [x / 60, x % 60]


func _process(delta: float) -> void:
	_tick()
	_place_bubbles()
	if _popcorn.button_pressed:
		_snack_in -= delta
		if _snack_in <= 0.0:
			_snack_in = randf_range(9.0, 18.0)
			if is_instance_valid(player) and player.has_method("play_seated"):
				player.call("play_seated", "cinema/cinema_snack")


# ---- host ------------------------------------------------------------------------------
func _host_menu() -> void:
	var m := PopupMenu.new()
	m.theme = UIKit.THEME
	var hand := PopupMenu.new()
	hand.name = "HandOff"
	for w in CinemaSession.watchers:
		if int(w["id"]) != Net.local_id():
			hand.add_item(str(w["name"]), int(w["id"]))
	if hand.item_count == 0:
		hand.add_item("No one else is seated", -1)
		hand.set_item_disabled(0, true)
	hand.id_pressed.connect(func(id: int) -> void:
		CinemaSession.hand_off(id)
		UIWidgets.toast(self, "Host handed off", "star"))
	m.add_child(hand)
	m.add_submenu_node_item("Hand off host", hand)
	m.add_item("Pick another film (lobby kiosk)", 1)
	m.id_pressed.connect(func(id: int) -> void:
		if id == 1:
			CinemaSession.open_kiosk())
	add_child(m)
	m.popup_hide.connect(m.queue_free)
	m.popup(Rect2i(Vector2i(_host_btn.global_position) + Vector2i(0, -110), Vector2i(260, 0)))


# ---- seat props ------------------------------------------------------------------------
func _toggle_popcorn(on: bool) -> void:
	if is_instance_valid(player) and player.has_method("hold_prop"):
		player.call("hold_prop", "interaction_props/popcorn_tub" if on else "")
	_snack_in = 1.2 if on else 0.0


## Saves the nearest free seat next to ours (the reservation marker shows for everyone).
func _save_seat() -> void:
	if not is_instance_valid(seat):
		return
	var best: SeatSpot = null
	var best_d := INF
	for n in seat.get_parent().get_children():
		var sp := n as SeatSpot
		if sp == null or sp == seat or sp.kit != "cinema" or CinemaSession.saved_seats.has(String(sp.name)) \
				or Net.bench_held_by_other(sp.bench_key()):
			continue
		var d: float = sp.seat_point.distance_to((seat as SeatSpot).seat_point)
		if d < best_d:
			best = sp
			best_d = d
	if best == null:
		UIWidgets.toast(self, "No free seat nearby", "seat")
		return
	CinemaSession.save_seat(String(best.name))
	CinemaSession.say("Saved you a seat")


# ---- speech bubbles --------------------------------------------------------------------
func _on_chat(speaker: String, message: String) -> void:
	var who: Node3D = null
	for p in get_tree().get_nodes_in_group("player"):
		var tag := (p as Node).get_node_or_null("NameLabel") as Label3D
		if tag and tag.text == speaker:
			who = p
	if who == null:
		return
	for b in _bubbles.filter(func(x: Dictionary) -> bool: return x["node"] == who):
		(b["panel"] as Control).queue_free()
		_bubbles.erase(b)
	var panel := bubble(message)
	add_child(panel)
	_bubbles.append({"panel": panel, "node": who, "until": Time.get_ticks_msec() + BUBBLE_S * 1000.0})


static func bubble(message: String) -> PanelContainer:
	var p := PanelContainer.new()
	var b := A.box(Color(0.07, 0.1, 0.2, 0.9), 16, 2, Color(0.7, 0.78, 0.92, 0.55), 0)
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 8
	b.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", b)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := A.label(message.substr(0, 60), 17, A.WHITE, false)
	p.add_child(l)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(-4, 12)])
	tail.color = Color(0.07, 0.1, 0.2, 0.9)
	tail.name = "Tail"
	p.add_child(tail)
	p.resized.connect(func() -> void: tail.position = Vector2(p.size.x * 0.32, p.size.y - 1))
	return p


func _place_bubbles() -> void:
	var cam := get_viewport().get_camera_3d()
	var now := Time.get_ticks_msec()
	for b in _bubbles.duplicate():
		var panel: Control = b["panel"]
		if now > b["until"] or not is_instance_valid(b["node"]):
			panel.queue_free()
			_bubbles.erase(b)
			continue
		var head: Vector3 = (b["node"] as Node3D).global_position + Vector3(0, 1.75, 0)
		panel.visible = cam != null and not cam.is_position_behind(head)
		if panel.visible:
			panel.position = cam.unproject_position(head) - Vector2(panel.size.x * 0.32, panel.size.y + 14)


func close() -> void:
	if is_instance_valid(player):
		if player.has_method("hold_prop"):
			player.call("hold_prop", "")
		if player.has_method("stand_up") and player.has_method("current_bench") and player.call("current_bench") == seat:
			player.call("stand_up")
	queue_free()


## Thin rounded progress track; the host drags or clicks it to seek.
class ScrubBar:
	extends Control
	signal seek(fraction: float)
	var value := 0.0
	var editable := false
	var _drag := -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _process(_d: float) -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if editable else Control.CURSOR_ARROW
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if not editable:
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_drag = clampf(e.position.x / size.x, 0.0, 1.0)
			elif _drag >= 0.0:
				seek.emit(_drag)
				_drag = -1.0
			accept_event()
		elif e is InputEventMouseMotion and _drag >= 0.0:
			_drag = clampf(e.position.x / size.x, 0.0, 1.0)
			accept_event()

	func _draw() -> void:
		var h := 12.0
		var y := (size.y - h) * 0.5
		var f := _drag if _drag >= 0.0 else clampf(value, 0.0, 1.0)
		draw_style_box(_rr(Color(1, 1, 1, 0.14)), Rect2(0, y, size.x, h))
		if f > 0.0:
			draw_style_box(_rr(Color("#5BC0F0")), Rect2(0, y, maxf(size.x * f, h), h))
		if editable and (_drag >= 0.0 or get_global_rect().has_point(get_global_mouse_position())):
			draw_circle(Vector2(size.x * f, size.y * 0.5), 9.0, Color.WHITE)

	static func _rr(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(6)
		s.anti_aliasing = true
		return s
