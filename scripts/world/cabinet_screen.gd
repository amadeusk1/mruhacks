extends Node3D
## The glowing screen of an arcade cabinet. Idle: attract mode (title, blinking "Sit to play" and
## the high score table cycling). In use: who is playing and their live score (ArcadeNet.playing).
## The duo cabinet mirrors the live Puck Rally / Snow Trails match for everyone in the room.
## Child of the cabinet; sized to the cabinet's screen insert (arcade_cabinet: 0.42 x 0.23 m).

const TITLES := {"pac": "PAC-MAN", "tetris": "TETRIS", "dino": "DINO RUN", "fish": "FISH FRENZY",
	"star": "STAR PATROL", "arcade": "PUCK RALLY"}
const ACCENT := {"pac": Color("#F2C14E"), "tetris": Color("#B48CF0"), "dino": Color("#E8EEF5"),
	"fish": Color("#8BD3E6"), "star": Color("#F0645C"), "arcade": Color("#3FB3B5")}

var game := "pac"
var duo := false
var screen_size := Vector2(0.42, 0.235)

var _vp: SubViewport
var _art: Control
var _puck: PuckBoard
var _trails: TrailsBoard
var _cab := ""              ## ArcadeNet key: the seat's bench key (solo) or the cabinet key (duo)
var _tick := 0.0
var _t := 0.0


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, int(640.0 * screen_size.y / screen_size.x)) if duo else Vector2i(320, 180)
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_art = Control.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.draw.connect(_paint)
	_vp.add_child(_art)
	if duo:
		_puck = PuckBoard.new()
		_puck.mirror = true
		_puck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_puck.visible = false
		_vp.add_child(_puck)
		_trails = TrailsBoard.new()
		_trails.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_trails.visible = false
		_trails.set_process(false)  # display only: no input here
		_vp.add_child(_trails)
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = screen_size
	quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	m.emission_enabled = true
	m.emission_texture = _vp.get_texture()
	m.emission_energy_multiplier = 0.35
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	var live := _live_state()
	var rate := 0.05 if not live.is_empty() else 0.12
	if _tick > 0.0:
		return
	_tick = rate
	if _cab == "":
		_cab = _resolve_key()
	if duo:
		var g := str(live.get("game", ""))
		_puck.visible = g == "puck"
		_trails.visible = g == "trails"
		if g == "puck":
			_puck.apply_view(float(live.get("px", 0.5)), float(live.get("py", 0.5)), float(live.get("lp", 0.5)), float(live.get("rp", 0.5)))
		elif g == "trails":
			_trails.apply_view(live)
	_art.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Live duo state worth showing (countdown or live), else {}.
func _live_state() -> Dictionary:
	if not duo:
		return {}
	var s: Dictionary = ArcadeNet.duo.get(_cab, {}) if _cab != "" else {}
	return s if str(s.get("phase", "")) in ["countdown", "live"] else {}


func _paint() -> void:
	var sz := _art.size
	var accent: Color = ACCENT.get(game, Color.WHITE)
	var font := _art.get_theme_default_font()
	var live := _live_state()
	if not live.is_empty():
		var names: Array = live.get("names", ["", ""])
		var bar := Rect2(0, 0, sz.x, sz.y * 0.2)
		_art.draw_rect(bar, Color(0.03, 0.06, 0.14, 0.75))
		var line := "%s %d  ·  %d %s" % [names[0] if names.size() > 0 else "", int(live.get("sa", 0)), int(live.get("sb", 0)), names[1] if names.size() > 1 else ""]
		_art.draw_string(font, Vector2(0, sz.y * 0.16), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * 0.15), Color.WHITE)
		if str(live.get("phase", "")) == "countdown":
			_art.draw_string(font, Vector2(0, sz.y * 0.75), str(int(ceil(float(live.get("left", 0.0))))), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * 0.5), Color("#FFE27A"))
		return
	# background: dark with a moving scanline sweep
	_art.draw_rect(Rect2(Vector2.ZERO, sz), Color("#0C1430"))
	for i in 18:
		var y := fposmod(i * sz.y / 18.0 + _t * 12.0, sz.y)
		_art.draw_line(Vector2(0, y), Vector2(sz.x, y), Color(1, 1, 1, 0.04), 1.0)
	var p: Dictionary = ArcadeNet.playing.get(_cab, {}) if _cab != "" else {}
	if not p.is_empty():
		_art.draw_string(font, Vector2(0, sz.y * 0.28), "NOW PLAYING", HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * 0.11), accent)
		_art.draw_string(font, Vector2(0, sz.y * 0.52), str(p.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * 0.17), Color.WHITE)
		_art.draw_string(font, Vector2(0, sz.y * 0.86), "%d" % int(p.get("score", 0)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * 0.26), Color("#FFE27A"))
		return
	var title: String = TITLES.get(game, game.to_upper())
	var bob := sin(_t * 2.0) * sz.y * 0.02
	_art.draw_string(font, Vector2(0, sz.y * 0.3 + bob), title, HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * (0.12 if duo else 0.17)), accent)
	var cycle := int(_t / 4.0) % 2
	var list: Array = ArcadeNet.boards.get(game, []) if not duo else []
	if cycle == 1 and not list.is_empty():
		for i in mini(3, list.size()):
			var row := "%d  %s  %d" % [i + 1, str(list[i]["name"]).substr(0, 10), int(list[i]["score"])]
			_art.draw_string(font, Vector2(0, sz.y * (0.52 + 0.15 * i)), row, HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * 0.1), Color.WHITE)
	elif int(_t * 2.0) % 2 == 0:
		var msg := "2 PLAYERS · SIT TO PLAY" if duo else "SIT TO PLAY"
		_art.draw_string(font, Vector2(0, sz.y * 0.75), msg, HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(sz.y * (0.1 if duo else 0.11)), Color.WHITE)


## Same keys ArcadeNet uses: seats under the room point back at this cabinet via meta "table".
func _resolve_key() -> String:
	var cabinet := get_parent()
	var room := cabinet.get_parent()
	while room != null and room.get_parent() != null and room.get_parent().name != "LocationHost" and not (room.get_script() and room.has_method("_seats")):
		room = room.get_parent()  # seats hang off the interior root, the cabinet off its nav region
	if room == null:
		return ""
	for seat in room.find_children("*", "", true, false):
		if seat.has_method("bench_key") and seat.has_meta("table") and seat.get_meta("table") == cabinet:
			var key := str(seat.call("bench_key"))
			return ArcadeNet._cab_of_bench(key) if duo else key
	return ""
