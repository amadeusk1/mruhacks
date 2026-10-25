extends CanvasLayer

## Entry flow before the first room loads (board "Main Menu and Entry"):
## Your Penguin (first time) -> Choose a World -> Joining. The signals and methods below are the
## contract world.gd uses (host/join/solo, player_name, set_status, set_busy, show/hide).

signal host_requested
signal join_requested
signal solo_requested

const T := preload("res://ui/theme/ui_tokens.gd")
const PROFILE := "user://profile.cfg"
var WORLDS := [
	{"id": "solo", "name": "Practice Island", "desc": "Explore the island on your own.", "count": "Just you",
		"action": "Play solo", "thumb": "res://ui/screens/world_thumb_0.png"},
	{"id": "host", "name": "Host a World", "desc": "Friends on your network can join you.", "count": "Up to 8",
		"action": "Host world", "thumb": "res://ui/screens/world_thumb_1.png"},
	{"id": "join", "name": "Join a Friend", "desc": "Join the world hosted at 127.0.0.1.", "count": "LAN",
		"action": "Join friend", "thumb": "res://ui/screens/world_thumb_2.png"},
]

var _root: Control
var _setup: Control
var _choose: Control
var _joining: Control
var _name := {}            # UIKit.field dict
var _color := 0
var _swatches: Array[Button] = []
var _preview: PenguinPreview
var _rows: Array[PanelContainer] = []
var _selected := 0
var _go: IconTextButton
var _join_title: Label
var _join_sub: Label
var _join_error: Control
var _busy := false


func _ready() -> void:
	if Net.public_client():
		WORLDS.remove_at(1)
		WORLDS[1] = {"id": "join", "name": "Pengloo Party", "desc": "Join the shared island with friends.", "count": "Online", "action": "Join world", "thumb": "res://ui/screens/world_thumb_1.png"}
	layer = 20
	_load_profile()
	_build()
	_show(_choose if _has_profile() else _setup)


# ---- contract used by world.gd ---------------------------------------------------
func player_name() -> String:
	var raw := (_name["field"] as LineEdit).text.strip_edges().replace("\n", " ")
	if raw == "":
		return "Penguin"
	return raw.substr(0, 16)


func set_name_text(value: String) -> void:
	(_name["field"] as LineEdit).text = value


func set_status(message: String) -> void:
	if _joining.visible and not _busy and message != "":
		_join_error.visible = true
		(_join_error.find_child("Msg", true, false) as Label).text = message
		_join_title.text = "Couldn't join"
		_join_sub.text = "Your choice is kept."
	elif message != "" and _choose.visible:
		UIWidgets.toast(self, message, "wifi_off")


func set_busy(busy: bool) -> void:
	_busy = busy
	if busy:
		_open_joining()


func show_lobby(message: String = "") -> void:
	visible = true
	_busy = false
	_show(_choose)
	if message != "":
		var c := ConnectionLost.show_lost(message, func() -> void: _go_pressed())
		c.title_label.text = ""


func hide_lobby() -> void:
	var focus := _root.get_viewport().gui_get_focus_owner() if _root.is_inside_tree() else null
	if focus != null and _root.is_ancestor_of(focus):
		focus.release_focus()
	visible = false


## Screenshot harness hook.
func debug_show(step: String) -> void:
	match step:
		"penguin_setup":
			_show(_setup)
		"choose_world":
			_show(_choose)
		"joining":
			_open_joining()


# ---- build -------------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.theme = UIKit.THEME
	UIKit.full(_root)
	add_child(_root)
	var bg := TextureRect.new()
	bg.texture = load("res://ui/screens/backdrop_blur.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UIKit.full(bg)
	_root.add_child(bg)
	_setup = _build_setup()
	_choose = _build_choose()
	_joining = _build_joining()


func _card(size: Vector2) -> PanelContainer:
	var c := UIKit.card()
	_root.add_child(UIKit.pin(c, Vector2(0.5, 0.5), Vector2.ZERO, size))
	return c


func _header(parent: VBoxContainer, title: String, subtitle: String, on_back: Callable) -> void:
	var head := Control.new()
	head.custom_minimum_size.y = 58
	parent.add_child(head)
	var t := UIKit.label(title, "Title", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 58)
	UIKit.full(t)
	head.add_child(t)
	if on_back.is_valid():
		var back := UIKit.icon_button("back", "Back", 60)
		back.position = Vector2(2, 2)
		back.pressed.connect(on_back)
		head.add_child(back)
	parent.add_child(UIKit.label(subtitle, "Subtitle", HORIZONTAL_ALIGNMENT_CENTER))


func _build_setup() -> Control:
	var card := _card(Vector2(1000, 560))
	var col := UIKit.vbox(10)
	card.add_child(col)
	_header(col, "Your Penguin", "Choose a look and a name for your penguin.",
		func() -> void: get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn"))
	var row := UIKit.hbox(30)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_preview = PenguinPreview.new(Vector2i(420, 420), Net.coat_color(_color))
	_preview.bird.rotation.y = deg_to_rad(-28) if _preview.bird else 0.0
	_preview.custom_minimum_size = Vector2(420, 400)
	row.add_child(_preview)
	var form := UIKit.vbox(14)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(form)
	var dn := UIKit.label("Display Name", "Strong")
	dn.add_theme_font_size_override("font_size", 28)
	form.add_child(dn)
	_name = UIKit.field("Your penguin's name", str(_profile.get("name", "Snowdrop")))
	(_name["field"] as LineEdit).max_length = 16
	(_name["field"] as LineEdit).custom_minimum_size.y = 72
	(_name["field"] as LineEdit).add_theme_font_size_override("font_size", 30)
	(_name["field"] as LineEdit).text_changed.connect(func(_t: String) -> void: UIKit.set_field_error(_name, ""))
	(_name["field"] as LineEdit).text_submitted.connect(func(_t: String) -> void: _continue())
	form.add_child(_name["root"])
	form.add_child(UIKit.gap(4))
	var pcl := UIKit.label("Penguin Color", "Strong")
	pcl.add_theme_font_size_override("font_size", 28)
	form.add_child(pcl)
	var sw := UIKit.hbox(16)
	for i in Net.COATS.size():
		var b := UIKit.swatch(Net.coat_color(i), _pick_color.bind(i))
		b.tooltip_text = ["Blue", "Green", "Yellow", "Pink", "Purple", "Orange"][i] if i < 6 else ""
		_swatches.append(b)
		sw.add_child(b)
	form.add_child(sw)
	form.add_child(UIKit.gap(18))
	var cont := UIKit.button("Continue", "primary", "chevron_right", Vector2(0, 92), true)
	cont.add_theme_font_size_override("font_size", 40)
	for st in ["normal", "hover", "pressed"]:
		var sb := (UIKit.THEME.get_stylebox(st, "PrimaryButton") as StyleBoxFlat).duplicate()
		sb.set_corner_radius_all(40)
		cont.add_theme_stylebox_override(st, sb)
	cont.pressed.connect(_continue)
	form.add_child(cont)
	_pick_color(_color)
	return card


func _build_choose() -> Control:
	var card := _card(Vector2(1090, 640))
	var col := UIKit.vbox(10)
	card.add_child(col)
	_header(col, "Choose a World", "Pick a cozy place to waddle together.", func() -> void: _show(_setup))
	col.add_child(UIKit.gap(4))
	for i in WORLDS.size():
		var w: Dictionary = WORLDS[i]
		var r := UIKit.card("Row")
		r.custom_minimum_size.y = 118
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
				if e.double_click: _go_pressed())
		var h := UIKit.hbox(22)
		r.add_child(h)
		var pic := TextureRect.new()
		pic.texture = load(w["thumb"])
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(160, 96)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_rounded(pic))
		var txt := UIKit.vbox(2)
		txt.alignment = BoxContainer.ALIGNMENT_CENTER
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UIKit.label(w["name"], "Heading")
		n.add_theme_font_size_override("font_size", 36)
		txt.add_child(n)
		txt.add_child(UIKit.label(w["desc"], "Subtitle"))
		h.add_child(txt)
		var cnt := UIKit.hbox(10)
		cnt.add_child(UIKit.glyph("users", 30, T.NAVY_TITLE))
		var cl := UIKit.label(w["count"], "Strong")
		cl.add_theme_font_size_override("font_size", 28)
		cnt.add_child(cl)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cnt.custom_minimum_size.x = 170
		h.add_child(cnt)
		for c in r.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.append(r)
		col.add_child(r)
	col.add_child(UIKit.spacer(false))
	var bottom := UIKit.hbox(16)
	var edit := UIKit.button("Edit penguin", "outline", "pencil", Vector2(240, 76))
	for st in ["normal", "hover", "pressed"]:
		var sb := (UIKit.THEME.get_stylebox(st, "OutlineButton") as StyleBoxFlat).duplicate()
		sb.set_corner_radius_all(40)
		edit.add_theme_stylebox_override(st, sb)
	edit.pressed.connect(func() -> void: _show(_setup))
	bottom.add_child(edit)
	bottom.add_child(UIKit.spacer())
	_go = UIKit.button("Play solo", "primary", "chevron_right", Vector2(360, 80), true)
	_go.add_theme_font_size_override("font_size", 32)
	for st in ["normal", "hover", "pressed"]:
		var sb := (UIKit.THEME.get_stylebox(st, "PrimaryButton") as StyleBoxFlat).duplicate()
		sb.set_corner_radius_all(40)
		_go.add_theme_stylebox_override(st, sb)
	_go.pressed.connect(_go_pressed)
	bottom.add_child(_go)
	col.add_child(bottom)
	_select(int(_profile.get("world", 1 if Net.public_client() else 0)))
	return card


func _build_joining() -> Control:
	var card := _card(Vector2(860, 600))
	var col := UIKit.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	col.add_child(UIKit.spacer(false))
	var feet := Footprints.new()
	feet.custom_minimum_size = Vector2(0, 210)
	col.add_child(feet)
	_join_title = UIKit.label("Joining…", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	_join_title.add_theme_font_size_override("font_size", 46)
	col.add_child(_join_title)
	_join_sub = UIKit.label("Finding your iceberg…", "Subtitle", HORIZONTAL_ALIGNMENT_CENTER)
	_join_sub.add_theme_font_size_override("font_size", 22)
	col.add_child(_join_sub)
	_join_error = UIWidgets.state_panel("error", "Could not join.", "", [["Retry", "danger", _go_pressed]])
	(_join_error.find_children("*", "Label", true, false)[1] as Label).name = "Msg"
	_join_error.visible = false
	col.add_child(_center(_join_error, 420))
	col.add_child(UIKit.gap(16))
	var cancel := UIKit.button("Cancel", "secondary", "", Vector2(300, 64))
	cancel.add_theme_font_size_override("font_size", 24)
	cancel.pressed.connect(func() -> void:
		Net.shutdown()
		_busy = false
		_show(_choose))
	col.add_child(_center(cancel, 300))
	col.add_child(UIKit.spacer(false))
	return card


func _center(c: Control, w: float) -> CenterContainer:
	var cc := CenterContainer.new()
	c.custom_minimum_size.x = w
	cc.add_child(c)
	return cc


func _rounded(pic: TextureRect) -> Control:
	# shortcut: square-cornered thumbnail inside a rounded frame; use a mask shader for true round corners
	var p := PanelContainer.new()
	var b := StyleBoxFlat.new()
	b.bg_color = T.LINE
	b.set_corner_radius_all(12)
	b.content_margin_left = 2
	b.content_margin_right = 2
	b.content_margin_top = 2
	b.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", b)
	p.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	p.add_child(pic)
	return p


# ---- behaviour ---------------------------------------------------------------------------
func _show(which: Control) -> void:
	for c in [_setup, _choose, _joining]:
		c.visible = c == which
	if which == _setup:
		(_name["field"] as LineEdit).grab_focus.call_deferred()
	elif which == _choose:
		_go.grab_focus.call_deferred()


func _pick_color(i: int) -> void:
	_color = i
	for k in _swatches.size():
		_swatches[k].set_pressed_no_signal(k == i)
	if _preview:
		_preview.set_body(Net.coat_color(i))


func _continue() -> void:
	var raw := (_name["field"] as LineEdit).text.strip_edges()
	if raw.length() < 2:
		UIKit.set_field_error(_name, "Names need at least 2 letters.")
		return
	if not RegEx.create_from_string("^[\\p{L}\\p{N} _'-]+$").search(raw):
		UIKit.set_field_error(_name, "Use letters, numbers, spaces, - or _.")
		return
	_save_profile()
	_show(_choose)


func _select(i: int) -> void:
	_selected = clampi(i, 0, WORLDS.size() - 1)
	for k in _rows.size():
		_rows[k].theme_type_variation = "RowSelected" if k == _selected else "Row"
	_go.set_caption(WORLDS[_selected]["action"])


func _go_pressed() -> void:
	if _busy:
		return
	_profile["world"] = _selected
	_save_profile()
	Net.preferred_color = _color
	match WORLDS[_selected]["id"]:
		"solo": solo_requested.emit()
		"host": host_requested.emit()
		"join": join_requested.emit()


func _open_joining() -> void:
	var w: Dictionary = WORLDS[_selected]
	_join_title.text = {"solo": "Waddling to the island…", "host": "Opening your world…", "join": "Joining your friend…"}[w["id"]]
	_join_sub.text = "Finding your iceberg…"
	_join_error.visible = false
	_show(_joining)


# ---- profile --------------------------------------------------------------------------------
var _profile := {}


func _has_profile() -> bool:
	return _profile.has("name")


func _load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(PROFILE) == OK:
		for k in ["name", "color", "world"]:
			if cf.has_section_key("penguin", k):
				_profile[k] = cf.get_value("penguin", k)
	_color = int(_profile.get("color", 0))


func _save_profile() -> void:
	_profile["name"] = player_name()
	_profile["color"] = _color
	var cf := ConfigFile.new()
	for k in _profile:
		cf.set_value("penguin", k, _profile[k])
	cf.save(PROFILE)


class Footprints extends Control:
	func _foot(col: Color) -> void:
		# webbed penguin foot: a rounded heel fanning into three toes
		var pts := PackedVector2Array([Vector2(0, 40), Vector2(-14, 30), Vector2(-26, -4), Vector2(-34, -36),
			Vector2(-18, -22), Vector2(-10, -46), Vector2(0, -20), Vector2(12, -46), Vector2(18, -22),
			Vector2(34, -36), Vector2(26, -4), Vector2(14, 30)])
		draw_colored_polygon(pts, col)
		draw_circle(Vector2(0, 30), 14, col)

	## three navy webbed footprints walking up-right with coral motion marks (Joining panel)
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var spots := [Vector2(-120, 40), Vector2(-10, -10), Vector2(100, -70)]
		for i in 3:
			var on := fmod(_t * 1.2 - i * 0.35, 1.6) < 1.1
			var p: Vector2 = c + spots[i]
			draw_circle(p + Vector2(-20, 40), 18, Color(0.85, 0.9, 0.95, 0.9))
			if on:
				draw_set_transform(p, deg_to_rad(28 + i * 4), Vector2.ONE)
				_foot(Color("#1E3460"))
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var coral := Color("#F5776C")
		draw_line(c + Vector2(160, -110), c + Vector2(184, -128), coral, 7, true)
		draw_line(c + Vector2(168, -84), c + Vector2(196, -88), coral, 7, true)
