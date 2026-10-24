extends StaticBody3D

## A slot cabinet, color roulette wheel, or poker table.
## Walk up and press F. The panel on screen is the game.

const APPROACH := 1.7

@export var kind := "slot"

var _prompt: Label3D
var _hud: Node
var _closing := false
var _wheel: MeshInstance3D
var _gem: MeshInstance3D
var _reels: Array[MeshInstance3D] = []
var _banner: Label3D
var _spinning := false
var _spin_from := 0.0
var _spin_to := 0.0
var _spin_time := 0.0


func _ready() -> void:
	add_to_group("casino_table")
	collision_layer = 2
	collision_mask = 0
	_build_body()
	_prompt = Label3D.new()
	_prompt.font_size = 42
	_prompt.outline_size = 8
	_prompt.pixel_size = 0.005
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.98, 0.98, 1)
	_prompt.outline_modulate = Color(0.08, 0.16, 0.24)
	_prompt.visible = false
	_prompt.top_level = true
	add_child(_prompt)
	_prompt.global_position = approach_point() + Vector3(0.0, 1.35, 0.0)


func approach_point() -> Vector3:
	return global_position + Vector3(0.0, 0.0, APPROACH)


func stand_point() -> Vector3:
	var at := approach_point()
	return Vector3(at.x, 0.2, at.z)


func bench_key() -> String:
	var location := ""
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("current_location_id"):
		location = str(world.call("current_location_id"))
	return "%s:%s" % [location, name]


func try_play(force := false) -> bool:
	var player := get_tree().get_first_node_in_group("local_player")
	if player == null or not player.has_method("plant_table"):
		return false
	if player.has_method("is_at_table") and bool(player.call("is_at_table")) and player.call("current_bench") == self:
		return true
	var stand := approach_point()
	var flat := Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z)
	if not force and flat.length() > 1.35:
		return false
	if force and flat.length() > 2.4:
		return false
	if not Net.claim_bench(bench_key()):
		return false
	if not bool(player.call("plant_table", self, stand_point(), 0.0)):
		Net.release_bench()
		return false
	return true


func can_interact() -> bool:
	return _prompt.visible and _prompt.text != "Taken"


func open_play(_player: Node) -> void:
	if _hud != null:
		return
	var path := "res://scripts/slot_hud.gd"
	if kind == "roulette":
		path = "res://scripts/roulette_hud.gd"
	elif kind == "poker":
		path = "res://scripts/poker_hud.gd"
	_hud = load(path).new()
	add_child(_hud)
	_hud.call("open", self)


func close_play() -> void:
	if _closing:
		return
	_closing = true
	if _hud != null and is_instance_valid(_hud):
		if _hud.has_method("finish"):
			_hud.call("finish")
		_hud.queue_free()
		_hud = null
	_closing = false


func coins() -> int:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("coin_balance"):
		return int(world.call("coin_balance"))
	return 0


func take_coins(amount: int) -> bool:
	if amount <= 0 or coins() < amount:
		return false
	var world := get_tree().get_first_node_in_group("world")
	world.call("grant_coins", -amount)
	return true


func give_coins(amount: int) -> void:
	if amount <= 0:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("grant_coins"):
		world.call("grant_coins", amount)


func show_reels(symbols: PackedStringArray) -> void:
	for i in mini(symbols.size(), _reels.size()):
		_paint(_reels[i], _symbol_color(symbols[i]))
	if _banner != null:
		_banner.text = "  ".join(symbols)


func spin_wheel() -> void:
	if _wheel == null:
		return
	_spin_from = _wheel.rotation.y
	_spin_to = _spin_from + TAU * 4.0 + randf() * TAU
	_spin_time = 0.0
	_spinning = true


func show_color(color_name: String) -> void:
	_paint(_gem, _bet_color(color_name))
	if _banner != null:
		_banner.text = color_name.capitalize()


func _process(delta: float) -> void:
	if _spinning and _wheel != null:
		_spin_time += delta
		var t := clampf(_spin_time / 2.0, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - t, 3.0)
		_wheel.rotation.y = lerpf(_spin_from, _spin_to, ease)
		if t >= 1.0:
			_spinning = false
	_refresh_prompt()


func _refresh_prompt() -> void:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		_prompt.visible = false
		return
	var here := false
	if player.has_method("is_at_table") and bool(player.call("is_at_table")):
		here = player.call("current_bench") == self
	var stand := approach_point()
	var flat := Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z)
	var taken := Net.bench_held_by_other(bench_key())
	if kind == "roulette":
		_prompt.text = "Taken" if taken else "F to spin"
	elif kind == "poker":
		_prompt.text = "Taken" if taken else "F to deal"
	else:
		_prompt.text = "Taken" if taken else "F to pull"
	_prompt.visible = not here and flat.length() < 2.3


func _build_body() -> void:
	_banner = Label3D.new()
	_banner.font_size = 48
	_banner.pixel_size = 0.004
	_banner.outline_size = 8
	_banner.modulate = Color(0.98, 0.95, 0.88)
	_banner.outline_modulate = Color(0.08, 0.14, 0.22)
	_banner.position = Vector3(0.0, 1.7, 0.0)
	_banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_banner)
	if kind == "roulette":
		_build_wheel()
	elif kind == "poker":
		_build_felt(Vector3(2.5, 0.82, 1.45), Color(0.1, 0.38, 0.3))
		_banner.text = "Poker"
	else:
		_build_slot()


func _build_slot() -> void:
	_add_box(Vector3(1.15, 1.45, 0.7), Vector3(0.0, 0.72, 0.0), Color(0.16, 0.24, 0.34), true)
	for i in 3:
		var reel := _add_box(Vector3(0.28, 0.42, 0.06), Vector3(-0.34 + float(i) * 0.34, 0.95, 0.34), Color(0.95, 0.93, 0.86), false)
		_reels.append(reel)
	_banner.text = "Slots"
	_banner.position.y = 1.85


func _build_wheel() -> void:
	_add_box(Vector3(2.05, 0.82, 1.35), Vector3(0.0, 0.41, 0.0), Color(0.2, 0.28, 0.24), true)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.35, 1.35)
	mesh.orientation = PlaneMesh.FACE_Y
	plane.mesh = mesh
	plane.position = Vector3(0.0, 0.86, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _wheel_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material_override = mat
	add_child(plane)
	_wheel = plane
	var pointer := _add_box(Vector3(0.08, 0.08, 0.22), Vector3(0.0, 0.92, 0.78), Color(0.98, 0.95, 0.88), false)
	pointer.rotation.x = 0.0
	_gem = _add_box(Vector3(0.28, 0.28, 0.28), Vector3(0.0, 1.15, -0.85), Color(0.12, 0.45, 0.32), false)
	_banner.text = "Roulette"
	_banner.position.y = 1.7


func _build_felt(size: Vector3, color: Color) -> void:
	_add_box(size, Vector3(0.0, size.y * 0.5, 0.0), color, true)


func _add_box(size: Vector3, at: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.position = at
	_paint(mesh_node, color)
	add_child(mesh_node)
	if solid:
		var shape := CollisionShape3D.new()
		var body := BoxShape3D.new()
		body.size = size
		shape.shape = body
		shape.position = at
		add_child(shape)
	return mesh_node


func _paint(mesh_node: MeshInstance3D, color: Color) -> void:
	if mesh_node == null:
		return
	var mat := mesh_node.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.roughness = 0.72
		mesh_node.material_override = mat
	mat.albedo_color = color


func _wheel_texture() -> ImageTexture:
	var n := 220
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(n * 0.5, n * 0.5)
	var outer := n * 0.48
	var inner := n * 0.18
	var pockets := float(CasinoRules.ROULETTE_POCKETS)
	for y in n:
		for x in n:
			var delta := Vector2(float(x) + 0.5, float(y) + 0.5) - center
			var dist := delta.length()
			if dist > outer or dist < inner:
				continue
			var turn := (atan2(delta.y, delta.x) + PI) / TAU
			var pocket := posmod(int(floor(turn * pockets)), int(pockets))
			img.set_pixel(x, y, _bet_color(CasinoRules.roulette_color(pocket)))
	return ImageTexture.create_from_image(img)


func _symbol_color(symbol: String) -> Color:
	match symbol:
		"penguin":
			return Color(0.2, 0.45, 0.82)
		"coin":
			return Color(0.95, 0.78, 0.28)
		"fish":
			return Color(0.94, 0.5, 0.18)
		"igloo":
			return Color(0.93, 0.95, 0.98)
		_:
			return Color(0.18, 0.62, 0.64)


func _bet_color(color_name: String) -> Color:
	match color_name:
		"red":
			return Color(0.78, 0.16, 0.18)
		"black":
			return Color(0.1, 0.12, 0.16)
		_:
			return Color(0.12, 0.55, 0.36)
