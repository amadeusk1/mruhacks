extends Node3D

## The connected town, built at load from the art pack's layout data
## (res://Models/world/town_layout.json, format in docs/Art Docs/World Layout Format.md).
## Everything walkable or blocking goes under NavigationRegion3D *before* its room_nav.gd
## bakes in _ready, so click-to-walk paths work like in the teammate's plaza.

const LAYOUT := "res://Models/world/town_layout.json"
const STUB := "res://scripts/world/town_layout_stub.json"
const ENV_FORWARD := "res://scenes/env/town_env_forward.tres"
const ENV_COMPAT := "res://scenes/env/town_env_compat.tres"
const FOLIAGE := preload("res://scripts/world/foliage_batch.gdshader")
const BATCH_MIN := 6  # identical untinted, part-less props batched into one MultiMesh
const FLOOR_LAYER := 1
const BLOCK_LAYER := 2

@onready var _nav: NavigationRegion3D = $NavigationRegion3D

var _layout: Dictionary
var _glows: Array = []  # [material, base_energy, phase]
var _saved_env: Environment
var _saved_sun := {}
var _t := 0.0


func _enter_tree() -> void:
	var path := LAYOUT if FileAccess.file_exists(LAYOUT) else STUB
	_layout = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(_layout is Dictionary and _layout.has("placements"), "bad town layout: " + path)
	var nav := get_node("NavigationRegion3D")
	_build_terrain(nav)
	_build_placements(nav)
	_build_markers(nav)
	for b in _layout.get("nav_blockers", []):
		_box_body(nav, _v(b["pos"]), _v(b["size"]), float(b.get("rot_y_deg", 0)), BLOCK_LAYER)


func _ready() -> void:
	_apply_environment()


func _exit_tree() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or _saved_env == null:
		return
	(world.get_node("WorldEnvironment") as WorldEnvironment).environment = _saved_env
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	for k in _saved_sun:
		sun.set(k, _saved_sun[k])


func _process(delta: float) -> void:
	_t += delta
	for g in _glows:  # gentle, out-of-phase lantern breathing (Engine Spec - Ambient World)
		g[0].emission_energy_multiplier = g[1] * (1.0 + 0.12 * sin(_t * TAU / g[3] + g[2]))


## Same contract as the teammate's rooms: centre, follow limits, camera height and distance.
func camera_for_spawn(_spawn_name: String) -> Dictionary:
	var cam: Dictionary = _layout.get("camera", {})
	if cam.has("bounds_min"):  # layout v2: walkable bounds plus pitch/distance
		var lo: Array = cam["bounds_min"]
		var hi: Array = cam["bounds_max"]
		var pitch := deg_to_rad(absf(float(cam.get("pitch_deg", -50))))
		var dist := float(cam.get("distance", 18))
		return {
			"center": Vector3((lo[0] + hi[0]) * 0.5, 0, (lo[1] + hi[1]) * 0.5),
			"limit_x": (hi[0] - lo[0]) * 0.5,
			"limit_z": (hi[1] - lo[1]) * 0.5,
			"height": dist * sin(pitch),
			"distance": dist * cos(pitch),
		}
	return {
		"center": _v(cam.get("center", [0, 0, 0])),
		"limit_x": float(cam.get("limit_x", 30.0)),
		"limit_z": float(cam.get("limit_z", 24.0)),
		"height": float(cam.get("height", 15.0)),
		"distance": float(cam.get("distance", 12.5)),
	}


func _build_terrain(nav: Node) -> void:
	var tpath := "res://Models/" + str(_layout.get("terrain", ""))
	var terrain: Node3D
	if _layout.get("terrain", "") != "" and ResourceLoader.exists(tpath):
		terrain = load(tpath).instantiate()
	else:  # stub: flat snow field
		var mi := MeshInstance3D.new()
		mi.name = "terrain_snow"
		var plane := PlaneMesh.new()
		plane.size = Vector2(90, 70)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#EEF4F7")
		m.roughness = 0.9
		plane.material = m
		mi.mesh = plane
		terrain = Node3D.new()
		terrain.add_child(mi)
	terrain.name = "Terrain"
	nav.add_child(terrain)
	Tints.prepare(terrain)
	for mi in terrain.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).begins_with("water"):  # v2 merges snow/rock/sand into "town_terrain"
			_trimesh_body(mi, FLOOR_LAYER)


func _build_placements(nav: Node) -> void:
	var groups := {}
	for p in _layout["placements"]:
		var id := str(p["id"])
		var batchable: bool = (p.get("tints", {}) as Dictionary).is_empty() and _sway_only(id) \
			and not (p.get("tags", []) as Array).has("walkable") and not (p.get("tags", []) as Array).has("blocker")
		groups.get_or_add(id if batchable else "", []).append(p)
	for id in groups:
		if id != "" and groups[id].size() >= BATCH_MIN:
			_batch(nav, id, groups[id])
		else:
			for p in groups[id]:
				_place(nav, p)


func _xform(p: Dictionary) -> Transform3D:
	var s := float(p.get("scale", 1.0))
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(p.get("rot_y_deg", 0.0)))).scaled(Vector3.ONE * s), _v(p["pos"]))


func _place(nav: Node, p: Dictionary) -> void:
	var id := str(p["id"])
	var node := _spawn(id)
	if node == null:
		return
	node.name = str(p.get("name", id.get_file()))
	node.transform = _xform(p)
	nav.add_child(node)
	if not (p.get("tints", {}) as Dictionary).is_empty():
		var colors := {}
		for role in p["tints"]:
			colors[role] = Color(p["tints"][role])
		Tints.apply(node, colors)
	var tags: Array = p.get("tags", [])
	if tags.has("walkable"):
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			_trimesh_body(mi, FLOOR_LAYER)
	if tags.has("blocker"):
		var size := AssetRegistry.size(id) * float(p.get("scale", 1.0))
		_box_body(nav, node.position + Vector3(0, size.y * 0.5, 0), size, float(p.get("rot_y_deg", 0.0)), BLOCK_LAYER)
	_start_ambient(node)


## Assets whose only moving parts sway (tree crowns, shrub tops) batch fine: the sway moves
## into the foliage shader. Doors, flags and the like need real nodes.
func _sway_only(id: String) -> bool:
	for part in AssetRegistry.parts(id).values():
		if part.get("motion", "") != "sway":
			return false
	return true


func _batch(nav: Node, id: String, items: Array) -> void:
	var proto := _spawn(id)
	if proto == null:
		return
	var parts := AssetRegistry.parts(id)
	for mi in proto.find_children("*", "MeshInstance3D", true, false):
		var local := _local_to(proto, mi)
		var sway := float(parts.get(String(mi.get_parent().name), parts.get(String(mi.name), {})).get("amp_deg", 0.0))
		var mesh := mi.mesh.duplicate() as Mesh
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, _batch_material(mi.get_active_material(s), sway))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, _xform(items[i]) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s" % [id.get_file(), mi.name]
		mmi.multimesh = mm
		nav.add_child(mmi)
	proto.free()


func _spawn(id: String) -> Node3D:  # teammate's loader: instancing plus Tints.prepare
	return AssetPack.spawn(id.get_base_dir(), id.get_file())


## Foliage shader version of a surface: same colour/shade, sway, and the occlusion hole.
## Glowing surfaces (lanterns) keep their own material.
func _batch_material(src: Material, sway: float) -> Material:
	var base := src as BaseMaterial3D
	if base == null or base.emission_enabled or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return src
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo", base.albedo_color)
	m.set_shader_parameter("use_vertex_shade", base.vertex_color_use_as_albedo)
	m.set_shader_parameter("roughness", base.roughness)
	m.set_shader_parameter("sway_deg", sway)
	return m


func _local_to(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		t = (cur as Node3D).transform * t if cur is Node3D else t
		cur = cur.get_parent()
	return t


func _build_markers(nav: Node) -> void:
	var markers: Array = _layout.get("markers", [])
	if not markers.any(func(m): return m.get("kind", "") == "bus"):
		# world.gd needs NavigationRegion3D/BusStop; put one beside the arrival spot
		for m in markers:
			if m["name"] == "BusArrival":
				var p: Array = m["pos"]
				markers.append({"name": "BusStop", "kind": "bus", "pos": [p[0] + 3.0, 0.0, p[2] + 1.5], "rot_y_deg": 90})
				break
	for m in markers:
		var kind := str(m.get("kind", ""))
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(m.get("rot_y_deg", 0.0)))), _v(m["pos"]))
		if kind == "bus":  # world.gd expects NavigationRegion3D/BusStop
			var stop := load("res://scenes/bus_stop.tscn").instantiate() as Node3D
			stop.name = "BusStop"
			stop.transform = t
			nav.add_child(stop)
			continue
		var marker := Marker3D.new()
		marker.name = str(m["name"])
		marker.transform = t
		for k in m:
			if k not in ["name", "pos", "rot_y_deg"]:
				marker.set_meta(k, m[k])
		add_child(marker)
		if kind == "door":
			_door(marker, str(m.get("target", "")))
		elif kind == "activity":
			_activity_anchor(marker, str(m.get("activity", "")))


## Town door target -> [location, spawn in that location]. Interiors return to "<Door>Out".
const DOORS := {
	"cinema_lobby": ["cinema", "InsideLobby", "Cinema"],
	"cafe_interior": ["cafe", "Inside", "Café"],
	"arcade_interior": ["arcade", "Inside", "Arcade"],
	"home": ["home", "InsideSpawn", "your igloo"],
}
const ACTIVITY_TITLES := {"sled": "Sled Hill", "snowballs": "Snowball Arena", "basketball": "Basketball Court", "sketch": "Sketch Club"}


func _door(marker: Marker3D, target: String) -> void:
	# spawn just outside the door, facing away from it, so arriving never re-triggers it
	var out := Marker3D.new()
	out.name = marker.name + "Out"
	out.transform = Transform3D(marker.basis.rotated(Vector3.UP, PI), marker.position + marker.basis.z * 1.6)
	add_child(out)
	if not DOORS.has(target):
		return
	var d: Array = DOORS[target]
	_anchor(marker, d[2], "Enter", "", d[0], d[1])


func _activity_anchor(marker: Marker3D, activity: String) -> void:
	match activity:
		"fishing":  # the teammate's fishing spot; the rail sits 1.2 m in front of the stand marker
			var spot := StaticBody3D.new()
			spot.name = marker.name + "Rail"
			spot.set_script(load("res://scripts/fishing_spot.gd"))
			var facing := -marker.basis.z
			spot.position = marker.position + facing * 1.2 + Vector3(0, 0.58, 0)
			spot.rotation.y = marker.rotation.y - PI * 0.5
			add_child(spot)
		"sled":
			_anchor(marker, "Sled Hill", "Ride", "", "sled_hill", "BusArrival")
		"sled_finish":
			pass
		_:
			_anchor(marker, ACTIVITY_TITLES.get(activity, activity.capitalize()), "Join", activity, "", "")


func _anchor(at: Node3D, title: String, verb: String, activity: String, location: String, spawn: String) -> void:
	var a := Interactable.new()
	a.name = at.name + "Action"
	a.title = title
	a.verb = verb
	a.activity = activity
	a.location = location
	a.spawn_name = spawn
	a.transform = at.transform
	a.set_meta("marker", at.name)
	add_child(a)


func _start_ambient(node: Node) -> void:
	for ap in node.find_children("*", "AnimationPlayer", true, false):
		for clip in (ap as AnimationPlayer).get_animation_list():
			if String(clip).ends_with("_sway") or String(clip).ends_with("_flutter") or String(clip).ends_with("_spin"):
				ap.play(clip)
				ap.seek(randf() * ap.get_animation(clip).length, true)
				ap.speed_scale = randf_range(0.8, 1.2)
				break
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m and m.emission_enabled and String(m.resource_name).begins_with(("glow")):
				var d := m.duplicate() as BaseMaterial3D
				mi.set_surface_override_material(s, d)
				_glows.append([d, d.emission_energy_multiplier, randf() * TAU, randf_range(2.5, 4.0)])


func _trimesh_body(mi: MeshInstance3D, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mi.mesh.create_trimesh_shape()
	body.add_child(shape)
	mi.add_child(body)


func _box_body(parent: Node, center: Vector3, size: Vector3, rot_y: float, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), center)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


func _apply_environment() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return
	var we := world.get_node("WorldEnvironment") as WorldEnvironment
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_saved_env = we.environment
	we.environment = load(ENV_COMPAT if compat else ENV_FORWARD)
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	for k in ["rotation_degrees", "light_color", "light_energy", "shadow_enabled", "shadow_blur"]:
		_saved_sun[k] = sun.get(k)
	var s: Dictionary = _layout.get("sun", {})
	sun.rotation_degrees = _v(s.get("rotation_deg", [-48, -35, 0]))
	sun.light_color = Color(s.get("color", "#FFE2B0"))
	sun.light_energy = float(s.get("energy", 1.25)) * (0.62 if compat else 1.0)  # Compatibility renders hotter
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5


func _v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])
