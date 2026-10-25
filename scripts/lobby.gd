extends CanvasLayer

## Entry flow before the first room loads (board "Main Menu and Entry"):
## Your Penguin (first time) -> Choose a World -> Joining. The signals and methods below are the
## contract world.gd uses (host/join/solo, player_name, set_status, set_busy, show/hide).

signal host_requested
signal join_requested
signal solo_requested

const T := preload("res://ui/theme/ui_tokens.gd")
const LINK := preload("res://scripts/lobby_link.gd")
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
var _servers: Control       # Community Servers list (docs/Engine Specs/Community Servers.md)
var _server_list: VBoxContainer
var _server_rows: Array = []  # [{row, listing}]
var _server_pick := -1
var _server_join: Button
var _server_http: HTTPRequest
var _server_t0 := 0
var _full_banner: PanelContainer
var _full_title: Label
var _admin := {}
var _joining_server := ""
var _hosting: Control       # Host a Server setup (name, max players, optional own cinema)
var _hf := {}               # hosting field dicts by key
var _host_max: SpinBox
var _host_test: Label
const HOSTING := "user://hosting.cfg"   # the host's own settings, cinema credentials included: never uploaded
const HOST_CINEMA_ENV := "user://cinema_host.env"


func _ready() -> void:
	if Net.public_client():
		WORLDS.remove_at(1)
		WORLDS[1] = {"id": "join", "name": "Pengloo Party", "desc": "Join the shared island with friends.", "count": "Online", "action": "Join world", "thumb": "res://ui/screens/world_thumb_1.png"}
		WORLDS.append({"id": "servers", "name": "Community Servers", "desc": "Islands hosted by other players.", "count": "Browse",
			"action": "Browse servers", "thumb": "res://ui/screens/world_thumb_2.png"})
	if OS.has_feature("desktop_online"):  # browsers can't host; the desktop app can, through pengloo.party
		WORLDS.append({"id": "host_public", "name": "Host a Server", "desc": "Your own island, listed on pengloo.party.", "count": "You host",
			"action": "Set up server", "thumb": "res://ui/screens/world_thumb_0.png"})
	layer = 20
	_load_profile()
	_build()
	Net.join_full.connect(_on_full)
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
	_servers = _build_servers()
	_hosting = _build_hosting()


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
	for c in [_setup, _choose, _joining, _servers, _hosting]:
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
		"join":
			Net.server_url = ""
			Net.community = false
			Net.community_cinema = false
			_joining_server = ""
			join_requested.emit()
		"servers":
			_show(_servers)
			_refresh_servers()
		"host_public":
			_show(_hosting)


func _open_joining() -> void:
	var w: Dictionary = WORLDS[_selected]
	_join_title.text = {"solo": "Waddling to the island…", "host": "Opening your world…", "join": "Joining your friend…", "servers": "Joining…",
		"host_public": "Opening your server…"}[w["id"]]
	_join_sub.text = "Finding your iceberg…"
	if _joining_server != "":
		_join_title.text = "Joining %s…" % _joining_server
		_join_sub.text = "Community server · not run or moderated by Pengloo Party" if Net.community else "Finding your iceberg…"
	_join_error.visible = false
	_show(_joining)


# ---- community servers ----------------------------------------------------------------------
func _build_servers() -> Control:
	var card := _card(Vector2(1090, 640))
	var col := UIKit.vbox(10)
	card.add_child(col)
	_header(col, "Community Servers", "Islands hosted by other players, played right here through pengloo.party.", func() -> void: _show(_choose))
	col.add_child(_build_full_banner())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_server_list = UIKit.vbox(10)
	_server_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_server_list)
	col.add_child(scroll)
	var bottom := UIKit.hbox(16)
	var refresh := UIKit.button("Refresh", "outline", "refresh", Vector2(220, 76))
	refresh.pressed.connect(_refresh_servers)
	bottom.add_child(refresh)
	bottom.add_child(UIKit.spacer())
	_server_join = UIKit.button("Join server", "primary", "chevron_right", Vector2(360, 80), true)
	_server_join.add_theme_font_size_override("font_size", 32)
	_server_join.pressed.connect(_join_server)
	bottom.add_child(_server_join)
	col.add_child(bottom)
	_server_http = HTTPRequest.new()
	_server_http.timeout = 8.0
	_server_http.request_completed.connect(_on_servers)
	add_child(_server_http)
	return card


func _refresh_servers() -> void:
	_server_http.cancel_request()
	_server_t0 = Time.get_ticks_msec()
	_fill_servers([], "loading")
	if _server_http.request(Net.lobby_base() + "/lobby/servers") != OK:
		_fill_servers([], "error")


func _on_servers(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var rtt := Time.get_ticks_msec() - _server_t0
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if not (data is Dictionary) or not (data.get("servers") is Array):
		_fill_servers([], "error")
		return
	var out := []
	for s in data["servers"]:
		if s is Dictionary:
			s["ping"] = rtt + int(s.get("host_ms", 0))  # you -> pengloo.party -> the host
			out.append(s)
	_fill_servers(out, "ok")


## The official island is always first; community servers follow (the lobby sorts by players).
## Different builds can't talk (the RPC checksum differs), so mismatched versions are greyed out.
func _fill_servers(list: Array, state: String) -> void:
	for c in _server_list.get_children():
		c.queue_free()
	_server_rows.clear()
	_server_pick = -1
	if not list.any(func(x: Dictionary) -> bool: return bool(x.get("official", false))):  # lobby down: still offer it
		_add_server_row({"name": "Pengloo Party", "official": true, "players": -1, "url": "", "version": Net.build_version()})
	for s in list:
		_add_server_row(s)
	if state != "ok" or list.is_empty():
		var msg: Array = {"loading": ["loading", "Looking for servers…"], "error": ["error", "Couldn't load community servers. Try Refresh."],
			"ok": ["empty", "No community servers are online yet. Host one: see pengloo.party/download."]}[state]
		_server_list.add_child(UIWidgets.state_panel(msg[0], "Community Servers", msg[1], []))
	_pick_server(0)


func _add_server_row(s: Dictionary) -> void:
	var mine := Net.build_version()
	var theirs := str(s.get("version", ""))
	var outdated := theirs != mine and mine != "dev" and theirs != "dev"
	var full := s.has("max") and int(s.get("players", 0)) >= int(s["max"])
	var r := UIKit.card("Row")
	r.custom_minimum_size.y = 96
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	var i := _server_rows.size()
	r.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pick_server(i)
			if e.double_click: _join_server())
	var h := UIKit.hbox(18)
	r.add_child(h)
	var txt := UIKit.vbox(4)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	var n := UIKit.label(str(s.get("name", "Server")), "Heading")
	n.add_theme_font_size_override("font_size", 32)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	txt.add_child(n)
	var tags := UIKit.hbox(10)
	tags.add_child(UIKit.chip("Official" if s.get("official", false) else "Community", "star" if s.get("official", false) else "users", 16))
	if outdated:
		tags.add_child(UIKit.status("Outdated version", Color("#A9ABB2")))
	elif full:
		tags.add_child(UIKit.status("Full", Color("#E3A92B")))
	elif s.has("ping"):
		tags.add_child(UIKit.status("~%d ms" % int(s["ping"]), Color("#14B28B") if int(s["ping"]) < 120 else Color("#E3A92B")))
	if str(s.get("region", "")) != "":
		tags.add_child(UIKit.label(str(s["region"]).to_upper(), "Muted"))
	txt.add_child(tags)
	h.add_child(txt)
	var cnt := UIKit.hbox(10)
	cnt.add_child(UIKit.glyph("users", 30, T.NAVY_TITLE))
	var cl := UIKit.label("Online" if int(s.get("players", 0)) < 0 else "%d / %d" % [int(s.get("players", 0)), int(s.get("max", 0))], "Strong")
	cl.add_theme_font_size_override("font_size", 28)
	cnt.add_child(cl)
	cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cnt.custom_minimum_size.x = 150
	h.add_child(cnt)
	for c in r.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if outdated or full:
		r.modulate.a = 0.5
	else:  # one click straight in
		var join := UIKit.button("Join", "primary", "", Vector2(130, 60))
		join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		join.pressed.connect(func() -> void: _pick_server(i); _join_server())
		h.add_child(join)
	_server_list.add_child(r)
	_server_rows.append({"row": r, "listing": s, "ok": not (outdated or full)})


## Shown when the official island refuses us for being full: try again, pick a community server
## below, host your own, or use an admin code.
func _build_full_banner() -> PanelContainer:
	_full_banner = UIKit.card("Inset")
	_full_banner.visible = false
	var v := UIKit.vbox(8)
	_full_banner.add_child(v)
	var top := UIKit.hbox(14)
	_full_title = UIKit.label("", "Heading")
	_full_title.add_theme_font_size_override("font_size", 30)
	_full_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_full_title)
	var again := UIKit.button("Try again", "primary", "refresh", Vector2(220, 60))
	again.pressed.connect(_join_official)
	top.add_child(again)
	v.add_child(top)
	var how := UIKit.label("Join a community server below, or host your own: run one from the desktop app or on any computer, and it shows up in everyone's Servers list automatically. You can even add your own cinema.", "Body")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)
	var row := UIKit.hbox(12)
	var host := UIKit.button("Host your own server", "outline", "chevron_right", Vector2(320, 56), true)
	host.pressed.connect(func() -> void: OS.shell_open(Net.lobby_base() + "/download/#host"))
	row.add_child(host)
	row.add_child(UIKit.spacer())
	_admin = UIKit.field("Admin code", str(_profile.get("admin", "")), false)
	(_admin["field"] as LineEdit).secret = true
	(_admin["field"] as LineEdit).custom_minimum_size = Vector2(240, 56)
	row.add_child(_admin["root"])
	var use := UIKit.button("Use code", "secondary", "", Vector2(160, 56))
	use.pressed.connect(func() -> void:
		_profile["admin"] = (_admin["field"] as LineEdit).text.strip_edges()
		_save_profile()
		_join_official())
	row.add_child(use)
	v.add_child(row)
	return _full_banner


func _on_full(players: int, cap: int) -> void:
	_busy = false
	_full_title.text = "Pengloo Party is full right now (%d/%d)" % [players, cap]
	_full_banner.visible = true
	_show(_servers)
	_refresh_servers()


func _join_official() -> void:
	_full_banner.visible = false
	Net.server_url = ""
	Net.community = false
	Net.community_cinema = false
	Net.admin_code = str(_profile.get("admin", ""))
	_joining_server = "Pengloo Party"
	Net.preferred_color = _color
	join_requested.emit()


func _pick_server(i: int) -> void:
	_server_pick = i if i >= 0 and i < _server_rows.size() and _server_rows[i]["ok"] else -1
	for k in _server_rows.size():
		(_server_rows[k]["row"] as PanelContainer).theme_type_variation = "RowSelected" if k == _server_pick else "Row"
	_server_join.disabled = _server_pick < 0


func _join_server() -> void:
	if _busy or _server_pick < 0:
		return
	var s: Dictionary = _server_rows[_server_pick]["listing"]
	var url := "" if bool(s.get("official", false)) else str(s.get("url", ""))  # the official island: /multiplayer
	Net.community = url != ""
	Net.community_cinema = url != "" and bool(s.get("cinema", false))
	Net.server_url = "" if url == "" else Net.lobby_base().replace("https://", "wss://").replace("http://", "ws://") + url
	_joining_server = str(s.get("name", ""))
	Net.preferred_color = _color
	join_requested.emit()


# ---- hosting setup -------------------------------------------------------------------------
## Host a Server: name and size, plus an optional cinema with the host's OWN media server and
## codes. Those stay on this machine (user://); the bundled gateway runs here and players reach it
## through the pengloo.party relay. Skipping the cinema is fine: the cinema shows "No cinema".
func _build_hosting() -> Control:
	var card := _card(Vector2(1090, 760))
	var col := UIKit.vbox(8)
	card.add_child(col)
	_header(col, "Host a Server", "Players find it under Community Servers and join through pengloo.party.", func() -> void: _show(_choose))
	var cf := ConfigFile.new()
	cf.load(HOSTING)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var form := UIKit.vbox(8)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	col.add_child(scroll)
	var top := UIKit.hbox(16)
	_hf["name"] = UIKit.field("Server name (3-32 letters)", str(cf.get_value("server", "name", "")), false)
	(_hf["name"]["root"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_hf["name"]["root"])
	top.add_child(UIKit.label("Max players", "Strong"))
	_host_max = SpinBox.new()
	_host_max.min_value = 2
	_host_max.max_value = 32
	_host_max.value = int(cf.get_value("server", "max_players", 16))
	_host_max.custom_minimum_size = Vector2(140, 64)
	top.add_child(_host_max)
	form.add_child(top)
	var cin := UIKit.label("Cinema (optional): your own media server and codes", "Heading")
	cin.add_theme_font_size_override("font_size", 28)
	form.add_child(cin)
	form.add_child(UIKit.label("Leave all of these empty to host without movies. They're saved only on this computer.", "Subtitle"))
	for key in [["emby_url", "Emby server URL (e.g. http://192.168.1.10:8096)"], ["emby_key", "Emby API key"],
			["emby_user", "Emby user ID"], ["host_code", "Host code (picks movies)"], ["viewer_code", "Viewer code (watches)"]]:
		_hf[key[0]] = UIKit.field(key[1], str(cf.get_value("cinema", key[0], "")), false)
		if key[0] in ["emby_key", "host_code", "viewer_code"]:
			(_hf[key[0]]["field"] as LineEdit).secret = true
		form.add_child(_hf[key[0]]["root"])
	var test_row := UIKit.hbox(14)
	var test := UIKit.button("Test connection", "outline", "refresh", Vector2(280, 64))
	test.pressed.connect(_test_cinema)
	test_row.add_child(test)
	_host_test = UIKit.label("", "Muted")
	_host_test.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_row.add_child(_host_test)
	form.add_child(test_row)
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	var go := UIKit.button("Start hosting", "primary", "chevron_right", Vector2(360, 80), true)
	go.add_theme_font_size_override("font_size", 32)
	go.pressed.connect(_start_hosting)
	bottom.add_child(go)
	col.add_child(bottom)
	return card


func _hval(key: String) -> String:
	return (_hf[key]["field"] as LineEdit).text.strip_edges()


func _cinema_fields() -> Array:
	return ["emby_url", "emby_key", "emby_user", "host_code", "viewer_code"].map(_hval)


## "" when the cinema section is usable (all empty = no cinema), else what's wrong.
func _cinema_problem() -> String:
	var v := _cinema_fields()
	if v.all(func(x: String) -> bool: return x == ""):
		return ""
	if v.any(func(x: String) -> bool: return x == ""):
		return "Fill in every cinema field, or leave them all empty to host without movies."
	if not (v[0] as String).begins_with("http"):
		return "The Emby URL starts with http:// or https://."
	if (v[3] as String).length() < 4 or (v[4] as String).length() < 4 or v[3] == v[4]:
		return "Host and viewer codes need 4+ characters and must differ."
	return ""


func _test_cinema() -> void:
	var problem := _cinema_problem()
	if problem != "" or _hval("emby_url") == "":
		_host_test.text = problem if problem != "" else "No cinema set up: this server will show “No cinema on this server”."
		return
	_host_test.text = "Testing…"
	var notes := []
	if LINK.helper_path() == "":
		notes.append("The cinema helper (pengloo-cinema) isn't next to the game; reinstall the desktop download.")
	if OS.execute("ffmpeg", ["-version"]) != 0:
		notes.append("ffmpeg isn't installed: the big screen in the cinema needs it (ffmpeg.org).")
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var me: Variant = JSON.parse_string(body.get_string_from_utf8()) if code == 200 else null
		var head := "Connected to Emby as %s." % str(me.get("Name", "?")) if me is Dictionary else \
			("Emby rejected the key or user ID (HTTP %d)." % code if result == HTTPRequest.RESULT_SUCCESS else "Couldn't reach that Emby server.")
		_host_test.text = " ".join([head] + notes))
	# goes straight from this computer to the host's own media server, never via pengloo.party
	req.request(_hval("emby_url").trim_suffix("/") + "/Users/" + _hval("emby_user").uri_encode(), ["X-Emby-Token: " + _hval("emby_key")])


func _start_hosting() -> void:
	var server_name := _hval("name")
	if not RegEx.create_from_string("^[\\p{L}\\p{N} '._!?&-]{3,32}$").search(server_name):
		UIKit.set_field_error(_hf["name"], "3-32 letters, numbers and simple punctuation.")
		return
	var problem := _cinema_problem()
	if problem != "":
		_host_test.text = problem
		return
	var cf := ConfigFile.new()
	cf.set_value("server", "name", server_name)
	cf.set_value("server", "max_players", int(_host_max.value))
	var v := _cinema_fields()
	var keys := ["emby_url", "emby_key", "emby_user", "host_code", "viewer_code"]
	for i in keys.size():
		cf.set_value("cinema", keys[i], v[i])
	cf.save(HOSTING)
	Net.public_listing = true
	Net.server_name = server_name
	Net.max_players = int(_host_max.value)
	Net.host_cinema = ""
	Net.host_cinema_env = ""
	if v[0] != "":
		var env := FileAccess.open(HOST_CINEMA_ENV, FileAccess.WRITE)
		if env:
			env.store_string("EMBY_URL=%s\nEMBY_API_KEY=%s\nEMBY_USER_ID=%s\nCINEMA_HOST_CODE=%s\nCINEMA_VIEWER_CODE=%s\n" % v)
			env.close()
			Net.host_cinema_env = HOST_CINEMA_ENV
	_profile["world"] = _selected
	_save_profile()
	Net.preferred_color = _color
	_joining_server = server_name
	host_requested.emit()


# ---- profile --------------------------------------------------------------------------------
var _profile := {}


func _has_profile() -> bool:
	return _profile.has("name")


func _load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(PROFILE) == OK:
		for k in ["name", "color", "world", "admin"]:
			if cf.has_section_key("penguin", k):
				_profile[k] = cf.get_value("penguin", k)
	_color = int(_profile.get("color", 0))
	if FileAccess.file_exists(Outfit.PATH):
		_color = int(Outfit.load_look().get("color", _color))
	Net.admin_code = str(_profile.get("admin", ""))


func _save_profile() -> void:
	_profile["name"] = player_name()
	_profile["color"] = _color
	var look := Outfit.load_look()
	look["color"] = _color
	Outfit.save_look(look)
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
