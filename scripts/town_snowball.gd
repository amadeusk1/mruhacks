extends Node

## The town's snowball arena (winter/snowball_arena_blockout). Reads the arena's sockets, hands the
## field, pads, spawns and cover to Net (the host runs scripts/snow_match.gd), then draws what the
## host publishes: flying snowballs, hit puffs, team rings and badges, the scoreboard and the HUD.
## Rules and numbers: vault note "Art Docs/Snowball Fight.md".

const _Match := preload("res://scripts/snow_match.gd")
const _Ui := preload("res://ui/activities/winter/winter_ui.gd")
const CORAL := Color("#E86D58")
const TEAL := Color("#207D85")
const FIELD := Vector2(12.0, 8.0)  # manifest field_m: brief X along +x, brief Z along -z
# manifest cover_colliders_cx_cy_sx_sy_h: the two spawn walls and the two centre banks
const BLOCKOUT_COVER := [[2.5, 4.0, 0.6, 3.0, 0.7], [9.5, 4.0, 0.6, 3.0, 0.7], [5.0, 5.0, 1.2, 0.9, 0.6], [7.0, 3.0, 1.2, 0.9, 0.6]]
# cover placed on the field by the town layout: footprint x, depth, height
const PLACED_COVER := {"winter/snow_bank_cover": Vector3(1.3, 0.8, 0.9), "winter/snow_wall_straight": Vector3(2.0, 0.6, 0.7)}
const BLOCK_LAYER := 2

var _arena: Node3D
var _field := Rect2()
var _floor := 0.0
var _pads := {}
var _spawns := {"coral": [], "teal": []}
var _balls := {}  # ball id -> [Node3D, launch p, launch v, age]
var _seen := -1  # last event n applied; -1 until the first view (old events are not replayed)
var _life := 0
var _down := false
var _markers := {}  # body instance id -> [ring, badge, team]
var _hud: Control
var _status: Label
var _pad_labels := {}
var _score_a: Label3D
var _score_b: Label3D
var _hud_sig := ""
var _hide_result := false
var _lobby_ui: Control
var _lobby_sig := ""


func _ready() -> void:
	_arena = _first("winter/snowball_arena_blockout")
	if _arena == null:
		return
	add_to_group("snow_arena")
	var corners: Array[Vector3] = [_arena.global_transform * Vector3.ZERO, _arena.global_transform * Vector3(FIELD.x, 0, -FIELD.y)]
	_field = Rect2(Vector2(minf(corners[0].x, corners[1].x), minf(corners[0].z, corners[1].z)),
		Vector2(absf(corners[1].x - corners[0].x), absf(corners[1].z - corners[0].z)))
	_floor = _arena.global_position.y + 0.05
	var sockets := Sockets.all(_arena)
	for team in _Match.TEAMS:
		for i in 2:
			var s: Node3D = sockets.get("spawn_%s_%d" % [team, i])
			if s != null:
				_spawns[team].append(s.global_position)
	_find_pads(sockets)
	var cover := _cover()
	Net.snow_configure(_field, _floor, _pads, _spawns, cover)
	_dress()
	_hud_layer()


func _process(delta: float) -> void:
	if _arena == null:
		return
	var state := Net.snow_view()
	_apply_events(state)
	_fly(delta)
	_mark_teams(state)
	_track_self(state)
	_paint(state)
	_refresh_lobby(state)


## Penguin left click while in a match: throw at the cursor's spot on the snow instead of walking.
func try_throw(player: Node3D, event: InputEvent) -> bool:
	var state := Net.snow_view()
	if str(state.get("phase", "")) != "live" or Net.snow_team() == "" or not _field.grow(0.3).has_point(Vector2(player.global_position.x, player.global_position.z)):
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return true
	var mouse := (event as InputEventMouse).position if event is InputEventMouse else get_viewport().get_mouse_position()
	var target: Variant = Plane(Vector3.UP, _floor).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if target == null:
		return true
	var mine: Array = (state.get("lives", {}) as Dictionary).get(Net.local_id(), [])
	if mine.size() < 2 or float(mine[0]) > 0.0 or float(mine[1]) > 0.0:
		return true  # cooling down or down: the click is still eaten so the penguin does not wander off
	if player.has_method("face_point"):
		player.call("face_point", target)
	if player.has_method("play_activity"):
		player.call("play_activity", "snow_throw")
	Net.snow_throw(target)
	return true


## ActivityScreens hands us the "Snowballs" lobby card opened at the ArenaGate.
func wire_lobby(card: Control) -> void:
	_lobby_ui = card
	_lobby_sig = ""
	card.connect("intent", _lobby_intent.bind(card))
	_refresh_lobby(Net.snow_view())


func _lobby_intent(action: String, _value: Variant, card: Control) -> void:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null or not is_instance_valid(card):
		return
	if action == "ready":
		var ready: Dictionary = Net.snow_view().get("ready", {})
		var team := "teal" if (ready.get("teal", []) as Array).size() < (ready.get("coral", []) as Array).size() else "coral"
		if _pads.has(team):
			player.call("command_walk_to", Vector3(_pads[team].x, _floor, _pads[team].y))
		card.queue_free()
	elif action == "spectate":
		var bench := Sockets.find(_arena, "spectator_1")
		if bench != null:
			player.call("command_walk_to", bench.global_position)
		card.queue_free()


func _refresh_lobby(state: Dictionary) -> void:
	if not is_instance_valid(_lobby_ui):
		return
	var ready: Dictionary = state.get("ready", {})
	var coral: Array = ready.get("coral", [])
	var teal: Array = ready.get("teal", [])
	var live := str(state.get("phase", "")) == "live"
	if live:  # show who is playing; the queue waits for the next match
		coral = []
		teal = []
		var teams: Dictionary = state.get("teams", {})
		for id in teams:
			(coral if teams[id] == "coral" else teal).append(id)
	var lobby := {"mode": "lobby", "coral": coral.map(_name_of), "teal": teal.map(_name_of),
		"waiting": coral.is_empty() or teal.is_empty() or live}
	var sig := str(lobby)
	if sig != _lobby_sig:
		_lobby_sig = sig
		_lobby_ui.call("apply_state", lobby)


func _name_of(id: Variant) -> String:
	if int(id) == Net.local_id():
		return "You"
	for entry in Net.roster():
		if int(entry.get("id", 0)) == int(id):
			return str(entry.get("name", "Penguin"))
	return "Penguin"


# ---- arena setup ----------------------------------------------------------------------
func _find_pads(sockets: Dictionary) -> void:
	# the painted ready spots by the gate: one pad per team between its two ready sockets
	for team in _Match.TEAMS:
		var a: Node3D = sockets.get("ready_%s_0" % team)
		var b: Node3D = sockets.get("ready_%s_1" % team)
		if a != null and b != null:
			_pads[team] = _flat((a.global_position + b.global_position) * 0.5)


func _cover() -> Array:
	var boxes: Array = []
	# one body per wall/bank (a merged body reads as one big box to tools/walk_test), parented to the
	# town's NavigationRegion3D so its rebake carves them out of the click-to-walk navmesh
	var nav: Node = get_parent().get_node_or_null("NavigationRegion3D") if get_parent() else null
	for i in BLOCKOUT_COVER.size():
		var c: Array = BLOCKOUT_COVER[i]
		var center: Vector3 = _arena.global_transform * Vector3(c[0], c[4] * 0.5, -c[1])
		var size := Vector3(c[2], c[4], c[3])
		boxes.append(AABB(center - size * 0.5, size))
		var body := StaticBody3D.new()  # players can't walk through the blockout's walls either
		body.name = "ArenaCover%d" % i
		body.collision_layer = BLOCK_LAYER
		body.collision_mask = 0
		body.set_meta("blocker_of", "winter/snowball_arena_blockout cover")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, size.y + 0.6, size.z)
		shape.shape = box
		body.add_child(shape)
		(nav if nav != null else self).add_child(body)
		body.global_position = center + Vector3(0, 0.3, 0)
	for id in PLACED_COVER:
		for node in _placed(id):
			var at := node.global_position
			if not _field.has_point(_flat(at)):
				continue
			var dims: Vector3 = PLACED_COVER[id]
			var turned := absf(sin(node.global_rotation.y)) > 0.7
			var size := Vector3(dims.y if turned else dims.x, dims.z, dims.x if turned else dims.y)
			boxes.append(AABB(Vector3(at.x - size.x * 0.5, at.y, at.z - size.z * 0.5), size))
	return boxes


func _dress() -> void:
	for team in _Match.TEAMS:
		var list: Array = _spawns[team]
		if not list.is_empty():
			var pad := AssetPack.spawn("interaction_props", "respawn_pad")
			if pad != null:
				add_child(pad)
				pad.global_position = (list[0] + list[list.size() - 1]) * 0.5 + Vector3(0, -0.04, 0)
				Tints.apply(pad, {"team": _color(team), "team_glow": _color(team).lightened(0.15)})
		if _pads.has(team):
			var label := Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 48
			label.pixel_size = 0.006
			label.outline_size = 10
			label.modulate = _color(team).lightened(0.35)
			label.outline_modulate = Color(0.08, 0.14, 0.22)
			label.font = load("res://fonts/Fredoka-Bold.ttf") as Font
			add_child(label)
			label.global_position = Vector3(_pads[team].x, _floor + 1.6, _pads[team].y)
			_pad_labels[team] = label
	var boards := _placed("interaction_props/match_scoreboard")
	if not boards.is_empty():
		_score_a = _digit(boards[0], "score_a", CORAL)
		_score_b = _digit(boards[0], "score_b", TEAL)


func _digit(board: Node3D, socket: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font_size = 96
	label.pixel_size = 0.004
	label.outline_size = 8
	label.modulate = color.lightened(0.5)
	label.outline_modulate = Color(0.06, 0.1, 0.16)
	label.font = load("res://fonts/Fredoka-Bold.ttf") as Font
	label.text = "0"
	var at := Sockets.find(board, socket)
	(at if at != null else board).add_child(label)
	label.position = Vector3(0, 0, 0.03) if at != null else Vector3(0, 1.6, 0.1)
	return label


func _hud_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SnowHud"
	layer.layer = 2
	add_child(layer)
	_hud = _Ui.new()  # not on the UIRouter stack: the world keeps its input during a match
	_hud.visible = false
	layer.add_child(_hud)
	_hud.connect("intent", func(action: String, _v = null) -> void:
		if action == "leave" and str(Net.snow_view().get("phase", "")) == "live":
			Net.snow_leave()
		_hide_result = true)
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.offset_left = -320.0
	_status.offset_right = 320.0
	_status.offset_top = 128.0
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	_status.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.24))
	_status.add_theme_constant_override("outline_size", 6)
	var font := load("res://fonts/Fredoka-Bold.ttf") as Font
	if font != null:
		_status.add_theme_font_override("font", font)
	layer.add_child(_status)


# ---- per frame --------------------------------------------------------------------------
func _apply_events(state: Dictionary) -> void:
	var events: Array = state.get("events", [])
	if _seen < 0:
		_seen = int(events[-1]["n"]) if not events.is_empty() else 0
		return
	for e in events:
		var n := int(e["n"])
		if n <= _seen:
			continue
		_seen = n
		match str(e["k"]):
			"throw":
				_launch(e)
			"hit":
				_drop_ball(int(e["ball"]))
				_burst(e["at"], true)
				var who := _body(int(e["who"]))
				if who != null and who.has_method("play_activity"):
					who.call("play_activity", "snow_hit")
			"pop":
				_drop_ball(int(e["ball"]))
				_burst(e["at"], false)


func _launch(e: Dictionary) -> void:
	var ball := AssetPack.spawn("winter", "snowball")
	if ball == null:
		ball = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.18
		(ball as MeshInstance3D).mesh = mesh
	add_child(ball)
	ball.global_position = e["p"]
	_balls[int(e["ball"])] = [ball, e["p"], e["v"], 0.0]
	var by := int(e["by"])
	if by != Net.local_id():
		var thrower := _body(by)
		if thrower != null:
			thrower.call("face_point", Vector3(thrower.global_position.x + (e["v"] as Vector3).x, 0, thrower.global_position.z + (e["v"] as Vector3).z))
			thrower.call("play_activity", "snow_throw")


func _fly(delta: float) -> void:
	for id in _balls.keys():
		var b: Array = _balls[id]
		b[3] = float(b[3]) + delta
		if float(b[3]) > _Match.FLIGHT + 0.5:
			_drop_ball(int(id))
			continue
		(b[0] as Node3D).global_position = _Match.arc(b[1], b[2], float(b[3]))


func _drop_ball(id: int) -> void:
	if _balls.has(id):
		(_balls[id][0] as Node).queue_free()
		_balls.erase(id)


## Puff at an impact: snow_burst plus scattered clumps on a hit, a small puff otherwise.
func _burst(at: Vector3, big: bool) -> void:
	var parts := [["fx", "snow_burst", Vector3.ZERO]] if big else [["fx", "snow_puff_small", Vector3.ZERO]]
	if big:
		for i in 5:
			var a := TAU * i / 5.0
			parts.append(["fx", "snow_clump_a" if i % 2 == 0 else "snow_clump_b", Vector3(cos(a), 0.6, sin(a)) * 0.45])
	for p in parts:
		var node := AssetPack.spawn(p[0], p[1])
		if node == null:
			continue
		add_child(node)
		node.global_position = at
		node.scale = Vector3.ONE * (2.2 if big else 1.6)
		var tween := node.create_tween().set_parallel()
		tween.tween_property(node, "global_position", at + p[2], 0.45).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", Vector3.ONE * 0.2, 0.6).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(node.queue_free)


## Coral/teal foot ring and badge on everyone in the match (body colour stays the player's own).
func _mark_teams(state: Dictionary) -> void:
	var teams: Dictionary = state.get("teams", {}) if str(state.get("phase", "")) in ["live", "result"] else {}
	var keep := {}
	for id in teams:
		var body := _body(int(id))
		if body == null:
			continue
		var key := body.get_instance_id()
		keep[key] = true
		var have: Array = _markers.get(key, [])
		if not have.is_empty() and have[2] == teams[id] and is_instance_valid(have[0]):
			continue
		_unmark(key)
		var ring := AssetPack.spawn("interaction_props", "team_foot_ring")
		var badge := AssetPack.spawn("interaction_props", "team_badge")
		var color := _color(str(teams[id]))
		for node in [ring, badge]:
			if node != null:
				Tints.apply(node, {"team": color, "team_glow": color.lightened(0.15)})
				body.add_child(node)
		if ring != null:
			ring.position = Vector3(0, 0.03, 0)
		if badge != null:
			var neck := Sockets.find(body, "neck")
			if neck != null:
				badge.reparent(neck, false)
			else:
				badge.position = Vector3(0, 0.68, -0.24)
		_markers[key] = [ring, badge, teams[id]]
	for key in _markers.keys():
		if not keep.has(key):
			_unmark(key)


func _unmark(key: int) -> void:
	for node in _markers.get(key, []):
		if node is Node and is_instance_valid(node):
			(node as Node).queue_free()
	_markers.erase(key)


## The local player's own life: lock input while down, warp to the team spawn on each new life.
func _track_self(state: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		return
	var mine: Array = (state.get("lives", {}) as Dictionary).get(Net.local_id(), [])
	var team := Net.snow_team()
	var down := mine.size() >= 6 and float(mine[1]) > 0.0 and str(state.get("phase", "")) == "live"
	if down != _down:
		_down = down
		player.call("set_travel_locked", down)
		if down:
			player.call("play_activity", "snow_hit")
	if mine.size() < 6 or team == "":
		_life = 0
		return
	if int(mine[3]) != _life:
		_life = int(mine[3])
		var list: Array = _spawns.get(team, [])
		if not list.is_empty():
			var at: Vector3 = list[int(mine[5]) % list.size()]
			player.call("halt")
			player.global_position = at + Vector3.UP * 0.05
			player.call("face_point", Vector3(_field.get_center().x, at.y, _field.get_center().y))
			player.call("play_activity", "snow_respawn" if _life > 1 else "snow_ready")


func _paint(state: Dictionary) -> void:
	var phase := str(state.get("phase", "lobby"))
	var ready: Dictionary = state.get("ready", {})
	var size := int(state.get("size", 2))
	for team in _pad_labels:
		var queued := (ready.get(team, []) as Array).size()
		(_pad_labels[team] as Label3D).text = "%s  %d/%d" % [team.capitalize(), mini(queued, size), size] if queued <= size else "%s  %d/%d +%d" % [team.capitalize(), size, size, queued - size]
	if _score_a != null:
		_score_a.text = str(int(state.get("coral", 0)))
		_score_b.text = str(int(state.get("teal", 0)))
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	var here := player != null and Net.snow_here(player.global_position)
	var team := Net.snow_team()
	var view := {}
	if here and phase == "live" and team != "":
		var mine: Array = (state.get("lives", {}) as Dictionary).get(Net.local_id(), [0.0, 0.0, false, 0, 0, 0])
		view = {"mode": "snowball", "coral": int(state.get("coral", 0)), "teal": int(state.get("teal", 0)),
			"time_left": ceilf(maxf(0.0, float(state.get("clock", 0.0)))), "ready_in": snappedf(float(mine[0]), 0.1),
			"respawn_in": ceilf(float(mine[1]))}
	elif here and phase == "result" and team != "" and not _hide_result:
		var rows: Array = []
		for r in state.get("rows", []):
			rows.append({"name": _name_of(r["id"]), "score": int(r["score"]), "team": str(r["team"])})
		view = {"mode": "result", "rows": rows, "footnote": str(state.get("text", ""))}
	if phase != "result":
		_hide_result = false
	_hud.visible = not view.is_empty()
	var sig := str(view)
	if _hud.visible and sig != _hud_sig:
		_hud_sig = sig
		_hud.call("apply_state", view)
	if not here or view.get("mode", "") == "result":
		_status.text = ""
		return
	var note := str(state.get("text", ""))
	if team != "" and phase == "live":
		var mine: Array = (state.get("lives", {}) as Dictionary).get(Net.local_id(), [])
		note = "You are %s.  Click to throw." % team.capitalize()
		if mine.size() >= 6 and bool(mine[2]) and float(mine[1]) <= 0.0:
			note += "  Protected until you throw."
	elif phase == "live":
		note = "Match on: %d - %d.  Stand on a pad for the next one." % [int(state.get("coral", 0)), int(state.get("teal", 0))]
	_status.text = note


# ---- helpers ----------------------------------------------------------------------------
func _body(id: int) -> Node3D:
	if id == Net.local_id():
		return get_tree().get_first_node_in_group("local_player") as Node3D
	for node in get_tree().get_nodes_in_group("remote_player"):
		if int(node.get_meta("remote_peer", 0)) == id:
			return node as Node3D
	return null


func _placed(asset_id: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var town := get_parent()
	if town == null:
		return found
	for node in town.find_children("*", "Node3D", true, false):
		if str(node.get_meta("asset_id", "")) == asset_id:
			found.append(node as Node3D)
	return found


func _first(asset_id: String) -> Node3D:
	var list := _placed(asset_id)
	return list[0] if not list.is_empty() else null


func _color(team: String) -> Color:
	return CORAL if team == "coral" else TEAL


static func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)
