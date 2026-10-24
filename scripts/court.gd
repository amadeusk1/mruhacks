extends Node3D

## The Court. A bus stop with one hoop and one shared ball.
## The host deals teams. This node builds the place and shows the match.

const CORAL := Color(0.91, 0.4, 0.32)
const TEAL := Color(0.2, 0.68, 0.72)
const BUS := preload("res://scenes/bus_stop.tscn")

var _ball: Node3D
var _hoop_net: Node3D
var _score: Label3D
var _status: Label
var _line: Label
var _hint: Label
var _swish := 0.0
var _shown_points := -1
var _marked: Array[Node] = []


func _ready() -> void:
	add_to_group("basket_court")
	_build()
	var state: Dictionary = Net.court_view()
	_shown_points = int(state.get("coral", 0)) + int(state.get("teal", 0))


func _exit_tree() -> void:
	for body in _marked:
		if not is_instance_valid(body):
			continue
		if body.has_meta("court_layer_prev"):
			body.collision_layer = int(body.get_meta("court_layer_prev"))
		if body.has_meta("court_mask_prev"):
			body.collision_mask = int(body.get_meta("court_mask_prev"))
		var ring := body.get_node_or_null("TeamRing")
		if ring:
			ring.visible = false
		var scarf := body.get_node_or_null("TeamScarf")
		if scarf:
			scarf.visible = false


func camera_for_spawn(_spawn: String) -> Dictionary:
	return {
		"center": Vector3(0.0, 0.0, 1.2),
		"limit_x": 10.0,
		"limit_z": 10.0,
		"height": 9.0,
		"distance": 7.5,
	}


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player != null:
		_witness(player, Net.local_id())
		_arm(player)
	for node in get_tree().get_nodes_in_group("remote_player"):
		var body := node as Node3D
		if body == null:
			continue
		_witness(body, int(body.get_meta("remote_peer", 0)))
		_arm(body)


func _process(delta: float) -> void:
	var state: Dictionary = Net.court_view()
	_place_ball(state, delta)
	_paint(state)
	_swish = maxf(0.0, _swish - delta)
	if _hoop_net != null:
		_hoop_net.rotation.x = sin(_swish * 24.0) * _swish * 0.5
	var points := int(state.get("coral", 0)) + int(state.get("teal", 0))
	if points > _shown_points and str(state.get("phase", "")) == "live":
		_swish = 0.45
	_shown_points = points


func _witness(body: Node3D, id: int) -> void:
	if id <= 0:
		return
	var speed := 0.0
	if body.has_method("court_speed"):
		speed = float(body.call("court_speed"))
	elif body is CharacterBody3D:
		var velocity := (body as CharacterBody3D).velocity
		speed = Vector2(velocity.x, velocity.z).length()
	Net.court_witness(id, body.global_position, body.rotation.y, speed)


func _arm(body: Node) -> void:
	if body in _marked:
		return
	_marked.append(body)
	if not body.has_meta("court_mask_prev"):
		body.set_meta("court_mask_prev", body.collision_mask)
	if int(body.get_meta("remote_peer", 0)) != 0 and not body.has_meta("court_layer_prev"):
		body.set_meta("court_layer_prev", body.collision_layer)
		body.collision_layer = 4
	body.collision_mask = int(body.get_meta("court_mask_prev")) | 4


func _place_ball(state: Dictionary, delta: float) -> void:
	if _ball == null:
		return
	var target := Vector3(float(state.get("bx", 0.0)), float(state.get("by", 0.2)), float(state.get("bz", 0.0)))
	if str(state.get("mode", "")) == "held":
		var holder := _body(int(state.get("poss", 0)))
		if holder != null:
			target = _carry(holder)
	if _ball.global_position.distance_to(target) > 2.4:
		_ball.global_position = target
	else:
		var blend := 1.0 - exp(-16.0 * delta)
		_ball.global_position = _ball.global_position.lerp(target, blend)


func _paint(state: Dictionary) -> void:
	var phase := str(state.get("phase", "practice"))
	var coral := int(state.get("coral", 0))
	var teal := int(state.get("teal", 0))
	var clock := maxf(0.0, float(state.get("clock", 0.0)))
	var minute := int(clock) / 60
	var second := int(clock) % 60
	var alone := bool(state.get("solo", false))
	if _score != null:
		if alone:
			_score.text = str(coral)
		elif phase == "practice":
			_score.text = "Open"
		else:
			_score.text = "%d  -  %d" % [coral, teal]
	if _line != null:
		if alone:
			_line.text = "You %d     %d:%02d" % [coral, minute, second]
		elif phase == "practice":
			_line.text = "Shoot around"
		elif bool(state.get("overtime", false)) and phase == "live":
			_line.text = "Next basket     Coral %d     Teal %d" % [coral, teal]
		else:
			_line.text = "Coral %d     %d:%02d     Teal %d" % [coral, minute, second, teal]
	if _status != null:
		var note := str(state.get("text", ""))
		var mine := _my_side(str(state.get("teams", "")))
		if alone:
			pass
		elif mine == "coral" or mine == "teal":
			note = "%s   You are %s" % [note, "Coral" if mine == "coral" else "Teal"]
		elif mine == "bench":
			note = "%s   Next game" % note
		_status.text = note.strip_edges()
	_mark_teams("" if alone else str(state.get("teams", "")))


func _my_side(packed: String) -> String:
	var mine := str(Net.local_id())
	for piece in packed.split(",", false):
		var bits := piece.split(":")
		if bits.size() == 2 and bits[0] == mine:
			return bits[1]
	return ""


func _mark_teams(packed: String) -> void:
	var sides := {}
	for piece in packed.split(",", false):
		var bits := piece.split(":")
		if bits.size() == 2:
			sides[int(bits[0])] = bits[1]
	for body in _marked:
		if not is_instance_valid(body):
			continue
		var id := Net.local_id()
		if int(body.get_meta("remote_peer", 0)) != 0:
			id = int(body.get_meta("remote_peer"))
		_dress(body, str(sides.get(id, "")))


func _dress(body: Node, side: String) -> void:
	var show := side == "coral" or side == "teal"
	var color := CORAL if side == "coral" else TEAL
	var ring := body.get_node_or_null("TeamRing") as MeshInstance3D
	var scarf := body.get_node_or_null("TeamScarf") as MeshInstance3D
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = "TeamRing"
		var disc := CylinderMesh.new()
		disc.top_radius = 0.42
		disc.bottom_radius = 0.42
		disc.height = 0.035
		ring.mesh = disc
		ring.position = Vector3(0.0, 0.03, 0.0)
		body.add_child(ring)
	if scarf == null:
		scarf = MeshInstance3D.new()
		scarf.name = "TeamScarf"
		var band := TorusMesh.new()
		band.inner_radius = 0.15
		band.outer_radius = 0.23
		band.rings = 8
		band.ring_segments = 8
		scarf.mesh = band
		scarf.position = Vector3(0.0, 0.58, 0.0)
		body.add_child(scarf)
	ring.visible = show
	scarf.visible = show
	if not show:
		return
	_tint_mesh(ring, color)
	_tint_mesh(scarf, color)


func _tint_mesh(mesh: MeshInstance3D, color: Color) -> void:
	var mat := mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.roughness = 0.7
		mesh.material_override = mat
	mat.albedo_color = color


func _body(id: int) -> Node3D:
	if id == Net.local_id():
		return get_tree().get_first_node_in_group("local_player") as Node3D
	for node in get_tree().get_nodes_in_group("remote_player"):
		if int(node.get_meta("remote_peer", 0)) == id:
			return node as Node3D
	return null


func _carry(body: Node3D) -> Vector3:
	var forward := Vector3(-sin(body.rotation.y), 0.0, -cos(body.rotation.y))
	return body.global_position + forward * 0.34 + Vector3(0.0, 0.48, 0.0)


func _build() -> void:
	_snow()
	_walls()
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	add_child(region)
	var nav := NavigationMesh.new()
	nav.vertices = PackedVector3Array([
		Vector3(-7.0, 0.0, -5.0),
		Vector3(7.0, 0.0, -5.0),
		Vector3(7.0, 0.0, 9.0),
		Vector3(-7.0, 0.0, 9.0),
	])
	nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = nav
	var stop := BUS.instantiate()
	stop.name = "BusStop"
	region.add_child(stop)
	stop.position = Vector3(0.0, 0.0, 7.3)
	var arrival := Marker3D.new()
	arrival.name = "BusArrival"
	arrival.position = Vector3(0.0, 0.0, 6.15)
	add_child(arrival)

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var court := AssetPack.place(props, "activities", "basketball_court_half", Vector3.ZERO)
	var hoop: Node3D = null
	if court != null:
		var socket := _find(court, "socket_hoop")
		hoop = AssetPack.spawn("activities", "basketball_hoop")
		if hoop != null:
			props.add_child(hoop)
			if socket != null:
				hoop.global_position = socket.global_position
			_hoop_net = _find(hoop, "part_net")
		var board_at := _find(court, "socket_scoreboard")
		var board := AssetPack.place(props, "activities", "scoreboard", Vector3(4.9, 0.0, -1.6), PI / 2.0)
		if board != null and board_at != null:
			board.global_position = board_at.global_position
		AssetPack.place(props, "activities", "ball_rack", Vector3(-5.15, 0.0, 1.2), PI / 2.0)
		_fence(props)
		_trees(props)
		var target := _find(hoop, "socket_target") if hoop != null else null
		var hoop_at := target.global_position if target != null else Vector3(0.0, 1.7, -3.05)
		Net.court_configure(hoop_at, hoop_at, _bounds(court))
	_ball = AssetPack.spawn("activities", "basketball")
	if _ball != null:
		_ball.name = "Ball"
		add_child(_ball)
		_ball.position = Vector3(0.0, 0.2, 0.2)
	_score = Label3D.new()
	_score.name = "ScoreReadout"
	_score.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_score.font_size = 72
	_score.pixel_size = 0.006
	_score.outline_size = 10
	_score.position = Vector3(4.2, 1.7, -1.6)
	_score.modulate = Color(0.97, 0.98, 1.0)
	_score.outline_modulate = Color(0.1, 0.16, 0.24)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.text = "Open"
	var font := load("res://fonts/Fredoka-Bold.ttf") as Font
	if font != null:
		_score.font = font
	add_child(_score)
	_hud(font)


func _snow() -> void:
	var body := StaticBody3D.new()
	body.name = "Snow"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(28.0, 1.0, 28.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 1.0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(28.0, 0.2, 28.0)
	mesh.mesh = slab
	mesh.position = Vector3(0.0, -0.1, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.95, 0.98)
	mat.roughness = 0.96
	mesh.material_override = mat
	body.add_child(mesh)


func _walls() -> void:
	_wall(Vector3(-5.5, 0.5, -0.4), Vector3(0.35, 1.0, 8.2))
	_wall(Vector3(5.5, 0.5, -0.4), Vector3(0.35, 1.0, 8.2))
	_wall(Vector3(0.0, 0.5, -4.55), Vector3(11.2, 1.0, 0.35))
	_wall(Vector3(0.0, 0.5, 9.2), Vector3(12.0, 1.0, 0.35))


func _wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _fence(props: Node3D) -> void:
	for z in [-2.2, -0.2, 1.8]:
		AssetPack.place(props, "activities", "low_boundary_fence", Vector3(-4.85, 0.0, z), PI / 2.0)
		AssetPack.place(props, "activities", "low_boundary_fence", Vector3(4.85, 0.0, z), -PI / 2.0)
	for x in [-3.0, -1.0, 1.0, 3.0]:
		AssetPack.place(props, "activities", "low_boundary_fence", Vector3(x, 0.0, -4.15))


func _trees(props: Node3D) -> void:
	AssetPack.place(props, "nature_dock", "small_tree_snow", Vector3(-8.5, 0.0, -5.5))
	AssetPack.place(props, "nature_dock", "small_tree_snow", Vector3(8.5, 0.0, -5.5))
	AssetPack.place(props, "nature_dock", "broad_tree_snow", Vector3(-8.2, 0.0, 6.5))
	AssetPack.place(props, "nature_dock", "broad_tree_snow", Vector3(8.2, 0.0, 6.5))


func _bounds(court: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in court.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var part: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		if first:
			box = part
			first = false
		else:
			box = box.merge(part)
	if first:
		box = AABB(Vector3(-4.35, 0.0, -3.85), Vector3(8.7, 0.1, 7.7))
	return box


func _find(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if node.name == wanted or str(node.name).begins_with(wanted + "."):
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _hud(font: Font) -> void:
	var layer := CanvasLayer.new()
	layer.name = "CourtHud"
	layer.layer = 2
	add_child(layer)
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -220.0
	root.offset_right = 220.0
	root.offset_top = 18.0
	root.offset_bottom = 96.0
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(root)
	_line = _label(font, 22)
	_status = _label(font, 18)
	_hint = _label(font, 15)
	_hint.text = "Click shoots.  F passes.  F on a dribbler steals."
	_hint.modulate = Color(1, 1, 1, 0.82)
	root.add_child(_line)
	root.add_child(_status)
	root.add_child(_hint)


func _label(font: Font, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.24))
	label.add_theme_constant_override("outline_size", 6)
	if font != null:
		label.add_theme_font_override("font", font)
	return label
