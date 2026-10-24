class_name DecorEditor
extends Node3D
## Grid decoration for a home interior shell (Art Docs/Housing Placement Data.md):
## floor/rug items snap to the shell's 0.5 m `cells`, quarter turns rotate the footprint,
## `blocked_cells` keep the doorway clear, wall items snap to `wall_slots`.
## The UI (decor_ui.gd) drives it; it emits state changes for the overlay.
## shortcut: layout saved locally in user://home_<shell>.json, not on a server; validation is
## client-side only (the handoff requires server-side checks once homes are persisted online).

signal ghost_changed(valid: bool, reason: String)
signal selection_changed(item: Dictionary)
signal saved(ok: bool)
signal layout_changed

const GHOST_OK := Color(0.36, 0.82, 0.5, 0.55)
const GHOST_BAD := Color(0.96, 0.42, 0.36, 0.6)
const SEL := Color(1.0, 0.86, 0.45, 0.35)

var shell_id := ""
var room: Node3D                    ## the interior shell instance
var camera: Camera3D
var cell_m := 0.5
var floor_y := 0.0
var _origin := Vector2.ZERO        ## Blender XY of cell [0,0] corner (room local)
var _cells := {}                   ## Vector2i -> true
var _blocked := {}
var _wall_slots: Array = []        ## [{name, pos: Vector3 (room local, Godot), facing: Vector3}]
var items: Array = []              ## [{id, layer, cell: Vector2i, rot: int, slot: String, tints: {}, node: Node3D}]
var _ghost: Node3D
var _ghost_id := ""
var _ghost_rot := 0
var _ghost_cell := Vector2i(-99, -99)
var _ghost_slot := ""
var _ghost_valid := false
var _moving: Dictionary = {}       ## item being moved (restored on cancel)
var selected: Dictionary = {}
var _undo: Array = []
var _manifests := {}


func setup(p_room: Node3D, p_shell_id: String, p_camera: Camera3D) -> void:
	room = p_room
	shell_id = p_shell_id
	camera = p_camera
	var m := _entry(shell_id)
	cell_m = float(m.get("cell_m", 0.5))
	floor_y = float(m.get("floor_z", 0.0))
	var o: Array = m.get("cell_origin", [0, 0])
	_origin = Vector2(o[0], o[1])
	for c in _arr(m.get("cells", [])):
		_cells[Vector2i(c[0], c[1])] = true
	for c in _arr(m.get("blocked_cells", [])):
		_blocked[Vector2i(c[0], c[1])] = true
	var ws = m.get("wall_slots", {})
	if ws is String:
		ws = JSON.parse_string(str(ws).replace("'", "\""))
	if ws is Dictionary:
		for k in ws:
			var e: Dictionary = ws[k]
			var p: Array = e["pos"]
			var f: Array = e["facing"]
			_wall_slots.append({"name": k, "pos": Vector3(p[0], p[2], -p[1]), "facing": Vector3(f[0], 0, -f[1]).normalized()})


# ---------------------------------------------------------------- catalogue --
func _entry(id: String) -> Dictionary:
	var kit := id.get_slice("/", 0)
	if not _manifests.has(kit):
		var d := {}
		var f := FileAccess.open("res://Models/%s/manifest.json" % kit, FileAccess.READ)
		if f:
			for a in JSON.parse_string(f.get_as_text()):
				d[str(a["id"])] = a
		_manifests[kit] = d
	return _manifests[kit].get(id, {})


static func _arr(v) -> Array:
	if v is String:
		var parsed = JSON.parse_string(str(v))
		return parsed if parsed is Array else []
	return v if v is Array else []


func placement(id: String) -> Dictionary:
	var p = _entry(id).get("placement", {})
	return p if p is Dictionary else {}


# ---------------------------------------------------------------- grid math --
func cell_center(c: Vector2i) -> Vector3:
	var bx := _origin.x + (c.x + 0.5) * cell_m
	var by := _origin.y + (c.y + 0.5) * cell_m
	return Vector3(bx, floor_y, -by)


func footprint_cells(id: String, at: Vector2i, rot: int) -> Array[Vector2i]:
	var fp: Array = placement(id).get("footprint", [1, 1])
	var w := int(fp[0]) if fp.size() > 0 else 1
	var d := int(fp[1]) if fp.size() > 1 else 1
	if rot % 180 != 0:
		var t := w; w = d; d = t
	var out: Array[Vector2i] = []
	for i in w:
		for j in d:
			out.append(at + Vector2i(i - (w - 1) / 2, j - (d - 1) / 2))
	return out


func _item_center(id: String, at: Vector2i, rot: int) -> Vector3:
	var cs := footprint_cells(id, at, rot)
	var sum := Vector3.ZERO
	for c in cs:
		sum += cell_center(c)
	return sum / cs.size()


## Returns "" when the item fits, else the reason shown in the blocked bubble.
func check(id: String, at: Vector2i, rot: int, slot := "", ignore: Dictionary = {}) -> String:
	var layer := str(placement(id).get("layer", "floor"))
	if layer == "wall":
		if slot == "":
			return "Point at a wall to hang this"
		for it in items:
			if not _is_ignored(it, ignore) and it["slot"] == slot:
				return "That wall spot is taken"
		return ""
	if layer == "ceiling" or layer == "surface":
		return ""   # shortcut: ceiling anchors / tabletop slots not snapped yet; placed freely on the floor grid
	for c in footprint_cells(id, at, rot):
		if not _cells.has(c):
			return "That spot is outside the room"
		if _blocked.has(c) and layer != "rug":
			return "Keep the doorway clear"
	if layer != "rug":
		var mine := footprint_cells(id, at, rot)
		for it in items:
			if _is_ignored(it, ignore) or it["layer"] != "floor":
				continue
			for c in footprint_cells(it["id"], it["cell"], it["rot"]):
				if c in mine:
					return "Something is already there"
	return ""


func _is_ignored(it: Dictionary, ignore: Dictionary) -> bool:
	var node = ignore.get("node")
	return node != null and it.get("node") == node


func _nearest_valid(id: String, around: Vector2i, rot: int, slot: String, ignore: Dictionary) -> Vector2i:
	var best := Vector2i(-99, -99)
	var best_d := 1.0e9
	for c in _cells:
		if check(id, c, rot, slot, ignore) != "":
			continue
		var d := Vector2(c - around).length_squared()
		if d < best_d:
			best_d = d
			best = c
	return best


# ---------------------------------------------------------------- picking --
func _floor_hit(screen: Vector2) -> Variant:
	if camera == null or room == null:
		return null
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var plane_y := room.global_position.y + floor_y
	if absf(dir.y) < 0.001:
		return null
	var t := (plane_y - from.y) / dir.y
	return from + dir * t if t > 0 else null


func _to_cell(world: Vector3) -> Vector2i:
	var local := room.to_local(world)
	return Vector2i(floori((local.x - _origin.x) / cell_m), floori((-local.z - _origin.y) / cell_m))


func _nearest_slot(world: Vector3) -> String:
	var best := ""
	var bd := 1.6
	for s in _wall_slots:
		var d := room.to_global(s["pos"]).distance_to(world)
		if d < bd:
			bd = d; best = s["name"]
	return best


# ---------------------------------------------------------------- ghost --
func begin_place(id: String) -> void:
	cancel_ghost()
	_ghost_id = id
	_ghost_rot = 0
	_ghost = _spawn(id)
	if _ghost:
		room.add_child(_ghost)
		_tint_ghost(_ghost, GHOST_OK)
	_ghost_cell = Vector2i(-99, -99)


func begin_move(item: Dictionary) -> void:
	if item.is_empty() or item.get("node") == null:
		return
	cancel_ghost()
	_moving = item
	item["node"].visible = false
	_ghost_id = str(item["id"])
	_ghost_rot = int(item["rot"])
	_ghost = _spawn(_ghost_id)
	if _ghost:
		room.add_child(_ghost)
		_tint_ghost(_ghost, GHOST_OK)
	var cell: Vector2i = item["cell"]
	var slot := str(item.get("slot", ""))
	if check(_ghost_id, cell, _ghost_rot, slot, item) != "":
		var near := _nearest_valid(_ghost_id, cell, _ghost_rot, slot, item)
		if near != Vector2i(-99, -99):
			cell = near
	_update_ghost(cell, slot)


func rotate_ghost() -> void:
	if _ghost:
		_ghost_rot = (_ghost_rot + 90) % 360
		_update_ghost(_ghost_cell, _ghost_slot)
	elif not selected.is_empty():
		var it := selected
		var before := {"cell": it["cell"], "rot": it["rot"]}
		var nr := (int(it["rot"]) + 90) % 360
		if check(it["id"], it["cell"], nr, it["slot"], it) == "":
			it["rot"] = nr
			_pose(it)
			_undo.append({"op": "edit", "item": it, "before": before})
			layout_changed.emit()


func hover(screen: Vector2) -> void:
	if _ghost == null:
		return
	var hit = _floor_hit(screen)
	if hit == null:
		return
	var layer := str(placement(_ghost_id).get("layer", "floor"))
	_update_ghost(_to_cell(hit), _nearest_slot(hit) if layer == "wall" else "")


func _update_ghost(c: Vector2i, slot: String) -> void:
	_ghost_cell = c
	_ghost_slot = slot
	var reason := check(_ghost_id, c, _ghost_rot, slot, _moving)
	_ghost_valid = reason == ""
	_pose_node(_ghost, _ghost_id, c, _ghost_rot, slot)
	_tint_ghost(_ghost, GHOST_OK if _ghost_valid else GHOST_BAD)
	ghost_changed.emit(_ghost_valid, reason)


func ghost_screen_pos() -> Vector2:
	if _ghost == null or camera == null:
		return Vector2(-1000, -1000)
	return camera.unproject_position(_ghost.global_position + Vector3(0, 1.1, 0))


func has_ghost() -> bool:
	return _ghost != null


func place_ghost() -> bool:
	if _ghost == null or not _ghost_valid:
		return false
	var it: Dictionary
	if not _moving.is_empty():
		it = _moving
		_undo.append({"op": "edit", "item": it, "before": {"cell": it["cell"], "rot": it["rot"], "slot": it["slot"]}})
		it["cell"] = _ghost_cell; it["rot"] = _ghost_rot; it["slot"] = _ghost_slot
		it["node"].visible = true
		_pose(it)
		_moving = {}
	else:
		it = _add(_ghost_id, _ghost_cell, _ghost_rot, _ghost_slot, {})
		_undo.append({"op": "add", "item": it})
	cancel_ghost()
	select(it)
	layout_changed.emit()
	return true


func cancel_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if not _moving.is_empty():
		_moving["node"].visible = true   # cancelling a move restores the previous transform
		_moving = {}
	_ghost_id = ""


# ---------------------------------------------------------------- items --
func _spawn(id: String) -> Node3D:
	var p := "res://Models/%s.glb" % id
	if not ResourceLoader.exists(p):
		return null
	var n := (load(p) as PackedScene).instantiate() as Node3D
	Tints.prepare(n)
	return n


func _add(id: String, c: Vector2i, rot: int, slot: String, tints: Dictionary) -> Dictionary:
	var n := _spawn(id)
	if n == null:
		return {}
	room.add_child(n)
	var it := {"id": id, "layer": str(placement(id).get("layer", "floor")), "cell": c, "rot": rot, "slot": slot, "tints": tints, "node": n}
	items.append(it)
	if not tints.is_empty():
		Tints.apply(n, _colors(tints))
	_pose(it)
	return it


func _pose(it: Dictionary) -> void:
	_pose_node(it["node"], it["id"], it["cell"], it["rot"], it["slot"])


func _pose_node(n: Node3D, id: String, c: Vector2i, rot: int, slot: String) -> void:
	if n == null:
		return
	var layer := str(placement(id).get("layer", "floor"))
	if layer == "wall" and slot != "":
		for s in _wall_slots:
			if s["name"] == slot:
				n.position = s["pos"] + s["facing"] * 0.03
				n.rotation.y = atan2(s["facing"].x, s["facing"].z)
		return
	n.position = _item_center(id, c, rot) + Vector3(0, 0.004 if layer == "rug" else 0.0, 0)
	n.rotation.y = deg_to_rad(rot)


func item_at(screen: Vector2) -> Dictionary:
	var picked := _item_under_ray(screen)
	if not picked.is_empty():
		return picked
	var hit = _floor_hit(screen)
	if hit == null:
		return {}
	var c := _to_cell(hit)
	var best: Dictionary = {}
	for it in items:   # floor items win over rugs under them
		if c in footprint_cells(it["id"], it["cell"], it["rot"]) and (best.is_empty() or best["layer"] == "rug"):
			best = it
	if best.is_empty():
		for it in items:
			if it["layer"] == "wall" and is_instance_valid(it.get("node")) and room.to_global(it["node"].position).distance_to(hit) < 1.2:
				best = it
	return best


func _item_under_ray(screen: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best: Dictionary = {}
	var best_d := 1.0e9
	for it in items:
		var n: Node3D = it.get("node")
		if n == null or not is_instance_valid(n) or not n.visible:
			continue
		var point = _world_aabb(n).intersects_ray(from, dir)
		if point == null:
			continue
		var d := from.distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = it
	return best


func _world_aabb(n: Node3D) -> AABB:
	var box := AABB()
	var started := false
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		if not started:
			box = b
			started = true
		else:
			box = box.merge(b)
	if not started:
		box = AABB(n.global_position - Vector3(0.3, 0.0, 0.3), Vector3(0.6, 1.0, 0.6))
	return box.grow(0.08)


func select(it: Dictionary) -> void:
	if not selected.is_empty() and is_instance_valid(selected.get("node")):
		_highlight(selected["node"], false)
	selected = it
	if not it.is_empty():
		_highlight(it["node"], true)
	selection_changed.emit(it)


func selected_screen_pos() -> Vector2:
	if selected.is_empty() or camera == null:
		return Vector2(-1000, -1000)
	return camera.unproject_position(selected["node"].global_position + Vector3(0, 1.4, 0))


## Remove returns the item to inventory (not permanent deletion); undoable.
func remove_selected() -> void:
	if selected.is_empty():
		return
	var it := selected
	select({})
	items.erase(it)
	it["node"].visible = false
	_undo.append({"op": "remove", "item": it})
	layout_changed.emit()


func recolor_selected(color: Color) -> void:
	if selected.is_empty():
		return
	var roles := Tints.roles(selected["node"])
	if roles.is_empty():
		return
	var before: Dictionary = selected["tints"].duplicate()
	selected["tints"][roles[0]] = color.to_html(false)
	Tints.apply(selected["node"], _colors(selected["tints"]))
	_undo.append({"op": "tint", "item": selected, "before": before})
	layout_changed.emit()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var u: Dictionary = _undo.pop_back()
	var it: Dictionary = u["item"]
	match u["op"]:
		"add":
			if selected == it:
				select({})
			items.erase(it)
			it["node"].queue_free()
		"remove":
			items.append(it)
			it["node"].visible = true
		"edit":
			for k in u["before"]:
				it[k] = u["before"][k]
			_pose(it)
		"tint":
			it["tints"] = u["before"]
			Tints.apply(it["node"], _colors(it["tints"]))
	layout_changed.emit()
	return true


func can_undo() -> bool:
	return not _undo.is_empty()


static func _colors(tints: Dictionary) -> Dictionary:
	var out := {}
	for k in tints:
		out[k] = Color(str(tints[k]))
	return out


# ---------------------------------------------------------------- visuals --
func _meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)


func _tint_ghost(n: Node3D, c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b) * 0.35
	for mi in _meshes(n):
		(mi as MeshInstance3D).material_overlay = null
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _highlight(n: Node3D, on: bool) -> void:
	var m: StandardMaterial3D = null
	if on:
		m = StandardMaterial3D.new()
		m.albedo_color = SEL
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.grow = true
		m.grow_amount = 0.015
	for mi in _meshes(n):
		(mi as MeshInstance3D).material_overlay = m


# ---------------------------------------------------------------- grid overlay --
## Faint square grid drawn on the valid cells while editing (blocked cells tinted coral).
func make_grid() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var y := floor_y + 0.012
	var h := cell_m * 0.5
	for c in _cells:
		var p := cell_center(c)
		var col := Color(0.96, 0.45, 0.4, 0.75) if _blocked.has(c) else Color(1, 1, 1, 0.45)
		var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
		for i in 4:
			im.surface_set_color(col)
			im.surface_add_vertex(p + corners[i] + Vector3(0, y - p.y, 0))
			im.surface_set_color(col)
			im.surface_add_vertex(p + corners[(i + 1) % 4] + Vector3(0, y - p.y, 0))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- persistence --
func save_path() -> String:
	return path_for(shell_id)


static func path_for(shell: String) -> String:
	return "user://home_%s.json" % shell.get_slice("/", 1)


func save_layout() -> void:
	var out := []
	for it in items:
		out.append({"id": it["id"], "cell": [it["cell"].x, it["cell"].y], "rot": it["rot"], "slot": it["slot"], "tints": it["tints"]})
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	var ok := f != null
	if ok:
		f.store_string(JSON.stringify({"shell": shell_id, "items": out}, " "))
		f.close()
	saved.emit(ok)


## remote: another player's layout (a visit). It comes off the network, so every entry is checked
## against the catalogue before anything loads.
func load_layout(default_items: Array = [], remote: Variant = null) -> void:
	var data = remote
	if remote == null and FileAccess.file_exists(save_path()):
		data = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	var list: Array = data["items"] if data is Dictionary and data.get("items") is Array else default_items
	for e in list.slice(0, 300):
		if not (e is Dictionary) or not (e.get("cell") is Array) or e["cell"].size() != 2 or _entry(str(e.get("id", ""))).is_empty():
			continue
		var c: Array = e["cell"]
		var tints = e.get("tints", {})
		_add(str(e["id"]), Vector2i(int(c[0]), int(c[1])), int(e.get("rot", 0)), str(e.get("slot", "")), tints if tints is Dictionary else {})
	_undo.clear()


func clear_items() -> void:
	for it in items:
		if is_instance_valid(it["node"]):
			it["node"].queue_free()
	items.clear()
	selected = {}
