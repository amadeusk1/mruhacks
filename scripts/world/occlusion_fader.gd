extends Node

## Keeps the local penguin visible: anything big between the camera and the player dithers to
## see-through (alpha hash: crisp stipple, no sorting) and roofs hide while the player is inside a
## footprint. Only big occluders count: over MIN_HEIGHT tall and MIN_WIDTH across (benches, lamps,
## signs, fences and planters never do). The thin teal outline is a fallback for an occluder the
## see-through circle cannot open (no plain material to dither), shown only after SIL_ON s hidden
## and faded in and out, so it never flickers on paths.
## Child of CameraRig in world.tscn. Works on any room under World/LocationHost.

const FADE_TO := 0.0     # fade value is 1 - hole strength (0 = full see-through hole)
const MIN_HEIGHT := 1.2  # benches, planters and fences never count
const MIN_WIDTH := 1.0   # lamps, signposts and poles are tall but thin: they never count either
const SIL_ON := 0.25     # hidden this long before the outline appears
const SIL_OFF := 0.15    # visible this long before it goes
const SIL_FADE := 0.2    # outline fade in / out
const HOLE := preload("res://scripts/world/foliage_batch.gdshader")
const FADE_IN := 0.15   # seconds to reach FADE_TO
const FADE_OUT := 0.3   # seconds to come back
const RADIUS := 0.25    # occluder AABBs are inflated by this (a cheap capsule sweep)
const SKIP_NAMES := ["Terrain", "terrain_", "town_terrain", "water", "Shadow", "ClickMarker"]
const ROOF_TAGS := ["_roof", "_cutaway"]
const SILHOUETTE := preload("res://scripts/world/occluded_silhouette.gdshader")

var _camera: Camera3D
var _room: Node
var _roots: Array = []        # [{node, aabb, meshes, roofs}]
var _fading := {}             # root instance id -> {entry, alpha, target, saved: [[mi, surface, original, dup]]}
var _roofs_hidden := {}       # roof node -> true
var _silhouette: ShaderMaterial
var _player: Node3D
var _sil_hidden := 0.0   # seconds the outline has been needed
var _sil_clear := 0.0    # seconds it has not
var _sil_on := false
var _sil_alpha := 0.0


func _ready() -> void:
	_camera = get_parent().get_node("Camera3D")
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = SILHOUETTE


func _physics_process(delta: float) -> void:
	_player = get_tree().get_first_node_in_group("local_player") as Node3D
	var host := get_tree().get_first_node_in_group("world")
	var room: Node = null
	if host and host.has_node("LocationHost") and host.get_node("LocationHost").get_child_count() > 0:
		room = host.get_node("LocationHost").get_child(0)
	if room != _room:
		_reset()
		_room = room
		if room:
			_collect(room)
	if _player == null or not _player.visible or _room == null:
		_sil_on = false
		_sil_alpha = 0.0
		_set_silhouette(false)
		RenderingServer.global_shader_parameter_set("occlusion_radius", 0.0)
		return
	var target := _player.global_position + Vector3(0, 0.45, 0)
	RenderingServer.global_shader_parameter_set("occlusion_target", target)  # batched foliage hole
	RenderingServer.global_shader_parameter_set("occlusion_radius", 0.11)
	var from := _camera.global_position
	var to := target - (target - from).normalized() * 0.35
	var support := _support_root()
	var hits := {}
	for e in _roots:
		if e["node"] == support or not is_instance_valid(e["node"]):
			continue
		var box: AABB = e["aabb"]
		if not e["roofs"].is_empty() and _inside_footprint(box, _player.global_position):
			for r in e["roofs"]:
				if r.visible:
					r.visible = false
					_roofs_hidden[r] = true
			continue
		if box.has_point(_player.global_position + Vector3.UP * 0.3):
			continue  # the room/shell the player is inside: never fade it (its roof is handled above)
		if box.size.y < MIN_HEIGHT or maxf(box.size.x, box.size.z) < MIN_WIDTH:
			continue
		if _covers_player(box, target):
			hits[e["node"].get_instance_id()] = e
	for r in _roofs_hidden.keys():  # roofs come back when the player leaves the footprint
		if not is_instance_valid(r):
			_roofs_hidden.erase(r)
			continue
		var owner_box: AABB = _owner_box(r)
		if not _inside_footprint(owner_box, _player.global_position):
			r.visible = true
			_roofs_hidden.erase(r)
	_animate(hits, delta)
	# the see-through circle handles any occluder it could dither; the outline is for the rest
	var needed := hits.keys().any(func(id): return _fading.has(id) and (_fading[id]["saved"] as Array).is_empty())
	_sil_hidden = _sil_hidden + delta if needed else 0.0
	_sil_clear = 0.0 if needed else _sil_clear + delta
	if not _sil_on and _sil_hidden >= SIL_ON:
		_sil_on = true
	elif _sil_on and _sil_clear >= SIL_OFF:
		_sil_on = false
	_sil_alpha = move_toward(_sil_alpha, 1.0 if _sil_on else 0.0, delta / SIL_FADE)
	_silhouette.set_shader_parameter("strength", _sil_alpha)
	_set_silhouette(_sil_alpha > 0.0)


func _animate(hits: Dictionary, delta: float) -> void:
	var instant := _reduced_motion()
	for id in hits:
		if not _fading.has(id):
			_fading[id] = {"entry": hits[id], "alpha": 1.0, "saved": _make_dithered(hits[id])}
		_fading[id]["target"] = FADE_TO
	for id in _fading.keys():
		var f: Dictionary = _fading[id]
		if not hits.has(id):
			f["target"] = 1.0
		var rate := (1.0 - FADE_TO) / (FADE_IN if f["target"] < f["alpha"] else FADE_OUT)
		f["alpha"] = f["target"] if instant else move_toward(f["alpha"], f["target"], rate * delta)
		for s in f["saved"]:
			if is_instance_valid(s[3]):
				s[3].set_shader_parameter("hole_strength", 1.0 - f["alpha"])
		if f["alpha"] >= 1.0 and f["target"] >= 1.0:
			_restore(f)
			_fading.erase(id)


## Dithered copies of each surface's *current* material (keeps Tints.prepare overrides).
func _make_dithered(e: Dictionary) -> Array:
	var saved := []
	for mi in e["meshes"]:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var original: Material = mi.get_surface_override_material(s)
			var src: Material = original if original else mi.mesh.surface_get_material(s)
			if not (src is BaseMaterial3D):
				continue
			var b := src as BaseMaterial3D
			if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var dup := ShaderMaterial.new()  # same flat colour + shade, soft hole around the penguin
			dup.shader = HOLE
			dup.set_shader_parameter("albedo", b.albedo_color)
			dup.set_shader_parameter("use_vertex_shade", b.vertex_color_use_as_albedo)
			dup.set_shader_parameter("roughness", b.roughness)
			dup.set_shader_parameter("use_emission", b.emission_enabled)
			dup.set_shader_parameter("emission_color", b.emission)
			dup.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
			dup.set_shader_parameter("hole_strength", 0.0)
			mi.set_surface_override_material(s, dup)
			saved.append([mi, s, original, dup])
	return saved


func _restore(f: Dictionary) -> void:
	for s in f["saved"]:
		if is_instance_valid(s[0]):
			s[0].set_surface_override_material(s[1], s[2])


func _reset() -> void:
	for id in _fading:
		_restore(_fading[id])
	_fading.clear()
	for r in _roofs_hidden:
		if is_instance_valid(r):
			r.visible = true
	_roofs_hidden.clear()
	_roots.clear()


## Placement roots: each instanced GLB (scene_file_path set) or loose mesh, with a world AABB.
func _collect(room: Node) -> void:
	var stack: Array = [room]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if _skipped(n) or n is MultiMeshInstance3D:  # batched small props: one AABB spans the map
			continue
		var is_root: bool = n != room and n is Node3D and (n.scene_file_path != "" or n is GeometryInstance3D)
		if is_root:
			var meshes := n.find_children("*", "GeometryInstance3D", true, false)
			if n is GeometryInstance3D:
				meshes.append(n)
			meshes = meshes.filter(func(m): return not (m is Label3D) and not _skipped(m))
			if meshes.is_empty():
				continue
			var box := AABB()
			for i in meshes.size():
				var b: AABB = meshes[i].global_transform * meshes[i].get_aabb()
				box = b if i == 0 else box.merge(b)
			var roofs := n.find_children("*", "Node3D", true, false).filter(
				func(c): return ROOF_TAGS.any(func(t): return String(c.name).ends_with(t)) or c.get_meta("visibility_group", "") == "roof")
			_roots.append({"node": n, "aabb": box, "meshes": meshes.filter(func(m): return m is MeshInstance3D), "roofs": roofs})
			continue
		for c in n.get_children():
			stack.append(c)


func _skipped(n: Node) -> bool:
	if n.is_in_group("player") or n.is_in_group("local_player"):
		return true
	for s in SKIP_NAMES:
		if String(n.name).begins_with(s):
			return true
	return false


## The placement root the player stands on (a dock, bridge, stairs): never fade it.
func _support_root() -> Node:
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.3, _player.global_position + Vector3.DOWN * 1.0, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var n: Node = hit.collider
	while n != null and n != _room:
		for e in _roots:
			if e["node"] == n:
				return n
		n = n.get_parent()
	return null


func _owner_box(node: Node) -> AABB:
	for e in _roots:
		if e["roofs"].has(node):
			return e["aabb"]
	return AABB()


func _inside_footprint(box: AABB, p: Vector3) -> bool:
	return p.x > box.position.x + 0.3 and p.x < box.end.x - 0.3 and p.z > box.position.z + 0.3 and p.z < box.end.z - 0.3 \
		and p.y < box.end.y


## True when the occluder's screen rect overlaps the penguin's screen circle and its nearest
## point is in front of the penguin along the view direction.
func _covers_player(box: AABB, target: Vector3) -> bool:
	var fwd := -_camera.global_basis.z
	var player_depth := fwd.dot(target - _camera.global_position)
	var near := INF
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in 8:
		var c := box.get_endpoint(i)
		var depth := fwd.dot(c - _camera.global_position)
		if depth <= 0.05:
			return false  # straddles the camera: ignore rather than guess
		near = minf(near, depth)
		var sp := _camera.unproject_position(c)
		lo = lo.min(sp)
		hi = hi.max(sp)
	if near > player_depth - 0.3:
		return false
	var centre := _camera.unproject_position(target)
	var radius := _camera.get_viewport().get_visible_rect().size.y * 0.06
	var closest := centre.clamp(lo, hi)
	return closest.distance_to(centre) < radius


func _segment_hits(box: AABB, a: Vector3, b: Vector3) -> bool:  # slab test
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for i in 3:
		if absf(d[i]) < 1e-6:
			if a[i] < box.position[i] or a[i] > box.end[i]:
				return false
			continue
		var ta := (box.position[i] - a[i]) / d[i]
		var tb := (box.end[i] - a[i]) / d[i]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return false
	return true


func _set_silhouette(on: bool) -> void:
	if _player == null:
		return
	var visual := _player.get_node_or_null("Visual")
	if visual == null:
		return
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _silhouette if on else null
	for label in _player.find_children("*", "Label3D", true, false):
		label.no_depth_test = true  # nametags and prompts always readable


func _reduced_motion() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings != null and bool(settings.get("reduced_motion"))
