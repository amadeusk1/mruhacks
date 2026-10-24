extends Control
## Movie Library + Watch Party (Images/UI - Cinema and Arcade.png).
## State in: set_library(titles, source_status), set_playback({title, position, length, playing, host}).
## Intents out: play_for_group(id), toggle_play, seek(seconds), leave_seat, movie_volume/voice_volume.
## No media provider is connected yet, so the library shows a clearly labelled DEMO source.

signal intent(action: String, value: Variant)

const A := preload("res://ui/activities/act_style.gd")
const DEMO := [
	{"id": "moonbound", "title": "Moonbound", "tag": "A little penguin.\nA big sky.", "top": Color("#1B2D5C"), "bot": Color("#3A5AA0")},
	{"id": "underwater", "title": "Underwater Day", "tag": "Small friends.\nBig wonders.", "top": Color("#0F6A78"), "bot": Color("#1F9FA8")},
	{"id": "lantern", "title": "Lantern Coast", "tag": "Brighter together.", "top": Color("#5B4A7C"), "bot": Color("#E08A64")},
]

var mode := "library"          ## library | watch
var titles: Array = DEMO
var source_status := "demo"    ## demo | connected | connecting | offline
var source_name := "Demo library"
var is_host := true
var playback := {"title": "Moonbound", "position": 724.0, "length": 5708.0, "playing": true}
var _sel := "moonbound"
var _root: Control
var _seek: HSlider
var _time: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func set_library(p_titles: Array, status: String, name := "") -> void:
	titles = p_titles
	source_status = status
	source_name = name if name != "" else source_name
	_build()


func set_playback(state: Dictionary) -> void:
	playback.merge(state, true)
	if mode != "watch":
		mode = "watch"
		_build()
	_sync_time()


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = A.screen_root()
	add_child(_root)
	if mode == "watch":
		_build_watch()
	else:
		_build_library()


static func poster(t: Dictionary, w: float, h: float) -> Control:
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var g := Gradient.new()
	g.colors = PackedColorArray([t.get("top", Color("#1B2D5C")), t.get("bot", Color("#3A5AA0"))])
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
	var tag := A.label(str(t.get("tag", "")), 15, Color(1, 1, 1, 0.9), false, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(tag)
	return r


func _build_library() -> void:
	var p := A.panel(26, 28)
	A.pin(_root, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-520, -300, 520, 300))
	var v := A.vbox(18)
	p.add_child(v)
	var head := A.hbox(16)
	v.add_child(head)
	head.add_child(A.icon("camera", 46, A.NAVY))
	head.add_child(A.title("Movie Library", 44))
	head.add_child(A.expander())
	var dot: Color = {"demo": Color("#E3A92B"), "connected": UITokens.GREEN, "connecting": UITokens.BLUE_DOT, "offline": UITokens.GREY_DOT}[source_status]
	var st_text: String = {"demo": "Demo library\n(no server connected)", "connected": "Connected to\n" + source_name,
		"connecting": "Connecting to\n" + source_name, "offline": "Library offline\nRetry from Settings"}[source_status]
	head.add_child(UIKit.status(st_text, dot))
	var row := A.hbox(22, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(row)
	for t in titles:
		var on: bool = t["id"] == _sel
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 340)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = str(t["title"])
		var sb := A.box(Color.TRANSPARENT, 18, 5 if on else 0, Color("#5ED8CF"), 0)
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 18, 3, A.NAVY, 0))
		b.pressed.connect(func() -> void: _sel = t["id"]; _build())
		var po := poster(t, 290, 330)
		A.pin(b, po, Vector4(0, 0, 1, 1), Vector4(5, 5, -5, -5))
		var clip := po
		clip.clip_contents = true
		row.add_child(b)
	var play := A.button("Play for Group", "primary", "play", 30, Vector2(480, 76))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.disabled = not is_host
	play.tooltip_text = "" if is_host else "Only the host picks the film"
	play.pressed.connect(func() -> void: intent.emit("play_for_group", _sel); mode = "watch"; playback["title"] = _title(_sel); playback["position"] = 0.0; _build())
	v.add_child(play)
	var x := A.close_disc(56)
	x.pressed.connect(close)
	A.pin(_root, x, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(540, -300, 596, -244))


func _title(id: String) -> String:
	for t in titles:
		if t["id"] == id:
			return str(t["title"])
	return id


func _build_watch() -> void:
	var screen := ColorRect.new()
	screen.color = Color("#0C1428")
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(screen)
	var t := titles[0] as Dictionary
	for tt in titles:
		if tt["title"] == playback["title"]:
			t = tt
	var po := poster(t, 1280, 720)
	po.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c in po.get_children():
		if c is VBoxContainer:
			c.queue_free()
	screen.add_child(po)
	var host := A.chip("Host controls playback" if not is_host else "You control playback", Color(0.06, 0.1, 0.2, 0.75), A.WHITE, "users", 19, Vector2(20, 12))
	A.pin(_root, host, Vector4(0, 0, 0, 0), Vector4(24, 20, 0, 0))
	var demo := A.chip("Demo film", Color(0.95, 0.66, 0.18, 0.9), A.NAVY, "", 16, Vector2(14, 6))
	if source_status == "demo":
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
	_seek.max_value = float(playback["length"])
	_seek.value = float(playback["position"])
	_seek.editable = is_host
	_seek.drag_ended.connect(func(_c: bool) -> void: intent.emit("seek", _seek.value))
	seekrow.add_child(_seek)
	_time = A.label("", 20, A.WHITE, true)
	seekrow.add_child(_time)
	var ctl := A.hbox(16)
	v.add_child(ctl)
	var pp := UIKit.icon_button("pause" if playback["playing"] else "play", "Play/Pause", 56)
	pp.disabled = not is_host
	pp.add_theme_color_override("icon_normal_color", A.WHITE)
	pp.pressed.connect(func() -> void: playback["playing"] = not playback["playing"]; intent.emit("toggle_play", playback["playing"]); _build())
	ctl.add_child(pp)
	ctl.add_child(_volume("camera", "Movie volume", "movie"))
	ctl.add_child(_volume("mic", "Voice volume", "voice"))
	ctl.add_child(A.expander())
	var leave := A.button("Leave seat", "danger", "seat", 22, Vector2(220, 60))
	leave.pressed.connect(close)
	ctl.add_child(leave)
	_sync_time()


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
	_time.text = "%s / %s" % [_fmt(float(playback["position"])), _fmt(float(playback["length"]))]
	if _seek:
		_seek.value = float(playback["position"])


static func _fmt(t: float) -> String:
	var s := int(t)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60] if s >= 3600 else "%d:%02d" % [s / 60, s % 60]


func _process(delta: float) -> void:
	if mode == "watch" and bool(playback["playing"]):
		playback["position"] = minf(float(playback["position"]) + delta, float(playback["length"]))
		_sync_time()


func close() -> void:
	intent.emit("leave_seat" if mode == "watch" else "close", null)
	queue_free()


func preview(state: String) -> void:
	mode = "watch" if state == "watch" else "library"
	is_host = state != "watch"
	_build()
	if mode == "watch":
		playback["playing"] = false
		_sync_time()
