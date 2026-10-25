extends Control
## Movie Library + Watch Party (Images/UI - Cinema and Arcade.png), driven by a CinemaSource adapter
## (cinema_source.gd; Plex via adapted plex-watchparty later). The UI never fetches media itself.
## The demo source stays clearly labelled until a real adapter is plugged in with use_source().
## Intents also go out on `intent` for the game layer (seat release, voice routing).

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const STATUS := {
	"demo": ["Demo library\n(no server connected)", Color("#E3A92B")],
	"signed_out": ["Media server\nsign-in needed", Color("#E3A92B")],
	"connecting": ["Connecting to\n%s", Color("#4A8BE0")],
	"signing_in": ["Sign in to\n%s", Color("#E3A92B")],
	"connected": ["Connected to\n%s", Color("#14B28B")],
	"empty": ["Connected · no films\nin this library", Color("#A9ABB2")],
	"offline": ["Library offline\nRetry from Settings", Color("#A9ABB2")],
	"error": ["Source error\n%s", Color("#D6453C")],
}

var mode := "library"          ## library | watch
var source: CinemaSource
var _sel := ""
var _query := ""
var _root: Control
var _seek: HSlider
var _time: Label
var _last_media := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if source == null:
		use_source(GatewaySource.new() if CinemaService.enabled("service_enabled") else CinemaSource.DemoSource.new())


## Plug in the media adapter (Demo now; PlexWatchpartySource once the service exists).
func use_source(s: CinemaSource) -> void:
	source = s
	source.status_changed.connect(func(st: String, _d: String) -> void:
		if st == "offline" and source is GatewaySource:  # service down: the labelled Demo, never a dead end
			use_source.call_deferred(CinemaSource.DemoSource.new())
			return
		_build())
	source.catalog_changed.connect(func(its: Array) -> void:
		if _sel == "" and not its.is_empty(): _sel = str(its[0]["id"])
		_build())
	source.snapshot_changed.connect(func(snap: Dictionary) -> void:
		var media := str(snap.get("media_id", ""))
		if media != "" and media != _last_media:  # a (new) film started: watch it
			mode = "watch"
		_last_media = media
		_build())
	source.connect_source()
	_build()


func is_controller() -> bool:
	return source != null and (source.snapshot.is_empty() or source.is_controller(str(Net.local_id())))


func _build() -> void:
	if mode != "watch" and CinemaService.player:
		CinemaService.player.unwatch(self)
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	if mode == "watch":
		_build_watch()
	else:
		_build_library()


static func poster(t: Dictionary, w: float, h: float) -> Control:
	if t.get("thumb") is Texture2D:
		var img := TextureRect.new()
		img.texture = t["thumb"]
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(w, h)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := A.vbox(0)
		cap.alignment = BoxContainer.ALIGNMENT_END
		A.pin(img, cap, Vector4(0, 0, 1, 1), Vector4(8, 8, -8, -12))
		cap.add_child(A.label(str(t["title"]), 25, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
		return img
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(str(t.get("top", "#1B2D5C"))), Color(str(t.get("bot", "#3A5AA0")))])
	tex.gradient = g
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(w, h)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = A.asset_icon("avatar/avatar_base")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color(0.75, 0.82, 1.0, 0.95)
	A.pin(r, art, Vector4(0.2, 0.18, 0.8, 0.62))
	var v := A.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_END
	A.pin(r, v, Vector4(0, 0, 1, 1), Vector4(8, 8, -8, -12))
	v.add_child(A.label(str(t["title"]), 25, A.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := str(t.get("summary", ""))
	if int(t.get("year", 0)) > 0:
		sub += "\n%d · %s" % [int(t["year"]), _fmt(float(t.get("duration_s", 0)))]
	var tag := A.label(sub, 15, Color(1, 1, 1, 0.9), false, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(tag)
	return r


func _build_library() -> void:
	var p := A.panel(26, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-520, -320, 520, 320))
	var v := A.vbox(16)
	p.add_child(v)
	var head := A.hbox(16)
	v.add_child(head)
	head.add_child(A.icon("camera", 46, A.NAVY))
	head.add_child(A.title("Movie Library", 44))
	head.add_child(A.expander())
	var st: Array = STATUS.get(source.status, STATUS["offline"])
	var txt := str(st[0])
	if txt.contains("%s"):
		txt = txt % (source.label() if source.status != "error" else source.detail)
	head.add_child(UIKit.status(txt, st[1]))
	var f := UIKit.field("Search films", _query, false)
	(f["field"] as LineEdit).custom_minimum_size.y = 46
	(f["field"] as LineEdit).text_submitted.connect(func(q: String) -> void: _query = q; source.search(q))
	v.add_child(f["root"])
	var row := A.hbox(22, BoxContainer.ALIGNMENT_CENTER)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	if Net.community and not Net.community_cinema:
		row.add_child(UIWidgets.state_panel("empty", "No cinema on this server", "Movies are available on the official Pengloo Party server.", []))
	elif source.status == "signed_out" and source is GatewaySource:
		row.add_child(_sign_in_row())
	elif source.status in ["signed_out", "offline", "error", "connecting"] or source.items.is_empty():
		var kind := "loading" if source.status == "connecting" else ("empty" if source.items.is_empty() and source.status in ["connected", "demo", "empty"] else "error")
		var msg := {"loading": "Loading the library...", "empty": "No films match. Try another search.", "error": "The media server isn't reachable right now."}[kind] as String
		row.add_child(UIWidgets.state_panel(kind, "Movie Library", msg, []))
	else:
		for t in source.items.slice(0, 3):
			var on: bool = t["id"] == _sel
			var b := Button.new()
			b.custom_minimum_size = Vector2(300, 330)
			b.focus_mode = Control.FOCUS_ALL
			b.tooltip_text = str(t["title"])
			var sb := A.box(Color.TRANSPARENT, 18, 5 if on else 0, Color("#5ED8CF"), 0)
			for k in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(k, sb)
			b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 18, 3, A.NAVY, 0))
			b.pressed.connect(func() -> void: _sel = t["id"]; _build())
			var po := poster(t, 290, 320)
			po.clip_contents = true
			A.pin(b, po, Vector4(0, 0, 1, 1), Vector4(5, 5, -5, -5))
			row.add_child(b)
	var guest: bool = source is GatewaySource and source.status == "connected" and not source.can_host()
	var play := A.button("Suggest to host" if guest else "Play for Group", "primary", "send" if guest else "play", 30, Vector2(480, 76))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.disabled = (Net.community and not Net.community_cinema) or _sel == "" or source.items.is_empty() or (not guest and not is_controller() and not (source is GatewaySource and source.can_host()))
	play.tooltip_text = "Sends your pick to the movie-night chat" if guest else ("" if not play.disabled else "Only the host picks the film")
	play.pressed.connect(func() -> void:
		if guest:
			_suggest(_item(_sel))
		else:
			intent.emit("play_for_group", _sel)
			source.request_load(_sel))
	v.add_child(play)
	if source is GatewaySource and not str(source.snapshot.get("media_id", "")).is_empty():
		var back := A.button("Back to the movie", "ghost", "film", 18, Vector2(0, 40))
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(func() -> void: mode = "watch"; _build())
		v.add_child(back)
	var x := A.close_disc(56)
	x.pressed.connect(close)
	A.pin(_root, x, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(540, -320, 596, -264))


## Viewers suggest a film to the host through the chat everyone in the cinema sees.
func _suggest(t: Dictionary) -> void:
	var msg := "suggests watching %s" % str(t.get("title", "a movie"))
	if Net.is_online():
		Net.say(msg)
	UIWidgets.toast(self, "Suggested %s to the host" % str(t.get("title", "")), "send")


## Signed out: say what to do and give the button right here (never a dead end).
func _sign_in_row() -> Control:
	var v := A.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(A.label("Join movie night" if source.detail == "" else source.detail, 26, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	var help := A.label("Enter the host code to pick movies, or the viewer code to watch.", 19, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(help)
	var go := A.button("Sign in", "primary", "users", 24, Vector2(320, 60))
	go.name = "SignIn"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(CinemaService.open_sign_in)
	v.add_child(go)
	return v

func _item(id: String) -> Dictionary:
	for t in source.items:
		if t["id"] == id:
			return t
	return {"id": id, "title": id}


func _build_watch() -> void:
	var screen := ColorRect.new()
	screen.color = Color("#0C1428")
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(screen)
	var snap := source.snapshot
	var t := _item(str(snap.get("media_id", "")))
	if source is GatewaySource:  # the live film from the shared player (same frames as the 3D screen)
		var live := TextureRect.new()
		live.name = "Live"
		live.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		live.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		live.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		live.texture = CinemaService.player.texture
		screen.add_child(live)
		if not CinemaService.player.texture_changed.is_connected(_on_live_texture):
			CinemaService.player.texture_changed.connect(_on_live_texture)
		CinemaService.player.watch(self)  # released when the screen leaves watch mode or closes
	else:
		var po := poster(t, 1280, 720)
		po.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for c in po.get_children():
			if c is VBoxContainer:
				c.queue_free()
		screen.add_child(po)
	var who := "You control playback" if is_controller() else "Host controls playback"
	if int(snap.get("viewers", 0)) > 0:
		who += "  ·  %d watching" % int(snap["viewers"])
	var host := A.chip(who, Color(0.06, 0.1, 0.2, 0.75), A.WHITE, "users", 19, Vector2(20, 12))
	A.pin(_root, host, Vector4(0, 0, 0, 0), Vector4(24, 20, 0, 0))
	var demo := A.chip("Demo film", Color(0.95, 0.66, 0.18, 0.9), A.NAVY, "", 16, Vector2(14, 6))
	if str(snap.get("phase", "")) in ["preparing", "buffering"]:
		A.pin(_root, A.chip("Buffering..." if snap["phase"] == "buffering" else "Preparing stream...", Color(0.06, 0.1, 0.2, 0.75), A.WHITE, "", 22, Vector2(20, 10)), Vector4(0.5, 0.45, 0.5, 0.45), Vector4(-140, -24, 140, 24))
	if source.status == "demo":
		A.pin(_root, demo, Vector4(0, 0, 0, 0), Vector4(24, 76, 0, 0))
	var x := A.close_disc(52)
	x.pressed.connect(close)
	A.pin(_root, x, Vector4(1, 0, 1, 0), Vector4(-74, 20, -22, 72))
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", A.box(Color(0.04, 0.08, 0.16, 0.72), 0, 0, Color.TRANSPARENT, 18))
	A.pin(_root, bar, Vector4(0, 1, 1, 1), Vector4(0, -170, 0, 0))
	var v := A.vbox(12)
	bar.add_child(v)
	var seekrow := A.hbox(16)
	v.add_child(seekrow)
	_seek = HSlider.new()
	_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seek.max_value = float(snap.get("duration_s", 1.0))
	_seek.value = source.position_now()
	_seek.editable = is_controller()
	_seek.drag_ended.connect(func(_c: bool) -> void: intent.emit("seek", _seek.value); source.request_seek(_seek.value))
	seekrow.add_child(_seek)
	_time = A.label("", 20, A.WHITE, true)
	seekrow.add_child(_time)
	var ctl := A.hbox(16)
	v.add_child(ctl)
	var playing := bool(snap.get("playing", false))
	var pp := UIKit.icon_button("pause" if playing else "play", "Play/Pause", 56)
	pp.disabled = not is_controller()
	pp.add_theme_color_override("icon_normal_color", A.WHITE)
	pp.pressed.connect(func() -> void:
		intent.emit("toggle_play", not playing)
		if playing: source.request_pause()
		else: source.request_play())
	ctl.add_child(pp)
	ctl.add_child(_volume("camera", "Movie volume", "movie"))
	ctl.add_child(_volume("mic", "Voice volume", "voice"))
	for kind in ["audio", "subtitle"]:
		var tracks: Array = snap.get(kind + "_tracks", [])
		if tracks.size() > 1 or (kind == "subtitle" and not tracks.is_empty()):
			var ob := OptionButton.new()
			ob.tooltip_text = "Audio" if kind == "audio" else "Captions"
			if kind == "subtitle":
				ob.add_item("Captions off")
				ob.set_item_metadata(0, "")
			for tr in tracks:
				ob.add_item(str(tr["label"]))
				ob.set_item_metadata(ob.item_count - 1, str(tr["id"]))
			ob.disabled = not is_controller()
			ob.item_selected.connect(func(i: int) -> void:
				var a := str(snap.get("audio_track", "")); var sub := str(snap.get("subtitle_track", ""))
				if kind == "audio": a = str(ob.get_item_metadata(i))
				else: sub = str(ob.get_item_metadata(i))
				source.request_tracks(a, sub))
			ctl.add_child(ob)
	ctl.add_child(A.expander())
	if is_controller() and source is GatewaySource:
		var change := A.button("Change movie", "secondary", "film", 22, Vector2(220, 60))
		change.pressed.connect(func() -> void: mode = "library"; _build())
		ctl.add_child(change)
	var leave := A.button("Leave seat", "danger", "seat", 22, Vector2(220, 60))
	leave.pressed.connect(close)
	ctl.add_child(leave)
	_sync_time()


func _exit_tree() -> void:
	if CinemaService.player:
		CinemaService.player.unwatch(self)


func _on_live_texture(t: Texture2D) -> void:
	var live := find_child("Live", true, false) as TextureRect
	if live:
		live.texture = t


func _volume(icon_name: String, text: String, key: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.box(Color(1, 1, 1, 0.12), 16, 0, Color.TRANSPARENT, 10))
	var h := A.hbox(10)
	p.add_child(h)
	h.add_child(A.icon(icon_name, 24, A.WHITE))
	h.add_child(A.label(text, 17, A.WHITE))
	h.add_child(A.icon("volume", 24, A.WHITE))
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(120, 0)
	s.value = float(UIRouter.settings.get(key, 60.0))   # movie and voice volumes stay independent
	s.value_changed.connect(func(val: float) -> void: intent.emit(key + "_volume", val); UIRouter.set_setting(key, val))
	h.add_child(s)
	return p


func _sync_time() -> void:
	if _time == null:
		return
	var pos := source.position_now()
	_time.text = "%s / %s" % [_fmt(pos), _fmt(float(source.snapshot.get("duration_s", 0.0)))]
	if _seek and not _seek.has_focus():
		_seek.value = pos


static func _fmt(t: float) -> String:
	var s := int(t)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60] if s >= 3600 else "%d:%02d" % [s / 60, s % 60]


func _process(_delta: float) -> void:
	if mode == "watch" and source and bool(source.snapshot.get("playing", false)):
		_sync_time()


func close() -> void:
	intent.emit("leave_seat" if mode == "watch" else "close", null)
	queue_free()


func preview(state: String) -> void:
	if source == null:
		use_source(GatewaySource.new() if CinemaService.enabled("service_enabled") else CinemaSource.DemoSource.new())
	match state:
		"watch":
			source.request_load("demo:moonbound")
			source.request_seek(724.0)
			source.request_pause()
			source.snapshot["controller_player_id"] = "someone-else"
			_build()
		"signed_out", "connecting", "offline":
			source.status = state
			source.items = [] if state != "connecting" else source.items
			_build()
		_:
			mode = "library"
			_build()
