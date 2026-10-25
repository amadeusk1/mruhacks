extends Node

## The town's real court. The ball, the hoops and the score stay where they were built.
## Walking onto the paint is how you join. Nothing sends you to another place.

const CORAL := Color(0.91, 0.4, 0.32)
const TEAL := Color(0.2, 0.68, 0.72)
const _Match := preload("res://scripts/court_match.gd")
const HINT := "Walk into the ball.  Click shoots.  F passes."
const AIM_DOTS := 18
const AIM_GOOD := Color(0.4, 0.95, 0.5)
const AIM_OK := Color(1.0, 0.85, 0.3)
const AIM_OFF := Color(1.0, 0.5, 0.3)

var _rim_coral := Vector3.ZERO
var _rim_teal := Vector3.ZERO
var _aim: Node3D
var _aim_dots: MultiMeshInstance3D
var _aim_head: MeshInstance3D
var _aim_mat: StandardMaterial3D
var _ball: Node3D
var _hoops: Array[Node3D] = []
var _nets: Array[Node3D] = []
var _score: Label3D
var _status: Label
var _line: Label
var _hint: Label
var _hud: Control
var _center := Vector3.ZERO
var _swish := 0.0
var _shown_points := -1


func _ready() -> void:
	add_to_group("town_court")
	var halves := _here("town_court_half")
	_hoops = _here("town_hoop")
	if halves.is_empty() or _hoops.is_empty():
		return
	_hoops.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	var bounds := _bounds(halves)
	_center = bounds.position + bounds.size * 0.5
	var west := _rim(_hoops[0])
	var east := _rim(_hoops[_hoops.size() - 1])
	Net.court_configure(east, west, bounds)
	_rim_coral = east
	_rim_teal = west
	_build_aim()
	for hoop in _hoops:
		var net := _find(hoop, "part_net")
		if net != null:
			_nets.append(net)
	_ball = AssetPack.spawn("activities", "basketball")
	if _ball != null:
		_ball.name = "GameBall"
		add_child(_ball)
		_ball.global_position = Vector3(_center.x, 0.2, _center.z)
	_board()
	_hud_layer()


func _physics_process(_delta: float) -> void:
	if _hoops.is_empty():
		return
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player != null:
		_witness(player, Net.local_id())
	for node in get_tree().get_nodes_in_group("remote_player"):
		var body := node as Node3D
		if body != null:
			_witness(body, int(body.get_meta("remote_peer", 0)))


func _process(delta: float) -> void:
	if _hoops.is_empty():
		return
	var state: Dictionary = Net.court_view()
	_place_ball(state, delta)
	_paint(state)
	_update_aim(state, delta)
	_swish = maxf(0.0, _swish - delta)
	for net in _nets:
		if is_instance_valid(net):
			net.rotation.x = sin(_swish * 24.0) * _swish * 0.5
	var points := int(state.get("coral", 0)) + int(state.get("teal", 0))
	if points > _shown_points and _shown_points >= 0:
		_swish = 0.45
	_shown_points = points


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var step := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 0.05
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -0.05
	if step != 0.0 and _carrying_here() != null:
		Net.court_loft = clampf(Net.court_loft + step, 0.0, 1.0)
		get_viewport().set_input_as_handled()


## The local player while they hold the ball on the court, else null.
func _carrying_here() -> Node3D:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null or not Net.court_carrying() or not Net.court_here(player.global_position):
		return null
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return null
	return player


## The hoop a shot would go to: the same choice court_match makes on the host.
func _attack_rim(state: Dictionary, player: Node3D) -> Vector3:
	var side := _my_side(str(state.get("teams", "")))
	if str(state.get("phase", "")) == "live":
		if side == "teal":
			return _rim_teal
		if side == "coral":
			return _rim_coral
	var flat := Vector2(player.global_position.x, player.global_position.z)
	var to_teal := flat.distance_to(Vector2(_rim_teal.x, _rim_teal.z))
	var to_coral := flat.distance_to(Vector2(_rim_coral.x, _rim_coral.z))
	return _rim_teal if to_teal < to_coral else _rim_coral


func _build_aim() -> void:
	_aim = Node3D.new()
	_aim.name = "ShotAim"
	_aim.visible = false
	add_child(_aim)
	_aim_mat = StandardMaterial3D.new()
	_aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_mat.no_depth_test = true  # the arc stays readable behind the backboard and other penguins
	_aim_mat.render_priority = 10
	var dot := SphereMesh.new()
	dot.radius = 0.075
	dot.height = 0.15
	dot.radial_segments = 8
	dot.rings = 4
	dot.material = _aim_mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = dot
	multi.instance_count = AIM_DOTS
	_aim_dots = MultiMeshInstance3D.new()
	_aim_dots.multimesh = multi
	_aim_dots.top_level = true
	_aim.add_child(_aim_dots)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.24
	cone.height = 0.55
	cone.radial_segments = 12
	cone.material = _aim_mat
	_aim_head = MeshInstance3D.new()
	_aim_head.mesh = cone
	_aim_head.top_level = true
	_aim.add_child(_aim_head)


## Dotted arc from the ball to the hoop, ending in an arrowhead. Q/E (or the wheel) raise and
## lower it; green means the arc suits the distance, orange means it is too flat or too high.
func _update_aim(state: Dictionary, delta: float) -> void:
	var player := _carrying_here()
	if player == null or _aim == null:
		if _aim != null:
			_aim.visible = false
		if _hint != null:
			_hint.text = HINT
		return
	var lift := 0.0
	if InputMap.has_action("aim_up") and Input.is_action_pressed("aim_up"):
		lift += 1.0
	if InputMap.has_action("aim_down") and Input.is_action_pressed("aim_down"):
		lift -= 1.0
	if lift != 0.0:
		Net.court_loft = clampf(Net.court_loft + lift * delta * 0.7, 0.0, 1.0)
	var loft := Net.court_loft
	var rim := _attack_rim(state, player)
	var from := _carry(player)
	var dist := Vector2(from.x - rim.x, from.z - rim.z).length()
	var pts := _Match.arc_points(from, rim, loft, AIM_DOTS + 1)
	var fit := _Match.loft_fit(dist, loft)
	_aim_mat.albedo_color = AIM_GOOD if fit >= _Match.FIT_GOOD else (AIM_OK if fit >= _Match.FIT_OK else AIM_OFF)
	var multi := _aim_dots.multimesh
	for i in AIM_DOTS:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i + 1]))  # the first point is inside the ball
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	_aim_head.global_transform = Transform3D(Basis(side, dir, side.cross(dir)), tip - dir * 0.27)
	_aim.visible = true
	if _hint != null:
		var verdict := "green: this one goes in" if fit >= _Match.FIT_GOOD else ("too flat" if loft < _Match.ideal_loft(dist) else "too high")
		_hint.text = "Click shoots.  Wheel or %s / %s sets the arc: %s." % [ControlsScreen.key_text("aim_down"), ControlsScreen.key_text("aim_up"), verdict]


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


func _place_ball(state: Dictionary, delta: float) -> void:
	if _ball == null:
		return
	var target := Vector3(float(state.get("bx", _center.x)), float(state.get("by", 0.2)), float(state.get("bz", _center.z)))
	if target.distance_to(_center) > 40.0:
		target = Vector3(_center.x, 0.2, _center.z)
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
	var on_court := false
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player != null:
		on_court = Net.court_here(player.global_position)
	if _hud != null:
		_hud.visible = on_court
	if _score != null:
		if phase == "practice":
			_score.text = str(coral) if coral > 0 else "Open"
		else:
			_score.text = "%d  -  %d" % [coral, teal]
	if not on_court:
		return
	if _line != null:
		if phase == "practice":
			_line.text = "Shoot around" if coral == 0 else "You %d" % coral
		elif bool(state.get("overtime", false)) and phase == "live":
			_line.text = "Next basket     Coral %d     Teal %d" % [coral, teal]
		else:
			_line.text = "Coral %d     %d:%02d     Teal %d" % [coral, minute, second, teal]
	if _status != null:
		var note := str(state.get("text", ""))
		var mine := _my_side(str(state.get("teams", "")))
		if mine == "coral" or mine == "teal":
			note = "%s   You are %s" % [note, "Coral" if mine == "coral" else "Teal"]
		elif mine == "bench":
			note = "%s   Next game" % note
		_status.text = note.strip_edges()


func _my_side(packed: String) -> String:
	var mine := str(Net.local_id())
	for piece in packed.split(",", false):
		var bits := piece.split(":")
		if bits.size() == 2 and bits[0] == mine:
			return bits[1]
	return ""


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


func _here(group_name: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var town := get_parent()
	for node in get_tree().get_nodes_in_group(group_name):
		var body := node as Node3D
		if body != null and town != null and town.is_ancestor_of(body):
			found.append(body)
	return found


func _rim(hoop: Node3D) -> Vector3:
	var socket := _find(hoop, "socket_target")
	if socket != null:
		return socket.global_position
	return hoop.global_transform * Vector3(0.0, 1.67, 0.72)


func _bounds(halves: Array[Node3D]) -> AABB:
	var box := AABB()
	var first := true
	for court in halves:
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
		box = AABB(_center + Vector3(-8.0, 0.0, -4.0), Vector3(16.0, 0.2, 8.0))
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


func _board() -> void:
	var boards := _here("town_scoreboard")
	_score = Label3D.new()
	_score.name = "ScoreReadout"
	_score.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_score.font_size = 72
	_score.pixel_size = 0.006
	_score.outline_size = 10
	_score.modulate = Color(0.97, 0.98, 1.0)
	_score.outline_modulate = Color(0.1, 0.16, 0.24)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.text = "Open"
	var font := load("res://fonts/Fredoka-Bold.ttf") as Font
	if font != null:
		_score.font = font
	if boards.is_empty():
		add_child(_score)
		_score.position = Vector3(_center.x, 2.2, _center.z)
	else:
		boards[0].add_child(_score)
		_score.position = Vector3(0.0, 1.55, 0.0)


func _hud_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CourtHud"
	layer.layer = 2
	add_child(layer)
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -240.0
	root.offset_right = 240.0
	root.offset_top = 18.0
	root.offset_bottom = 110.0
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(root)
	_hud = root
	var font := load("res://fonts/Fredoka-Bold.ttf") as Font
	_line = _label(font, 22)
	_status = _label(font, 18)
	_hint = _label(font, 15)
	_hint.text = HINT
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
