class_name CasinoKit
extends RefCounted
## Shared casino UI pieces (Images/UI - Casino - Game UI Mockups.png): navy header banner with a
## play-chip readout, felt table with a wood rim, drawn playing cards and chips, and the
## exceptional-state cards (reconnecting, waiting, full table, insufficient chips).
## Every casino screen takes state in through apply_state() and emits intent(action, payload);
## the server owns shuffles, results, deadlines, legality and settlement (requirements note).

const A := preload("res://ui/activities/act_style.gd")
const HEADER := Color("#123E57")
const HEADER_EDGE := Color("#0B2C40")
const FELT := Color("#1E6F6E")
const FELT_DARK := Color("#165857")
const WOOD := Color("#7A4A2A")
const CREAM := Color("#F6EEDC")
const RED := Color("#D6453C")
const BLACK := Color("#232733")
const CHIP_VALUES := [1, 5, 10, 25, 100]
const CHIP_COLORS := [Color("#F4EFE6"), Color("#E0473F"), Color("#2F7FD6"), Color("#2E9E5E"), Color("#7B4FC4")]


static func chip_texture() -> Texture2D:
	return A.icon_tex("snowball")


## Navy banner: title left, status (e.g. "Betting open  00:12" or "Play chips: 120") right.
static func header(title: String, right_text := "", chip_icon := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := A.box(HEADER, 18, 0, Color.TRANSPARENT, 0)
	sb.border_width_bottom = 4
	sb.border_color = HEADER_EDGE
	sb.content_margin_left = 22
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := A.hbox(10)
	p.add_child(h)
	var t := A.label(title.to_upper(), 30, A.WHITE, true)
	h.add_child(t)
	h.add_child(A.expander())
	var r := A.label(right_text, 20, A.WHITE, true)
	r.name = "Right"
	h.add_child(r)
	if chip_icon:
		h.add_child(chip(2, 26))
	return p


## Teal felt with a wooden rim; content goes inside.
static func felt(pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := A.box(FELT, 26, 10, WOOD, pad)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


## Outer ivory frame around a casino game panel (header + felt), like each board tile.
static func frame() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.box(A.IVORY, 26, 3, A.IVORY_EDGE, 10, true))
	return p


static func chip(color_index: int, px := 44, selected := false) -> Control:
	var c := ChipDot.new()
	c.color = CHIP_COLORS[posmod(color_index, CHIP_COLORS.size())]
	c.selected = selected
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func card(rank: String, suit: String, face_up := true, w := 74) -> Control:
	var c := PlayingCard.new()
	c.rank = rank
	c.suit = suit
	c.face_up = face_up
	c.custom_minimum_size = Vector2(w, w * 1.4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Casino action button: teal primary, cream secondary (Leave/Check), grey when not legal.
static func action(text: String, kind := "primary", w := 160) -> Button:
	var b := A.button(text.to_upper(), "primary" if kind == "primary" else "secondary", "", 24, Vector2(w, 64))
	if kind != "primary":
		for st in ["normal", "hover"]:
			var sb := A.box(CREAM if st == "normal" else CREAM.lightened(0.3), 16, 3, Color("#D9C9A4"), 12)
			b.add_theme_stylebox_override(st, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, A.NAVY)
	var dis := A.box(Color("#8D97A3"), 16, 0, Color.TRANSPARENT, 12)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_disabled_color", Color("#DDE2E8"))
	return b


## Exceptional states shared by all tables.
##   kind: reconnecting | waiting | full | insufficient | unavailable
static func state_card(kind: String, detail := "") -> PanelContainer:
	var p := A.panel(24, 26)
	var v := A.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var faces := {"reconnecting": [{"head": "headphones"}], "waiting": [{}, {}, {}]}
	var row := A.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(row)
	var looks: Array = faces.get(kind, [{}])
	for i in looks.size():
		var pv := PenguinView.new()
		pv.framing = "full"
		pv.custom_minimum_size = Vector2(150, 160)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pv)
		pv.call_deferred("set_look", Net.coat_color([0, 3, 1][i % 3]), looks[i])
	var title := {"reconnecting": "Reconnecting...", "waiting": "Waiting for round to start...", "full": "Table is full",
		"insufficient": "Not enough play chips", "unavailable": "Table unavailable"}.get(kind, kind) as String
	var sub := {"reconnecting": "Hang tight! Getting you back to the game.", "waiting": "Players are joining. The game will begin soon.",
		"full": "Watch this round or try another table.", "insufficient": "Pick a smaller chip, or watch for now.",
		"unavailable": "This table is closed right now."}.get(kind, "") as String
	v.add_child(A.title(title, 30, HORIZONTAL_ALIGNMENT_CENTER))
	var s := A.label(detail if detail != "" else sub, 19, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	return p


class ChipDot:
	extends Control
	var color := Color.WHITE
	var selected := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		if selected:
			draw_circle(c, r + 2, Color("#F2C230"))
			r -= 3
		draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.2))
		draw_circle(c, r, color)
		for i in 8:   # edge stripes
			var a := TAU * i / 8.0
			draw_line(c + Vector2(cos(a), sin(a)) * r * 0.72, c + Vector2(cos(a), sin(a)) * r * 0.98, Color(1, 1, 1, 0.9) if color.v < 0.85 else Color("#C9C0AE"), r * 0.22)
		draw_circle(c, r * 0.56, color.lightened(0.15))
		draw_arc(c, r * 0.56, 0, TAU, 24, Color(1, 1, 1, 0.55), 1.5, true)


class PlayingCard:
	extends Control
	var rank := "A"
	var suit := "spades"     ## spades | hearts | diamonds | clubs
	var face_up := true
	const SYM := {"spades": "♠", "hearts": "♥", "diamonds": "♦", "clubs": "♣"}

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(size.x * 0.1))
		sb.anti_aliasing = true
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		if not face_up:
			sb.bg_color = Color("#C8453B")
			sb.set_border_width_all(int(size.x * 0.07))
			sb.border_color = Color("#FBF3E6")
			draw_style_box(sb, r)
			for i in 7:   # simple lattice back
				var x := size.x * (0.15 + i * 0.12)
				draw_line(Vector2(x, size.y * 0.1), Vector2(x - size.x * 0.25, size.y * 0.9), Color(1, 1, 1, 0.18), 2)
			return
		sb.bg_color = Color("#FFFDF8")
		sb.set_border_width_all(2)
		sb.border_color = Color("#E3DCCB")
		draw_style_box(sb, r)
		var col := CasinoKit.RED if suit in ["hearts", "diamonds"] else CasinoKit.BLACK
		var f: Font = CasinoKit.A.title_font()
		draw_string(f, Vector2(size.x * 0.1, size.y * 0.27), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.x * 0.36), col)
		draw_string(f, Vector2(0, size.y * 0.82), SYM.get(suit, "?"), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.x * 0.62), col)
