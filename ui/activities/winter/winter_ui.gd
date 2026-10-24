extends Control
## Snowball match HUD, snowball lobby, basketball HUD and the shared round-complete card
## (Images/UI - Sledding Snowballs and Basketball.png, UI - Activity Play Guess and Results.png).
## No snowball/basketball gameplay exists yet: these run from apply_state() with mock data in
## preview(), and emit intent() for the future activity session/server.
##   snowball state: {mode:"snowball", coral:int, teal:int, time_left:float, ready_in:float (0 = ready),
##                    respawn_in:float}
##   lobby state:    {mode:"lobby", coral:[names], teal:[names], waiting:bool}
##   court state:    {mode:"court", score:int, time_left:float, standings:[[name, score]], power:float, band:[lo, hi]}
##   result state:   {mode:"result", rows:[{name, score, team}], footnote:String}

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")

var state := {"mode": "snowball", "coral": 3, "teal": 2, "time_left": 84.0, "ready_in": 0.0, "respawn_in": 0.0}
var _root: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func apply_state(s: Dictionary) -> void:
	state = s
	_build()


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	match str(state.get("mode", "")):
		"lobby":
			_lobby()
		"court":
			_court()
		"result":
			_result()
		_:
			_snowball()


static func _clock(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


func _leave_chip(at: Vector4) -> void:
	var b := A.chip_button("Leave", "close", "light", 20)
	b.pressed.connect(func() -> void: intent.emit("leave", null))
	A.pin(_root, b, at)


# ------------------------------------------------------------------ snowball --
func _snowball() -> void:
	var bar := A.hbox(0)
	A.pin(_root, bar, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 20, 300, 110))
	bar.add_child(_team_block("Coral", int(state.get("coral", 0)), A.CORAL, true))
	var mid := PanelContainer.new()
	mid.add_theme_stylebox_override("panel", A.box(Color("#15304A"), 0, 0, Color.TRANSPARENT, 18))
	mid.custom_minimum_size = Vector2(160, 0)
	var tl := A.title(_clock(float(state.get("time_left", 0))), 40, HORIZONTAL_ALIGNMENT_CENTER)
	tl.add_theme_color_override("font_color", A.WHITE)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid.add_child(tl)
	bar.add_child(mid)
	bar.add_child(_team_block("Teal", int(state.get("teal", 0)), A.TEAL, false))
	var cross := A.icon("crosshair", 64, Color(1, 1, 1, 0.95))
	A.pin(_root, cross, Vector4(0.5, 0.45, 0.5, 0.45), Vector4(-32, -32, 32, 32))
	# throw readiness: a cooldown ring, not ammo (unlimited snowballs per the proposed rules)
	var rdy := A.chip("", A.IVORY, A.NAVY, "", 18, Vector2(18, 12))
	rdy.get_child(0).queue_free()
	var rr := A.hbox(14)
	rdy.add_child(rr)
	var ring := TextureProgressBar.new()
	ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	ring.texture_under = A.icon_tex("snowball")
	ring.texture_progress = A.icon_tex("snowball")
	ring.tint_under = Color(0.8, 0.84, 0.9)
	ring.tint_progress = Color("#4D7FBF")
	ring.custom_minimum_size = Vector2(54, 54)
	ring.nine_patch_stretch = true
	var cd := float(state.get("ready_in", 0.0))
	ring.value = 100.0 * (1.0 - clampf(cd / 0.8, 0, 1))
	rr.add_child(ring)
	rr.add_child(A.label("Ready" if cd <= 0.0 else "%.1fs" % cd, 22, A.NAVY, true))
	A.pin(_root, rdy, Vector4(0, 1, 0, 1), Vector4(24, -110, 214, -24))
	var resp := float(state.get("respawn_in", 0.0))
	if resp > 0.0:
		var inset := A.panel(16, 20)
		A.pin(_root, inset, Vector4(1, 0.5, 1, 0.5), Vector4(-310, -120, -30, 40))
		var iv := A.vbox(6)
		inset.add_child(iv)
		var line := A.hbox(6)
		line.add_child(A.label("Back in", 24, A.NAVY, true))
		line.add_child(A.label("%d..." % ceili(resp), 30, A.CORAL, true))
		iv.add_child(line)
		iv.add_child(A.label("Spawn protection on until you throw", 16, A.SUB))
	_leave_chip(Vector4(1, 1, 1, 1) + Vector4(0, 0, 0, 0))
	(_root.get_child(_root.get_child_count() - 1) as Control).offset_left = -150
	(_root.get_child(_root.get_child_count() - 1) as Control).offset_top = -76
	(_root.get_child(_root.get_child_count() - 1) as Control).offset_right = -24
	(_root.get_child(_root.get_child_count() - 1) as Control).offset_bottom = -24


func _team_block(team: String, score: int, col: Color, left: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := A.box(col, 0, 0, Color.TRANSPARENT, 12)
	if left:
		sb.corner_radius_top_left = 20; sb.corner_radius_bottom_left = 20
	else:
		sb.corner_radius_top_right = 20; sb.corner_radius_bottom_right = 20
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(220, 0)
	var h := A.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	p.add_child(h)
	var face := PenguinView.new()
	face.framing = "portrait"
	face.custom_minimum_size = Vector2(62, 62)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := A.vbox(-6)
	v.add_child(A.label(team, 20, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.label(str(score), 40, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
	if left:
		h.add_child(face); h.add_child(v)
	else:
		h.add_child(v); h.add_child(face)
	return p


# ------------------------------------------------------------------ lobby --
func _lobby() -> void:
	var p := A.panel(26, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-380, -290, 380, 290))
	var v := A.vbox(12)
	p.add_child(v)
	v.add_child(A.label("PENGLOO PARTY", 15, A.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.title("SNOWBALLS", 56, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.label("Waiting for players..." if state.get("waiting", true) else "Starting soon!", 22, A.SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	var teams := A.hbox(24, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(teams)
	teams.add_child(_team_col("Coral", state.get("coral", []), A.CORAL))
	teams.add_child(A.title("VS", 40))
	teams.add_child(_team_col("Teal", state.get("teal", []), A.TEAL))
	v.add_child(A.expander())
	var row := A.hbox(16)
	v.add_child(row)
	var leave := A.button("Leave", "secondary", "", 22, Vector2(140, 62))
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	row.add_child(leave)
	var ready := A.button("Ready", "primary", "", 32, Vector2(0, 76))
	ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready.pressed.connect(func() -> void: intent.emit("ready", null))
	row.add_child(ready)
	var spec := A.button("Spectate", "light", "eye", 21, Vector2(170, 62))
	spec.pressed.connect(func() -> void: intent.emit("spectate", null))
	row.add_child(spec)


func _team_col(team: String, names: Array, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.box(col.lightened(0.55), 18, 0, Color.TRANSPARENT, 0))
	p.custom_minimum_size = Vector2(260, 200)
	var v := A.vbox(8)
	p.add_child(v)
	var head := PanelContainer.new()
	var hs := A.box(col, 0, 0, Color.TRANSPARENT, 8)
	hs.corner_radius_top_left = 18; hs.corner_radius_top_right = 18
	head.add_theme_stylebox_override("panel", hs)
	head.add_child(A.label(team, 22, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(head)
	for i in 2:
		var nm: String = str(names[i]) if i < names.size() else ""
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", A.box(A.WHITE if nm != "" else Color(1, 1, 1, 0.5), 14, 0, Color.TRANSPARENT, 8))
		var h := A.hbox(12)
		row.add_child(h)
		if nm != "":
			var face := PenguinView.new()
			face.framing = "portrait"
			face.custom_minimum_size = Vector2(56, 56)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(face)
		h.add_child(A.label(nm if nm != "" else "Open slot", 22, A.NAVY if nm != "" else A.MUTED, true))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 10)
		m.add_theme_constant_override("margin_right", 10)
		m.add_child(row)
		v.add_child(m)
	return p


# ------------------------------------------------------------------ court --
func _court() -> void:
	var mine := A.stat_card("My score", str(state.get("score", 0)), 40)
	A.pin(_root, mine, Vector4(0, 0, 0, 0), Vector4(24, 20, 150, 0))
	var t := A.stat_card("Time", _clock(float(state.get("time_left", 0))), 40)
	A.pin(_root, t, Vector4(0, 0, 0, 0), Vector4(164, 20, 0, 0))
	var st := A.panel(14, 18)
	A.pin(_root, st, Vector4(1, 0, 1, 0), Vector4(-290, 20, -24, 0))
	var sv := A.vbox(6)
	st.add_child(sv)
	sv.add_child(A.label("Standings", 20, A.NAVY, true))
	var rows: Array = state.get("standings", [])
	for i in rows.size():
		var r := PanelContainer.new()
		r.add_theme_stylebox_override("panel", A.box(A.TEAL_SOFT if i == 0 else Color.TRANSPARENT, 10, 0, Color.TRANSPARENT, 6))
		var h := A.hbox(14)
		r.add_child(h)
		h.add_child(A.label(str(i + 1), 19, A.NAVY, true))
		var n := A.label(str(rows[i][0]), 19, A.NAVY, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(A.label(str(rows[i][1]), 19, A.NAVY, true))
		sv.add_child(r)
	# power meter: hold to charge, release inside the target band
	var meter := Control.new()
	meter.custom_minimum_size = Vector2(440, 70)
	A.pin(_root, meter, Vector4(0.5, 1, 0.5, 1), Vector4(-220, -140, 220, -70))
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", A.box(A.IVORY, 22, 4, A.WHITE, 0))
	A.pin(meter, track, Vector4(0, 0.35, 1, 1))
	var band: Array = state.get("band", [0.6, 0.76])
	var zones := [[0.42, float(band[0]), Color("#F4C44B")], [float(band[0]), float(band[1]), Color("#F3756A")], [float(band[1]), 0.95, Color("#7CC7EC")]]
	for z in zones:
		var zr := ColorRect.new()
		zr.color = z[2]
		zr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		A.pin(meter, zr, Vector4(z[0], 0.45, z[1], 0.9))
	var pos := float(state.get("power", 0.7))
	var mark := A.icon("play", 30, A.NAVY)
	mark.rotation_degrees = 90
	mark.pivot_offset = Vector2(15, 15)
	A.pin(meter, mark, Vector4(pos, 0, pos, 0), Vector4(-15, -12, 15, 18))
	var hint := A.label("Hold to charge · Release to shoot", 20, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	hint.add_theme_color_override("font_outline_color", Color(0.08, 0.16, 0.24, 0.6))
	hint.add_theme_constant_override("outline_size", 6)
	A.pin(_root, hint, Vector4(0.5, 1, 0.5, 1), Vector4(-240, -66, 240, -34))
	_leave_chip(Vector4(1, 1, 1, 1))
	var lc := _root.get_child(_root.get_child_count() - 1) as Control
	lc.offset_left = -150; lc.offset_top = -76; lc.offset_right = -24; lc.offset_bottom = -24


# ------------------------------------------------------------------ result --
func _result() -> void:
	var p := A.panel(28, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-330, -280, 330, 280))
	var v := A.vbox(14)
	p.add_child(v)
	v.add_child(A.label("PENGLOO PARTY", 15, A.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(A.title("Round complete", 52, HORIZONTAL_ALIGNMENT_CENTER))
	for r in state.get("rows", []):
		var col: Color = A.TEAM.get(str(r.get("team", "coral")), A.CORAL)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", A.box(col, 18, 3, col.lightened(0.3), 10))
		var h := A.hbox(16)
		row.add_child(h)
		var face := PenguinView.new()
		face.framing = "portrait"
		face.custom_minimum_size = Vector2(80, 80)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(face)
		var n := A.label(str(r["name"]), 28, A.WHITE, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var sc := PanelContainer.new()
		sc.add_theme_stylebox_override("panel", A.box(col.lightened(0.82), 14, 0, Color.TRANSPARENT, 6))
		sc.custom_minimum_size = Vector2(110, 0)
		sc.add_child(A.title(str(r["score"]), 52, HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(sc)
		v.add_child(row)
	var b := A.hbox(16)
	v.add_child(b)
	var again := A.button("Play again", "primary", "", 28, Vector2(0, 70))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void: intent.emit("play_again", null))
	b.add_child(again)
	var leave := A.button("Leave", "secondary", "", 24, Vector2(200, 70))
	leave.pressed.connect(func() -> void: intent.emit("leave", null))
	b.add_child(leave)
	v.add_child(A.label(str(state.get("footnote", "")), 16, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))


func close() -> void:
	intent.emit("leave", null)
	queue_free()


func preview(s: String) -> void:
	match s:
		"lobby":
			apply_state({"mode": "lobby", "coral": ["Pip", "You"], "teal": ["Milo", "Coco"], "waiting": true})
		"court":
			apply_state({"mode": "court", "score": 6, "time_left": 38.0, "standings": [["You", 6], ["Milo", 4]], "power": 0.74, "band": [0.62, 0.78]})
		"result":
			apply_state({"mode": "result", "rows": [{"name": "You", "score": 6, "team": "coral"}, {"name": "Milo", "score": 4, "team": "teal"}],
				"footnote": "Same result card for the court and snowballs."})
		"respawn":
			apply_state({"mode": "snowball", "coral": 3, "teal": 2, "time_left": 84.0, "ready_in": 0.0, "respawn_in": 2.0})
		_:
			apply_state({"mode": "snowball", "coral": 3, "teal": 2, "time_left": 84.0, "ready_in": 0.0, "respawn_in": 0.0})
