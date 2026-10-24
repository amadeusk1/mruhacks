class_name PenguinPreview
extends SubViewportContainer
## Live rigged penguin in its own little 3D scene: AssetPack bird + idle (or any clip), soft key light,
## transparent background. Used by penguin setup, player cards and (other builder) the wardrobe.
## Also provides cached head portraits for lists via PenguinPreview.portrait(color).

var viewport: SubViewport
var bird: Node3D
var player: AnimationPlayer
var _pivot: Node3D
var _camera: Camera3D
var spin := 0.0          # radians/s of slow turntable spin (0 = still)
var headshot := false    # frame only the head (portraits)


func _init(size_px := Vector2i(420, 420), body := Color("#2B4C8C"), framed_head := false) -> void:
	headshot = framed_head
	stretch = true
	custom_minimum_size = Vector2(size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = size_px
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#FFF4E6")
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	env.environment = e
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 0.85
	key.light_color = Color("#FFF1DC")
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.5
	viewport.add_child(rim)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 28 if not headshot else 30
	viewport.add_child(_camera)
	if headshot:
		_camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0, -0.06, -1.9), Vector3.UP).translated(Vector3(0, 0.56, 1.9))
	else:
		_camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0, -0.18, -2.55), Vector3.UP).translated(Vector3(0, 0.62, 2.55))
	bird = AssetPack.spawn("anim_locomotion", "avatar_base")
	if bird != null:
		_pivot.add_child(bird)
		bird.rotation.y = deg_to_rad(-18)
		player = bird.find_child("AnimationPlayer", true, false) as AnimationPlayer
		set_body(body)
		play("idle")


func set_body(color: Color) -> void:
	if bird != null:
		Tints.apply(bird, {"body": color})


func play(clip: String) -> void:
	if player == null:
		return
	for c in [clip, clip + "_loop"]:
		if player.has_animation(c):
			player.get_animation(c).loop_mode = Animation.LOOP_LINEAR
			player.play(c)
			return


func _process(delta: float) -> void:
	if spin != 0.0:
		_pivot.rotate_y(spin * delta)


# ---- cached portraits -----------------------------------------------------------
static var _portraits := {}


## A head-and-shoulders render of a penguin in this body colour (rendered once, then reused).
static func portrait(color: Color) -> Texture2D:
	var key := color.to_html(false)
	if _portraits.has(key):
		return _portraits[key]
	var p := PenguinPreview.new(Vector2i(160, 160), color, true)
	p.visible = true
	p.position = Vector2(-10000, -10000)  # offscreen; still renders
	UIRouter.add_child(p)
	p.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tex := p.viewport.get_texture()
	_portraits[key] = tex
	# freeze after a few frames so lists cost nothing
	p.get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(p): p.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return tex
