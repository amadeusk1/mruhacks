extends Control
## Pengloo Party title screen (board "Main Menu and Entry", panel 1): the real town drifting behind
## a chunky wordmark, a live penguin, a big Play button, a Settings pill and a quiet Quit.

const WORLD_SCENE := "res://scenes/world.tscn"
const T := preload("res://ui/theme/ui_tokens.gd")

var _cam: Camera3D
var _t := 0.0
var _backdrop: SubViewport


func _ready() -> void:
	theme = UIKit.THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_wordmark()
	var penguin := PenguinPreview.new(Vector2i(300, 340), Color("#2B4C8C"))
	add_child(UIKit.pin(penguin, Vector2(0, 1), Vector2(250, -185), Vector2(300, 340)))
	var play := UIKit.button("Play", "hero", "play", Vector2(420, 118))
	add_child(UIKit.pin(play, Vector2(0.5, 0.5), Vector2(50, 120), Vector2(420, 118)))
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file(WORLD_SCENE))
	var settings := UIKit.button("Settings", "secondary", "gear", Vector2(260, 72))
	settings.add_theme_font_size_override("font_size", 30)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBox = settings.get_theme_stylebox(st, "Button").duplicate() if UIKit.THEME.has_stylebox(st, "Button") else null
		if sb is StyleBoxFlat:
			(sb as StyleBoxFlat).set_corner_radius_all(36)
			settings.add_theme_stylebox_override(st, sb)
	add_child(UIKit.pin(settings, Vector2(0.5, 0.5), Vector2(50, 238), Vector2(260, 72)))
	settings.pressed.connect(func() -> void: UIRouter.push(SettingsScreen.new()))
	var quit := UIKit.button("Download desktop" if OS.has_feature("web") else "Quit", "quiet", "", Vector2(240, 50))
	quit.add_theme_font_size_override("font_size", 26)
	quit.add_theme_color_override("font_color", Color.WHITE)
	quit.add_theme_color_override("font_hover_color", T.NAVY)
	UIKit.pin(quit, Vector2(1, 1), Vector2(-155, -52), Vector2(240, 44))
	quit.pressed.connect(func() -> void:
		if OS.has_feature("web"):
			OS.shell_open("https://pengloo.party/download/")
		else:
			get_tree().quit()
	)
	add_child(quit)
	play.grab_focus()
	if OS.has_feature("web"):
		await get_tree().process_frame
		JavaScriptBridge.eval("window.penglooReady?.()")


func _build_backdrop() -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	UIKit.full(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_backdrop = SubViewport.new()
	_backdrop.size = Vector2i(1280, 720)
	_backdrop.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_backdrop)
	var env := WorldEnvironment.new()
	var e: Environment = (load("res://scenes/env/town_env_forward.tres") as Environment).duplicate(true)
	var sky := e.sky.sky_material as ProceduralSkyMaterial  # bright clear sky like the menu mockup
	if sky:
		sky.sky_top_color = Color("#5DA9E4")
		sky.sky_horizon_color = Color("#CFE7F4")
	e.fog_enabled = false
	env.environment = e
	_backdrop.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -38, 0)
	sun.light_color = Color("#FFE2B0")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	_backdrop.add_child(sun)
	if ResourceLoader.exists("res://scenes/locations/town.tscn"):
		_backdrop.add_child(load("res://scenes/locations/town.tscn").instantiate())
	_cam = Camera3D.new()
	_cam.fov = 40
	_backdrop.add_child(_cam)
	_place_cam.call_deferred()


func _place_cam() -> void:
	# slow orbit around the plaza, low and close like the mockup's village view
	if not _cam.is_inside_tree():
		return
	# slow drift past the cove docks and homes, low like the mockup's village view
	var a := deg_to_rad(212.0) + sin(_t * 0.05) * 0.18
	var focus := Vector3(-14, 0.5, 13)
	_cam.look_at_from_position(focus + Vector3(cos(a) * 17.0, 6.0, -sin(a) * 17.0), focus + Vector3(0, 2.4, -4), Vector3.UP)


func _process(delta: float) -> void:
	if UIRouter.settings.get("reduce_motion", false):
		return
	_t += delta
	_place_cam()


func _build_wordmark() -> void:
	var logo := TextureRect.new()
	logo.texture = preload("res://ui/branding/pengloo-party-logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UIKit.pin(logo, Vector2(0.5, 0), Vector2(0, 190), Vector2(780, 320)))


## Penguin head sitting in the counter of the first "O" of PENGLOO, like the mockup's W●RLD.
func _o_face(word: Label, box: Control) -> void:
	var f := word.get_theme_font("font")
	var fs := word.get_theme_font_size("font_size")
	var ow := f.get_string_size("O", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := f.get_string_size("PENG", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + ow * 0.8  # tuned against the render (kerning + outline)
	var asc := f.get_ascent(fs)
	var cap := f.get_string_size("O", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).y
	var head := TextureRect.new()
	head.texture = UIKit.icon("penguin_head")
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var d := ow * 0.62
	head.size = Vector2(d, d)
	head.position = word.position + Vector2(x0 + (ow - d) * 0.5, word.size.y * 0.5 - d * 0.5 + fs * 0.02)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.add_child(head)
	head.position -= word.position


class Sparks extends Control:
	## the coral "pop" marks beside the wordmark
	func _draw() -> void:
		var c := Color("#F5776C")
		draw_line(Vector2(0, 0), Vector2(26, -14), c, 9.0, true)
		draw_line(Vector2(6, 20), Vector2(34, 18), c, 9.0, true)
