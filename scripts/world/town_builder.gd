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
const SAMPLE_LAYER := 1 << 7  # the visual terrain's trimesh, only sampled into the ground heightfield

@onready var _nav: NavigationRegion3D = $NavigationRegion3D

var _layout: Dictionary
var _walks: Array = []  # walkable placements' floor bodies, joined to the ground in _ready
var _blockers: Array = []  # [node, id, scale]: collision built in _ready, once the ground is queryable
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
	var play := Node.new()
	play.name = "TownCourt"
	play.set_script(load("res://scripts/town_court.gd"))
	add_child(play)


func _ready() -> void:
	_apply_environment()
	await get_tree().physics_frame  # bodies registered for the edge raycasts
	var nav := get_node("NavigationRegion3D")
	var open := 0
	var space := get_world_3d().direct_space_state
	_ground_heightfield(nav, space)
	await get_tree().physics_frame
	var ramps := 0
	for b in _blockers:
		Footprint.blocker(nav, b[0], b[1], b[2], space)
	for pair in _walks:
		ramps += WalkSurface.add_ramps(pair[0], nav, space)
	ramps += WalkSurface.stair_ramps(_walks.map(func(pair): return pair[0]), nav)
	await get_tree().physics_frame
	for pair in _walks:
		WalkSurface.span_gaps(pair[1], nav, space)
	await get_tree().physics_frame  # spans first, so a closed hole is not railed off
	var guards := 0
	for pair in _walks:
		guards += WalkSurface.guard_edges(pair[0], pair[1], nav, space)
	await get_tree().physics_frame
	for pair in _walks:
		var left: Array = WalkSurface.span_gaps(pair[1], nav, space)
		open += left.size()
	print("Town walkables: %d, ramps: %d, gap spans: %d, edge guards: %d" % [_walks.size(), ramps, nav.get_children().filter(func(n): return n.has_meta("gap_span")).size(), guards])
	if open > 0:
		push_warning("Town: %d walkable edges drop off with no guard (layout fix needed)" % open)
	await get_tree().physics_frame  # gap spans registered before the shore is traced
	_water_edges(nav, space)
	for pair in _walks:  # flights stand on their FlightRamp; the tread nosings poke through it and snag the capsule
		if pair[0].find_child("socket_bottom", true, false) and pair[0].find_child("socket_top", true, false):
			(pair[1] as StaticBody3D).collision_layer = 0
	if nav.has_method("rebake"):
		nav.call("rebake")
	AmbientFx.dress(self)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		AmbientFx.snowfall(self, world.get_node("CameraRig"))


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
			_trimesh_body(mi, SAMPLE_LAYER)


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
	node.set_meta("asset_id", id)
	node.transform = _xform(p)
	nav.add_child(node)
	if id == "activities/basketball_court_half":
		node.add_to_group("town_court_half")
	elif id == "activities/basketball_hoop":
		node.add_to_group("town_hoop")
	elif id == "activities/scoreboard":
		node.add_to_group("town_scoreboard")
	if not (p.get("tints", {}) as Dictionary).is_empty():
		var colors := {}
		for role in p["tints"]:
			colors[role] = Color(p["tints"][role])
		Tints.apply(node, colors)
	var tags: Array = p.get("tags", [])
	if tags.has("walkable") and id == "world_misc/footbridge":
		_bridge_crossing(node)  # map builder's deck + end ramps; the visual rails are not a wall
		node.set_meta("walkable", true)
	elif tags.has("walkable"):  # decks, stairs, courts: standable where drawn, solid below
		var walk := WalkSurface.build(node, nav, node.position.y - 1.2, node.name + "_walk")
		node.set_meta("walkable", true)
		if id.contains("dock"):  # flat decks: one solid box across the footprint (plank gaps left holes)
			var sz := AssetRegistry.size(id)
			var deck := _box_body(nav, Vector3.ZERO, Vector3(sz.x, 0.3, sz.z), 0.0, FLOOR_LAYER)
			deck.transform = node.transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.15 + 0.02, 0))
		if walk:
			_walks.append([node, walk])
	if tags.has("blocker"):
		_blockers.append([node, id, float(p.get("scale", 1.0))])  # Footprint.blocker: posts only for the homes arch
	_start_ambient(node)
	if id == "activities/communal_table":  # Sketch Club: sitting here joins the table's game
		(func(): SeatSpot.from_sockets(nav, node, "sketch", node.global_position, "sketch")).call_deferred()  # needs globals


## The walkable ground is one heightfield sampled from the visual terrain and paths every
## GROUND_CELL m: no curb risers, snow-lip slivers or seams between meshes for the capsule to
## catch on (8 cm curbs become gentle ramps). Decks, stairs and bridges stay separate bodies.
const GROUND_CELL := 0.3


func _ground_heightfield(nav: Node, space: PhysicsDirectSpaceState3D) -> void:
	var n := int(WATER_HALF * 2.0 / GROUND_CELL) + 1
	var low := float(_layout.get("water_level", 0.0)) - 3.0
	var h := PackedFloat32Array()
	h.resize(n * n)
	for j in n:
		for i in n:
			var x := -WATER_HALF + i * GROUND_CELL
			var z := -WATER_HALF + j * GROUND_CELL
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, low, z), SAMPLE_LAYER))
			h[j * n + i] = hit.position.y if hit else low
	var faces := PackedVector3Array()
	for j in n - 1:  # shortcut: one triangle pair per cell; merge flat cells if the collision cost ever shows
		for i in n - 1:
			var x := -WATER_HALF + i * GROUND_CELL
			var z := -WATER_HALF + j * GROUND_CELL
			var a := Vector3(x, h[j * n + i], z)
			var b := Vector3(x + GROUND_CELL, h[j * n + i + 1], z)
			var c := Vector3(x, h[(j + 1) * n + i], z + GROUND_CELL)
			var d := Vector3(x + GROUND_CELL, h[(j + 1) * n + i + 1], z + GROUND_CELL)
			faces.append_array([a, b, c, b, d, c])  # clockwise seen from above: Godot's front face
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = FLOOR_LAYER
	body.collision_mask = 0
	body.add_child(col)
	nav.add_child(body)
	for b in nav.find_children("*", "StaticBody3D", true, false):
		if b.collision_layer == SAMPLE_LAYER:
			b.queue_free()


## Invisible walls over the sea and the stream: every WATER_CELL square whose top floor lies under
## the water line (or has no floor) becomes part of a tall prism on the blocker layer, merged into
## rectangles. Decks, bridges and gap spans above the water keep their cells dry.
const WATER_CELL := 0.5
const WATER_HALF := 50.0


func _water_edges(nav: Node, space: PhysicsDirectSpaceState3D) -> void:
	var water := float(_layout.get("water_level", -INF))
	if water == -INF:
		return
	var n := int(WATER_HALF * 2.0 / WATER_CELL)
	var wet := {}
	for i in n:
		for j in n:
			var x := -WATER_HALF + (i + 0.5) * WATER_CELL
			var z := -WATER_HALF + (j + 0.5) * WATER_CELL
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, water - 8.0, z), FLOOR_LAYER))
			if hit.is_empty() or hit.position.y < water - 0.05:
				wet[Vector2i(i, j)] = true
	var walls := 0
	while not wet.is_empty():  # greedy rectangles: grow along i, then along j while the whole row is wet
		var c: Vector2i = wet.keys()[0]
		var i1 := c.x
		while wet.has(Vector2i(i1 + 1, c.y)):
			i1 += 1
		var j1 := c.y
		while range(c.x, i1 + 1).all(func(i): return wet.has(Vector2i(i, j1 + 1))):
			j1 += 1
		for i in range(c.x, i1 + 1):
			for j in range(c.y, j1 + 1):
				wet.erase(Vector2i(i, j))
		var lo := Vector2(-WATER_HALF + c.x * WATER_CELL, -WATER_HALF + c.y * WATER_CELL)
		var hi := Vector2(-WATER_HALF + (i1 + 1) * WATER_CELL, -WATER_HALF + (j1 + 1) * WATER_CELL)
		var pts := PackedVector3Array()
		for q in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
			pts.append(Vector3(q.x, water - 8.0, q.y))
			pts.append(Vector3(q.x, water + Footprint.BLOCK_TOP + 0.5, q.y))
		var body := StaticBody3D.new()
		body.name = "WaterEdge"
		body.collision_layer = BLOCK_LAYER
		body.collision_mask = 0
		body.set_meta("blocker_of", "water_edge")
		var hull := ConvexPolygonShape3D.new()
		hull.points = pts
		var col := CollisionShape3D.new()
		col.shape = hull
		body.add_child(col)
		nav.add_child(body)
		walls += 1
	print("Town water edges: %d walls" % walls)


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


## Buildings whose door the layout doesn't mark yet: derive it from the model's socket_door.
const PLACEMENT_DOORS := {"casino/casino_exterior": ["CasinoDoor", "casino_interior"]}


func _build_markers(nav: Node) -> void:
	var markers: Array = _layout.get("markers", [])
	for p in _layout["placements"]:
		var door: Array = PLACEMENT_DOORS.get(p["id"], [])
		if door.is_empty() or markers.any(func(m): return m["name"] == door[0]):
			continue
		var s: Array = AssetRegistry.sockets(p["id"]).get("socket_door", [0, 0, 0])
		var yaw := float(p.get("rot_y_deg", 0.0))
		var at := _v(p["pos"]) + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(s[0], s[2], -s[1])
		markers.append({"name": door[0], "kind": "door", "target": door[1], "pos": [at.x, at.y, at.z], "rot_y_deg": yaw})
	for m in markers:
		var kind := str(m.get("kind", ""))
		if kind == "bus":
			continue
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(m.get("rot_y_deg", 0.0)))), _v(m["pos"]))
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
	"casino_interior": ["casino", "Inside", "Casino"],
}
const ACTIVITY_TITLES := {"sled": "Sled Hill", "snowballs": "Snowball Arena", "basketball": "Basketball Court", "sketch": "Sketch Club"}


func _door(marker: Marker3D, target: String) -> void:
	# spawn just outside the door, facing away from it, so arriving never re-triggers it
	var out := Marker3D.new()
	out.name = marker.name + "Out"
	out.transform = Transform3D(marker.basis.rotated(Vector3.UP, PI), marker.position + marker.basis.z * 1.6)
	add_child(out)
	if marker.name == "Home2Door":  # the snow dome on the island is the player's house
		_anchor(marker, "your house", "Enter", "", "home", "InsideSpawn")
		return
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
		"basketball":
			pass
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
			if m and m.emission_enabled and (String(m.resource_name).begins_with("glow") or String(m.resource_name).begins_with("bulb")):
				var d := m.duplicate() as BaseMaterial3D
				mi.set_surface_override_material(s, d)
				_glows.append([d, d.emission_energy_multiplier, randf() * TAU, randf_range(2.5, 4.0)])


## Walk line of world_misc/footbridge: span along local X, arch springing at 0.30 m,
## crown 0.45 m higher. Plank tops sit a few centimetres above this, flush with the
## approach-landing sockets, so the ramps meet the deck without a step.
func _bridge_deck_y(along: float) -> float:
	var half := 1.8
	var x := clampf(along, -half, half)
	return 0.30 + 0.45 * (1.0 - (x / half) * (x / half))


func _bridge_crossing(bridge: Node3D) -> void:
	# the town builds in _enter_tree, before its children are in the tree: socket globals are
	# meaningless until then (visual-only landings; the ribbon below carries the collision)
	_bridge_approaches.call_deferred(bridge)
	var pts := PackedVector3Array()
	pts.append(Vector3(-5.2, 0.07, 0.0))  # flat lip on the path paving (top is +0.07)
	pts.append(Vector3(-4.5, 0.07, 0.0))
	for i in 17:
		var x := lerpf(-2.4, 2.4, float(i) / 16.0)
		pts.append(Vector3(x, _bridge_deck_y(x), 0.0))
	pts.append(Vector3(4.5, 0.07, 0.0))
	pts.append(Vector3(5.2, 0.07, 0.0))
	_ribbon_floor(bridge, pts, 1.2)  # no rail colliders: the water edges hold the sides, and rail ends snagged the path


## Visible ramps from the path (0.07 m) up to each deck end. Collision is the ribbon,
## not the cobble mesh, so the kerbs cannot catch the capsule.
func _bridge_approaches(bridge: Node3D) -> void:
	for end_name in ["end_e", "end_w"]:
		var landing := _spawn("town_connections/footbridge_approach_landing")
		if landing == null:
			continue
		landing.name = "Approach"
		bridge.add_child(landing)
		if end_name == "end_w":
			landing.rotation.y = PI
		var seam := Sockets.find(landing, "seam_bridge")
		var end := Sockets.find(bridge, end_name)
		if seam != null and end != null:  # not in the tree yet: compose transforms instead of global_position
			var to_bridge := WalkSurface._world(bridge).affine_inverse()
			landing.position += (to_bridge * WalkSurface._world(end)).origin - (to_bridge * WalkSurface._world(seam)).origin
		else:
			landing.position = Vector3(3.4 if end_name == "end_e" else -3.4, 0.0, 0.0)


func _ribbon_floor(parent: Node3D, pts: PackedVector3Array, width: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	var drop := 0.2
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var a0 := a + Vector3(0.0, 0.0, -half)
		var a1 := a + Vector3(0.0, 0.0, half)
		var b0 := b + Vector3(0.0, 0.0, -half)
		var b1 := b + Vector3(0.0, 0.0, half)
		var a0d := a0 + Vector3(0.0, -drop, 0.0)
		var a1d := a1 + Vector3(0.0, -drop, 0.0)
		var b0d := b0 + Vector3(0.0, -drop, 0.0)
		var b1d := b1 + Vector3(0.0, -drop, 0.0)
		_tri(st, a0, a1, b1)       # top
		_tri(st, a0, b1, b0)
		_tri(st, a0d, b1d, a1d)    # underside
		_tri(st, a0d, b0d, b1d)
		_tri(st, a0, b0, b0d)      # sides, so the slab has thickness
		_tri(st, a0, b0d, a0d)
		_tri(st, a1, b1d, b1)
		_tri(st, a1, a1d, b1d)
	var body := StaticBody3D.new()
	body.name = "DeckWalk"
	body.collision_layer = FLOOR_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = st.commit().create_trimesh_shape()
	body.add_child(shape)
	parent.add_child(body)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)  # Godot fronts are clockwise: emitted a, c, b so the deck top faces up (else no navmesh)
	st.add_vertex(c)
	st.add_vertex(b)


func _trimesh_body(mi: MeshInstance3D, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mi.mesh.create_trimesh_shape()
	body.add_child(shape)
	mi.add_child(body)


func _box_body(parent: Node, center: Vector3, size: Vector3, rot_y: float, layer: int) -> StaticBody3D:
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
	return body


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
