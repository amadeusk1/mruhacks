class_name LivingTown
extends Node3D

## Makes the town live through a day. Every client derives the time of day from the same wall
## clock (one full day every CYCLE_S seconds), so everybody sees the same light without any
## networking. The sun arcs over and sets, the sky and ambient light shift through dusk to a
## moonlit blue night, the lanterns switch on (glowing halos plus a few real lights near the
## player), northern lights ripple along the top of the screen, and the snowfall comes and goes.
##
## The Day/Night button (or N) sweeps your own view to daylight or night (it is local only).

const CYCLE_S := 600.0
const KEYFRAMES := [["Morning", 0.31], ["Noon", 0.5], ["Dusk", 0.745], ["Night", 0.0]]
const LAMP_LIGHTS := 5  # real lights near the player; the rest are halo sprites only
const LAMP_COLOR := Color("#FFC76B")

static var hour_override := -1.0  # tools and --tod=
static var offset := 0.0  # local day/night switch

var _town: Node
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _base := {}
var _lamps: Array = []  # Vector3 socket positions
var _halos: Array = []  # Sprite3D, one per lamp
var _pool: Array = []  # {light, lamp, e, want}
var _snow: GPUParticles3D
var _aurora_mat: ShaderMaterial
var _toast: Label
var _toast_t := 0.0
var _sweep := 0.0  # day-fraction still to travel for a day/night switch
var _button: Button
var _scan := 0.0
var _t := 0.0


## 0..1 through the day: 0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset.
static func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	return fposmod(Time.get_unix_time_from_system() / CYCLE_S + offset, 1.0)


static func elevation(h: float) -> float:
	return sin((h - 0.25) * TAU)


static func daylight(h: float) -> float:
	return smoothstep(-0.1, 0.28, elevation(h))


static func night(h: float) -> float:
	return 1.0 - daylight(h)


static func phase_name(h: float) -> String:
	var el := elevation(h)
	var rising := h < 0.5
	if el > 0.55:
		return "Day"
	if el > 0.0:
		return "Morning" if rising else "Evening"
	if el > -0.25:
		return "Dawn" if rising else "Dusk"
	return "Night"


## How hard it is snowing, 0..1, slowly drifting (same for everyone).
static func snowiness() -> float:
	var u := Time.get_unix_time_from_system()
	return 0.5 + 0.5 * sin(u / 97.0 + sin(u / 233.0) * 2.0)


func _ready() -> void:
	name = "LivingTown"
	_town = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tod="):
			hour_override = float(arg.trim_prefix("--tod="))
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		set_process(false)
		return
	var we := world.get_node("WorldEnvironment") as WorldEnvironment
	_sun = world.get_node("DirectionalLight3D") as DirectionalLight3D
	if we.environment != null and we.environment.sky != null:
		_env = we.environment.duplicate(true)  # never tint the shared resource
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
		_base = {
			"top": _sky.sky_top_color, "horizon": _sky.sky_horizon_color,
			"ground": _sky.ground_bottom_color, "ground_h": _sky.ground_horizon_color,
			"amb": _env.ambient_light_color, "amb_e": _env.ambient_light_energy,
			"sun": _sun.light_color, "sun_e": _sun.light_energy,
		}
	_find_lamps()
	_build_lamp_visuals()
	_build_aurora()
	_snow = _town.get_node_or_null("Snowfall") as GPUParticles3D
	_apply(hour())


func _find_lamps() -> void:
	for n in _town.find_children("socket_light*", "Node3D", true, false):
		_lamps.append((n as Node3D).global_position)


func _build_lamp_visuals() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	for p in _lamps:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.03
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.double_sided = true
		s.transparent = true
		s.modulate = Color(LAMP_COLOR.r, LAMP_COLOR.g, LAMP_COLOR.b, 0.0)
		s.visible = false
		add_child(s)
		s.global_position = p
		_halos.append(s)
	for i in LAMP_LIGHTS:
		var l := OmniLight3D.new()
		l.light_color = LAMP_COLOR
		l.omni_range = 6.0
		l.light_energy = 0.0
		l.light_specular = 0.2
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append({"light": l, "lamp": -1, "e": 0.0, "want": false})


func _build_aurora() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AuroraLayer"
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aurora_mat = ShaderMaterial.new()
	_aurora_mat.shader = load("res://scripts/world/aurora.gdshader")
	rect.material = _aurora_mat
	layer.add_child(rect)
	var hud := CanvasLayer.new()
	hud.layer = 3
	add_child(hud)
	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.offset_left = 18.0
	_toast.offset_top = -48.0
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.24))
	_toast.add_theme_constant_override("outline_size", 6)
	var font := load("res://fonts/Fredoka-Bold.ttf") as Font
	if font != null:
		_toast.add_theme_font_override("font", font)
	_toast.modulate.a = 0.0
	hud.add_child(_toast)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left = -190.0
	_button.offset_right = -18.0
	_button.offset_top = 84.0
	_button.offset_bottom = 124.0
	_button.add_theme_font_size_override("font_size", 17)
	if font != null:
		_button.add_theme_font_override("font", font)
	_button.pressed.connect(toggle_day_night)
	hud.add_child(_button)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		toggle_day_night()
		get_viewport().set_input_as_handled()


## Switches your own view between day and night with a quick sunrise/sunset sweep.
func toggle_day_night() -> void:
	var going_night := daylight(hour()) > 0.5
	var target := 0.0 if going_night else 0.5  # midnight or noon
	_sweep = fposmod(target - hour(), 1.0)
	_toast.text = "Night mode (your view only)" if going_night else "Daylight mode (your view only)"
	_toast_t = 2.2


func _refresh_button() -> void:
	if _button != null:
		_button.text = "Switch to day" if night(hour()) > 0.5 else "Switch to night"

func _process(delta: float) -> void:
	_t += delta
	if _sweep > 0.0:
		var step := minf(_sweep, delta * 0.35)
		offset += step
		_sweep -= step
	_refresh_button()
	_apply(hour())
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.25
		_assign_lights()
	_fade_lights(delta)
	if _snow != null:
		_snow.amount_ratio = lerpf(0.3, 1.0, snowiness())
	_toast_t = maxf(_toast_t - delta, 0.0)
	_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)


func _apply(h: float) -> void:
	var el := elevation(h)
	var day := daylight(h)
	var dusk := exp(-pow(el / 0.22, 2.0))  # warm band around each horizon crossing
	var night_f := 1.0 - day
	var aur := 0.5 + 0.5 * sin(_t * 0.17)

	# sun by day, moon by night: one light that arcs across the sky and swaps over at the horizon
	var a := (h - 0.25) * TAU
	var dir := Vector3(cos(a), sin(a), 0.0)
	if dir.y < 0.0:
		dir = -dir
	dir = Basis(Vector3.UP, deg_to_rad(-38.0)) * (Basis(Vector3.RIGHT, deg_to_rad(28.0)) * dir)
	_sun.global_transform.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	if not _base.is_empty():
		var sun_e: float = _base["sun_e"]
		_sun.light_energy = lerpf(sun_e * 0.2, sun_e, day) * smoothstep(0.0, 0.3, absf(el))
		var moon := Color(0.55, 0.68, 1.0).lerp(Color(0.45, 1.0, 0.75).lerp(Color(0.8, 0.55, 1.0), aur), 0.3 * night_f)
		var c: Color = (_base["sun"] as Color).lerp(Color(1.0, 0.52, 0.28), dusk * 0.85)
		_sun.light_color = c.lerp(moon, smoothstep(0.0, -0.18, el))

		var top := Color(0.025, 0.04, 0.14).lerp(_base["top"], day).lerp(Color(0.3, 0.24, 0.5), dusk * 0.8)
		var hor := Color(0.09, 0.13, 0.3).lerp(_base["horizon"], day).lerp(Color(1.0, 0.5, 0.3), dusk * 0.85)
		_sky.sky_top_color = top
		_sky.sky_horizon_color = hor
		_sky.ground_bottom_color = Color(0.03, 0.06, 0.14).lerp(_base["ground"], day)
		_sky.ground_horizon_color = hor
		var amb := Color(0.32, 0.42, 0.9).lerp(_base["amb"], day).lerp(Color(1.0, 0.7, 0.6), dusk * 0.4)
		_env.ambient_light_color = amb
		_env.ambient_light_energy = float(_base["amb_e"]) * lerpf(0.6, 1.0, day)
		if _env.fog_enabled:
			_env.fog_light_color = hor.lerp(Color.WHITE, 0.25 * day)

	var lamp := smoothstep(0.2, 0.7, night_f)
	if _town.get("lamp_mult") != null:
		_town.set("lamp_mult", lerpf(0.15, 1.7, lamp))
	for i in _halos.size():
		var s := _halos[i] as Sprite3D
		s.visible = lamp > 0.01
		if s.visible:
			var flick := 1.0 + 0.05 * sin(_t * 2.3 + float(i) * 1.7)
			s.modulate.a = lamp * 0.8 * flick
			s.pixel_size = lerpf(0.026, 0.04, lamp)
	if _aurora_mat != null:
		_aurora_mat.set_shader_parameter("strength", pow(night_f, 3.0) * 0.85 * (0.7 + 0.3 * aur))
		_aurora_mat.set_shader_parameter("t", _t)


func _focus() -> Vector3:
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	if me != null:
		return me.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


## Hands the few real lights to the lamps nearest the player; a light fades out before it moves.
func _assign_lights() -> void:
	if _lamps.is_empty():
		return
	var focus := _focus()
	var order := range(_lamps.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return (_lamps[a] as Vector3).distance_squared_to(focus) < (_lamps[b] as Vector3).distance_squared_to(focus))
	var want := order.slice(0, _pool.size())
	var held := {}
	for slot in _pool:
		slot["want"] = want.has(slot["lamp"])
		if slot["want"]:
			held[slot["lamp"]] = true
	var free := want.filter(func(i: int) -> bool: return not held.has(i))
	for slot in _pool:
		if not slot["want"] and float(slot["e"]) < 0.02 and not free.is_empty():
			slot["lamp"] = free.pop_front()
			slot["want"] = true
			(slot["light"] as OmniLight3D).global_position = (_lamps[slot["lamp"]] as Vector3) + Vector3(0, 0.2, 0)


func _fade_lights(delta: float) -> void:
	var lamp := smoothstep(0.2, 0.7, night(hour()))
	for slot in _pool:
		slot["e"] = move_toward(float(slot["e"]), 1.0 if slot["want"] else 0.0, delta * 2.5)
		var l := slot["light"] as OmniLight3D
		l.light_energy = 1.3 * float(slot["e"]) * lamp
		l.visible = l.light_energy > 0.02
