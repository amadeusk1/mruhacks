class_name PenguinView
extends Control
## Live rigged penguin rendered in its own SubViewport: the wardrobe preview and the
## player portraits (lobbies, results, friend cards). Wears real avatar GLBs by slot.
## Usage: var v := PenguinView.new(); v.framing = "portrait"; add_child(v); v.set_look(color, outfit)

const SOCKET := {"head": "head", "face": "face", "neck": "neck", "back": "back", "hand": "hand_R"}

@export var framing := "full"            ## "full" body or "portrait" (head and shoulders)
@export var turntable := false           ## slow idle sway; drag to spin
@export var portrait_bg := Color(0, 0, 0, 0)

var _viewport: SubViewport
var _bird: Node3D
var _cam: Camera3D
var _player: AnimationPlayer
var _pieces: Array[Node] = []
var _yaw := 0.0
var _drag := false
var _body := Color("#3D7BD9")
var _outfit: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(holder)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = portrait_bg.a == 0.0
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR if portrait_bg.a == 0.0 else Environment.BG_COLOR
	e.background_color = portrait_bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.9)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 28, 0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.95, 0.86)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.8, 0.9, 1.0)
	_viewport.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 24.0
	_viewport.add_child(_cam)
	_bird = AssetPack.spawn("anim_locomotion", "avatar_base")
	if _bird:
		_viewport.add_child(_bird)
		_player = _bird.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _player and _player.has_animation("idle"):
			_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			_player.play("idle")
	_frame()
	set_look(_body, _outfit)


func _frame() -> void:
	if _cam == null:
		return
	if framing == "portrait":
		_cam.position = Vector3(0, 0.82, 2.6)
		_cam.look_at(Vector3(0, 0.66, 0))
		_cam.fov = 21.0
	else:
		_cam.position = Vector3(0, 1.05, 6.2)
		_cam.look_at(Vector3(0, 0.72, 0))
		_cam.fov = 21.0


## body: coat colour. outfit: {"head": "red_beanie", "torso": "hoodie", "face": "", "neck": "", "back": "", "hand": "mug"}
func set_look(body: Color, outfit: Dictionary) -> void:
	_body = body
	_outfit = outfit.duplicate()
	if _bird == null:
		return
	Tints.apply(_bird, {"body": body})
	for p in _pieces:
		if is_instance_valid(p):
			p.get_parent().remove_child(p)
			p.queue_free()
	_pieces.clear()
	var skeleton := _bird.find_child("Skeleton3D", true, false) as Skeleton3D
	for slot in outfit:
		var asset := str(outfit[slot])
		if asset == "":
			continue
		if slot == "torso":
			var before: Array = skeleton.get_children() if skeleton else []
			AssetPack._wear_cloth(_bird, asset, Color(1, 1, 1, 0))
			if skeleton:
				for c in skeleton.get_children():
					if not before.has(c):
						_pieces.append(c)
		elif SOCKET.has(slot):
			var sock := Sockets.find(_bird, SOCKET[slot])
			if sock == null:
				continue
			var before2 := sock.get_children()
			AssetPack._wear_item(_bird, asset, SOCKET[slot], Color(1, 1, 1, 0))
			for c in sock.get_children():
				if not before2.has(c):
					_pieces.append(c)


func play(anim: String) -> void:
	if _player and _player.has_animation(anim):
		_player.play(anim)


func _process(delta: float) -> void:
	if _bird == null:
		return
	if turntable and not _drag and not UIRouter.settings.get("reduce_motion", false):
		_yaw = lerp_angle(_yaw, sin(Time.get_ticks_msec() * 0.0006) * 0.35, 1.0 - exp(-2.0 * delta))
	_bird.rotation.y = _yaw


func _gui_input(event: InputEvent) -> void:
	if not turntable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		_yaw += event.relative.x * 0.01
