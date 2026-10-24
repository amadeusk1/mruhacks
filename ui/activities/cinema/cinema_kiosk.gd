extends Control
## Lobby kiosk: pick tonight's film for Screen 1 (Moonbound Watch Party flow).
## Poster grid from CinemaSession.source (Emby gateway, or the labelled Demo library), search,
## genre chips, a detail panel and one big start button. Non-hosts suggest; the host sees the queue.

const A := preload("res://ui/activities/act_style.gd")
const NIGHT := Color("#1B2238")

var _sel := ""
var _query := ""
var _genre := ""
var _root: Control
var _tiles := {}       # media id -> TextureRect (posters stream in after the grid is built)
var _code: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	CinemaSession.source_changed.connect(_rewire)
	CinemaSession.ensure_source()
	_rewire()
	# method callables (not lambdas) so the autoload drops them when the kiosk is freed
	CinemaSession.suggestions_changed.connect(_build.unbind(1))
	CinemaSession.film_selected.connect(_build.unbind(2))
	CinemaSession.watchers_changed.connect(_build.unbind(1))


func src() -> CinemaSource:
	return CinemaSession.source


func _items() -> Array:
	return src().items.filter(func(t: Dictionary) -> bool: return _genre == "" or _genre in t.get("genres", []))


func _selected() -> Dictionary:
	for t in src().items:
		if t["id"] == _sel:
			return t
	var list := _items()
	if list.is_empty():
		return {}
	_sel = str(list[0]["id"])
	return list[0]


func _build() -> void:
	if _root:
		_root.queue_free()
	_tiles.clear()
	_root = A.screen_root()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.14, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var p := A.panel(24, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-600, -334, 600, 334))
	var v := A.vbox(14)
	p.add_child(v)
	var head := A.hbox(14)
	v.add_child(head)
	head.add_child(A.icon("film", 40, A.NAVY))
	head.add_child(A.title("Movie Night", 38))
	head.add_child(A.label("Screen 1", 22, A.SUB, true))
	head.add_child(A.expander())
	head.add_child(_source_chip())
	var x := A.close_button(44)
	x.pressed.connect(close)
	head.add_child(x)
	match src().status:
		"signed_out", "signing_in":
			v.add_child(_sign_in())
		"connecting":
			v.add_child(UIWidgets.state_panel("loading", "Opening the film library", "Checking the cinema service..."))
		_:
			v.add_child(_browser())


func _source_chip() -> Control:
	var s := src()
	var ok := s.status in ["connected", "demo"]
	var c := A.chip(("%s library" % s.source_name) if s.provider_type != "demo" else "Demo library",
		A.TEAL_SOFT if ok else Color("#FBEFD3"), A.TEAL_DARK if ok else Color("#9A6A12"), "film" if ok else "info", 16, Vector2(14, 6))
	c.tooltip_text = s.detail
	return c


# ---- sign-in: the invite code goes straight to the gateway and is never kept ----------------
func _sign_in() -> Control:
	var row := A.hbox(0, BoxContainer.ALIGNMENT_CENTER)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := PanelContainer.new()
	card.theme_type_variation = "Inset"
	card.custom_minimum_size = Vector2(520, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	var v := A.vbox(14)
	card.add_child(v)
	v.add_child(A.title("Sign in to the cinema", 30))
	v.add_child(A.label("Enter the invite code from your movie-night host.\nHosts' codes can start films; guests can suggest.", 17, A.SUB))
	var f := UIKit.field("Invite code", "", false)
	_code = f["field"]
	_code.secret = true
	_code.custom_minimum_size.y = 50
	_code.text_submitted.connect(func(_t: String) -> void: _submit())
	v.add_child(f["root"])
	if src().detail != "" and src().status == "signed_out" and src().detail != "Enter your cinema invite code":
		v.add_child(A.label(src().detail, 16, A.CORAL_DARK))
	var go := A.button("Signing in..." if src().status == "signing_in" else "Sign in as %s" % CinemaSession.me_name(), "primary", "users", 22, Vector2(0, 58))
	go.disabled = src().status == "signing_in"
	go.pressed.connect(_submit)
	v.add_child(go)
	var demo := A.button("Browse the demo library instead", "ghost", "", 17, Vector2(0, 40))
	demo.pressed.connect(CinemaSession.use_demo)
	v.add_child(demo)
	_code.grab_focus.call_deferred()
	return row


func _submit() -> void:
	if _code == null or _code.text.strip_edges() == "":
		return
	var code := _code.text.strip_edges()
	_code.text = ""
	src().sign_in(CinemaSession.me_name(), code)


## (Re)subscribe whenever the session swaps sources (gateway -> Demo fallback).
func _rewire() -> void:
	var s := src()
	if s.thumb_ready.is_connected(_on_thumb):
		return
	s.status_changed.connect(_build.unbind(2))
	s.catalog_changed.connect(_build.unbind(1))
	s.thumb_ready.connect(_on_thumb)
	_build()



# ---- browse ------------------------------------------------------------------------------
func _browser() -> Control:
	var body := A.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := A.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var le := LineEdit.new()
	le.placeholder_text = "Search films"
	le.text = _query
	le.custom_minimum_size.y = 46
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(q: String) -> void: _query = q; _sel = ""; src().search(q))
	var search := A.hbox(10)
	search.add_child(le)
	var go := A.button("", "secondary", "search", 20, Vector2(52, 46))
	go.tooltip_text = "Search"
	go.pressed.connect(func() -> void: _query = le.text; _sel = ""; src().search(le.text))
	search.add_child(go)
	left.add_child(search)
	left.add_child(_genre_chips())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var list := _items()
	if list.is_empty():
		scroll.add_child(UIWidgets.state_panel("empty", "No films here", "Try another search or genre."))
	else:
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		scroll.add_child(grid)
		var sel := _selected()
		for t in list.slice(0, 60):
			grid.add_child(_tile(t, t["id"] == sel.get("id")))
	body.add_child(_detail(_selected()))
	return body


func _genre_chips() -> Control:
	var counts := {}
	for t in src().items:
		for g in t.get("genres", []):
			counts[g] = int(counts.get(g, 0)) + 1
	var genres := counts.keys()
	genres.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var row := A.hbox(8)
	for g in [""] + genres.slice(0, 5):
		var b := A.button("All" if g == "" else g, "primary" if g == _genre else "secondary", "", 15, Vector2(0, 36))
		b.pressed.connect(func() -> void: _genre = g; _sel = ""; _build())
		row.add_child(b)
	return row


func _tile(t: Dictionary, on: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(134, 232)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = str(t["title"])
	var sb := A.box(Color.TRANSPARENT, 14, 4 if on else 0, A.TEAL, 0)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_stylebox_override("hover", A.box(Color(0, 0, 0, 0.04), 14, 4 if on else 0, A.TEAL, 0))
	b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 14, 3, A.NAVY, 0))
	b.pressed.connect(func() -> void: _sel = t["id"]; _build())
	var art := _poster(t)
	A.pin(b, art, Vector4(0, 0, 1, 0), Vector4(6, 6, -6, 186))
	_tiles[t["id"]] = art
	var name := A.label(str(t["title"]), 15, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	A.pin(b, name, Vector4(0, 0, 1, 0), Vector4(4, 192, -4, 226))
	return b


## Poster art, or a night-sky placeholder with the title until the image arrives.
func _poster(t: Dictionary) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.clip_contents = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t.get("thumb") is Texture2D:
		r.texture = t["thumb"]
		return r
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	tex.gradient = Gradient.new()
	tex.gradient.colors = PackedColorArray([Color(str(t.get("top", "#1B2D5C"))), Color(str(t.get("bot", "#3A5AA0")))])
	r.texture = tex
	var cap := A.label(str(t["title"]), 17, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	cap.name = "Placeholder"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	A.pin(r, cap, Vector4(0, 0, 1, 1), Vector4(8, 8, -8, -8))
	var stars := A.icon("star", 20, Color("#FFD66B"))
	A.pin(r, stars, Vector4(0.5, 0, 0.5, 0), Vector4(-10, 14, 10, 34))
	return r


func _on_thumb(id: String, tex: Texture2D) -> void:
	for key in [id, id + ":detail"]:
		var r: TextureRect = _tiles.get(key)
		if is_instance_valid(r):
			r.texture = tex
			for c in r.get_children():
				c.queue_free()


func _detail(t: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Inset"
	card.custom_minimum_size = Vector2(400, 0)
	var v := A.vbox(12)
	card.add_child(v)
	if t.is_empty():
		v.add_child(A.label("Pick a film to see its details.", 18, A.SUB))
		return card
	var top := A.hbox(14)
	v.add_child(top)
	var art := _poster(t)
	art.custom_minimum_size = Vector2(118, 177)
	_tiles[str(t["id"]) + ":detail"] = art
	top.add_child(art)
	var info := A.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var name := A.title(str(t["title"]), 26)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name)
	var meta: Array = []
	if int(t.get("year", 0)) > 0:
		meta.append(str(t["year"]))
	if float(t.get("duration_s", 0.0)) > 0.0:
		meta.append(runtime(float(t["duration_s"])))
	info.add_child(A.label(" · ".join(meta), 17, A.SUB, true))
	var gl := HFlowContainer.new()
	gl.add_theme_constant_override("h_separation", 6)
	gl.add_theme_constant_override("v_separation", 6)
	for g in (t.get("genres", []) as Array).slice(0, 3):
		gl.add_child(A.chip(str(g), A.CARD, A.NAVY, "", 14, Vector2(10, 4)))
	info.add_child(gl)
	var syn := A.label(str(t.get("summary", "")) if str(t.get("summary", "")) != "" else "No synopsis yet.", 16, A.NAVY)
	syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	syn.max_lines_visible = 5
	syn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(syn)
	v.add_child(A.expander())
	if CinemaSession.is_host():
		v.add_child(_queue())
	v.add_child(_cta(t))
	v.add_child(_host_line())
	return card


func _cta(t: Dictionary) -> Button:
	var s := CinemaSession
	if str(s.film.get("id", "")) == str(t["id"]) and not s.film.is_empty():
		var b := A.button("Now showing · find a seat", "secondary", "seat", 21, Vector2(0, 64))
		b.pressed.connect(close)
		return b
	if s.can_start():
		var b := A.button("Start Movie Night in Screen 1", "primary", "play", 22, Vector2(0, 64))
		b.pressed.connect(func() -> void: s.start_movie(t); close())
		return b
	var b := A.button("Suggest to host", "primary", "send", 22, Vector2(0, 64))
	b.pressed.connect(func() -> void:
		s.suggest(t)
		UIWidgets.toast(self, "Suggested %s" % t["title"], "send"))
	for q in s.suggestions:
		if q["film"]["id"] == t["id"]:
			b.text = "Suggested · waiting for host"
			b.disabled = true
	return b


func _host_line() -> Label:
	var s := CinemaSession
	var txt := "No host yet · start a film to host tonight"
	if s.is_host():
		txt = "You're hosting · %d watching" % s.watchers.size()
	elif s.host_id != 0:
		var who := "A friend"
		for p in Net.roster():
			if int(p.get("id", 0)) == s.host_id:
				who = str(p["name"])
		txt = "%s is hosting · suggest a film" % who
	elif not src().can_host():
		txt = "Guest pass · suggest films to the host"
	return A.label(txt, 15, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)


func _queue() -> Control:
	var v := A.vbox(6)
	if CinemaSession.suggestions.is_empty():
		return v
	v.add_child(A.label("Suggestions", 17, A.NAVY, true))
	for q in CinemaSession.suggestions.slice(0, 3):
		var row := A.hbox(8)
		row.add_child(A.icon("send", 18, A.SUB))
		var l := A.label("%s · %s" % [q["film"]["title"], q["by"]], 15, A.NAVY)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		var pick := A.button("View", "light", "", 14, Vector2(0, 32))
		pick.pressed.connect(func() -> void: _sel = str(q["film"]["id"]); _genre = ""; _build())
		row.add_child(pick)
		v.add_child(row)
	return v


static func runtime(seconds: float) -> String:
	var m := int(seconds / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%d min" % m


func close() -> void:
	queue_free()


## Preview harness: "browse" (default), "guest" (someone else hosts, with a suggestion queued),
## "host_queue", "signin".
func preview(state: String) -> void:
	CinemaSession.use_demo()
	match state:
		"guest":
			CinemaSession.host_id = 77
			CinemaSession.suggestions = [{"film": src().items[1], "by": "Pebble", "by_id": 3}]
			_sel = "demo:lantern"
		"host_queue":
			CinemaSession.host_id = Net.local_id()
			CinemaSession.suggestions = [{"film": src().items[1], "by": "Pebble", "by_id": 3},
				{"film": src().items[2], "by": "Waddles", "by_id": 4}]
		"signin":
			src().status = "signed_out"
	_build()
