extends Node3D
## Builds the Sled Hill course from SledCourse: a groomed half-pipe ribbon with raised snow banks
## (trimesh collision: the banks are walls), snowfields with fir forest, fences on the bank lips,
## the start gate + start light, checkpoint arches, boost pads, ramps, slalom hazards and the
## finish arch with its race clock. Child of sled_run.tscn ("Track").

const TREE := preload("res://scenes/tree.tscn")
const ROCK := preload("res://scenes/rock.tscn")
const BOOST_SHADER := preload("res://scripts/activities/boost_pad.gdshader")
## Cross-section: [lateral m, height above the centreline m, colour]. Track | bank wall | lip | field.
const PROFILE := [
	[-46.0, 3.2, Color("#F4F8FB")], [-16.0, 1.2, Color("#F1F6FA")], [-9.5, 1.9, Color("#EEF4F9")],
	[-7.2, 2.05, Color("#F7FAFC")], [-6.0, 1.75, Color("#E4EEF6")], [-5.0, 0.3, Color("#D3E3F0")],
	[-4.2, 0.2, Color("#DDE9F3")], [-2.0, 0.05, Color("#E9F1F8")], [0.0, 0.0, Color("#EDF4FA")],
	[2.0, 0.05, Color("#E9F1F8")], [4.2, 0.2, Color("#DDE9F3")], [5.0, 0.3, Color("#D3E3F0")],
	[6.0, 1.75, Color("#E4EEF6")], [7.2, 2.05, Color("#F7FAFC")], [9.5, 1.9, Color("#EEF4F9")],
	[16.0, 1.2, Color("#F1F6FA")], [46.0, 3.2, Color("#F4F8FB")],
]

var start_lamps: Array[MeshInstance3D] = []
var clock_label: Label3D


func _ready() -> void:
	_ground()
	_start_area()
	for i in SledCourse.CHECKPOINTS.size():
		_arch(SledCourse.CHECKPOINTS[i], "interaction_props", "checkpoint_posts", 2.75, "CP %d" % (i + 1))
	_finish()
	for f in SledCourse.FEATURES:
		match str(f[2]):
			"boost": _boost(float(f[0]), float(f[1]))
			"ramp": _ramp(float(f[0]))
			"tree": _hazard(TREE, float(f[0]), float(f[1]), 1.0)
			"rock": _hazard(ROCK, float(f[0]), float(f[1]), 1.15)
	_forest()
	_fences()


## Lights the start lamps: n of 3 red, or all green when go.
func set_lamps(lit: int, go: bool) -> void:
	for i in start_lamps.size():
		var m := start_lamps[i].material_override as StandardMaterial3D
		var on := go or i < lit
		var c := Color("#4CD964") if go else Color("#FF4B3E")
		m.albedo_color = c if on else Color("#2A3440")
		m.emission = c
		m.emission_energy_multiplier = 2.6 if on else 0.0


func _ground() -> void:
	var p := SledCourse.samples()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := PROFILE.size()
	for i in p.size():
		var s := float(i) * SledCourse.STEP
		var r := SledCourse.right(s)
		for prof in PROFILE:
			var lat: float = prof[0]
			var h: float = prof[1]
			if absf(lat) <= SledCourse.WIDTH * 0.5:
				h = SledCourse.dish(lat)
			var c: Color = prof[2]
			if absf(lat) < 4.5 and int(s) % 6 < 3 and absf(absf(lat) - 1.6) < 0.5:
				c = c.darkened(0.03)  # faint groomed grooves
			st.set_color(c)
			st.set_uv(Vector2(lat * 0.1, s * 0.1))
			st.add_vertex(p[i] + r * lat + Vector3.UP * h)
	for i in p.size() - 1:
		for k in cols - 1:
			var a := i * cols + k
			var b := a + 1
			var c2 := a + cols
			var d := c2 + 1
			st.add_index(a); st.add_index(c2); st.add_index(b)
			st.add_index(b); st.add_index(c2); st.add_index(d)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.88
	mat.rim_enabled = true
	mat.rim = 0.25
	var mi := MeshInstance3D.new()
	mi.name = "Snow"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "SnowBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


func _start_area() -> void:
	var s := SledCourse.START_S
	_arch(s, "winter", "start_gate", 2.85, "")
	var light := _prop("interaction_props", "start_light", ground_at(s + 0.6, 7.6), SledCourse.yaw(s) + PI)
	if light:
		for k in 3:
			var lamp := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.12
			sphere.height = 0.24
			lamp.mesh = sphere
			var m := StandardMaterial3D.new()
			m.emission_enabled = true
			lamp.material_override = m
			var sock: Dictionary = AssetRegistry.sockets("interaction_props/start_light")
			var v: Array = sock.get("socket_lamp_%d" % k, [0, -0.2, 1.4 + 0.25 * k])
			lamp.position = Vector3(float(v[0]), float(v[2]), -float(v[1])) + Vector3(0, 0, 0.06)
			light.add_child(lamp)
			start_lamps.append(lamp)
	set_lamps(0, false)
	# flags and snowbanks framing the start
	for side in [-1.0, 1.0]:
		_prop("winter", "team_flag", ground_at(s - 4.0, side * 7.8), SledCourse.yaw(s))
		_prop("winter", "snowbank_large", ground_at(s - 9.0, side * 8.6), randf() * TAU)


func _finish() -> void:
	var s := SledCourse.finish_s()
	_arch(s, "winter", "finish_flags", 2.85, "")
	var timer := _prop("interaction_props", "finish_timer", ground_at(s + 3.0, -7.8), SledCourse.yaw(s) + PI)
	if timer:
		clock_label = Label3D.new()
		clock_label.text = "00:00.0"
		clock_label.font_size = 96
		clock_label.pixel_size = 0.006
		clock_label.outline_size = 16
		clock_label.modulate = Color("#FFE27A")
		clock_label.outline_modulate = Color("#14243A")
		var sock: Dictionary = AssetRegistry.sockets("interaction_props/finish_timer")
		var v: Array = sock.get("socket_display", [0, -0.2, 2.2])
		clock_label.position = Vector3(float(v[0]), float(v[2]), -float(v[1])) + Vector3(0, 0, 0.08)
		timer.add_child(clock_label)


## A gate prop stretched across the track (the kit's gates are sized for a 3.5 m lane).
func _arch(s: float, kit: String, asset: String, stretch: float, sign_text: String) -> void:
	var node := _prop(kit, asset, SledCourse.point(s), SledCourse.yaw(s) + PI)
	if node == null:
		return
	node.scale = Vector3(stretch, 1.35, 1.35)
	if sign_text != "":
		var l := Label3D.new()
		l.text = sign_text
		l.font_size = 64
		l.pixel_size = 0.01
		l.outline_size = 12
		l.modulate = Color.WHITE
		l.outline_modulate = Color("#173B6B")
		l.position = SledCourse.point(s) + Vector3.UP * 2.6
		l.rotation.y = SledCourse.yaw(s)
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(l)


func _boost(s: float, lateral: float) -> void:
	var at := SledCourse.point(s, lateral) + Vector3.UP * 0.04
	var pad := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2.4, 4.2)
	pad.mesh = q
	var m := ShaderMaterial.new()
	m.shader = BOOST_SHADER
	pad.material_override = m
	pad.position = at
	pad.rotation.y = SledCourse.yaw(s)
	add_child(pad)
	_trigger("boost", at, SledCourse.yaw(s), Vector3(2.4, 1.2, 4.0))


func _ramp(s: float) -> void:
	var at := SledCourse.point(s)
	var w := SledCourse.WIDTH - 0.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# wedge: low edge facing uphill (+Z local), lip 0.9 m high at the downhill end (-Z)
	var v := [Vector3(-w / 2, 0, 1.8), Vector3(w / 2, 0, 1.8), Vector3(-w / 2, 0.9, -1.8), Vector3(w / 2, 0.9, -1.8),
		Vector3(-w / 2, 0, -1.8), Vector3(w / 2, 0, -1.8)]
	var tris := [[0, 2, 1], [1, 2, 3], [2, 4, 3], [3, 4, 5], [0, 4, 2], [1, 3, 5]]
	for t in tris:
		for k in t:
			st.set_color(Color("#FFFFFF") if v[k].y > 0.5 else Color("#CFE3F2"))
			st.add_vertex(v[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = SledCourse.yaw(s)
	add_child(mi)
	# blue lip stripe so the kicker reads from the chase camera
	var lip := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.08, 0.25)
	lip.mesh = bm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#3D7BD9")
	lm.emission_enabled = true
	lm.emission = Color("#3D7BD9")
	lm.emission_energy_multiplier = 0.4
	lip.material_override = lm
	lip.position = Vector3(0, 0.9, -1.75)
	mi.add_child(lip)
	_trigger("ramp", at + SledCourse.forward(s) * -0.6, SledCourse.yaw(s), Vector3(w, 1.6, 1.2))


func _hazard(scene: PackedScene, s: float, lateral: float, scale_by: float) -> void:
	var n := scene.instantiate() as Node3D
	n.position = SledCourse.point(s, lateral)
	n.rotation.y = fposmod(s * 1.7, TAU)
	n.scale = Vector3.ONE * scale_by
	add_child(n)
	_prop("winter", "snowbank_small", SledCourse.point(s + 1.0, lateral), SledCourse.yaw(s))


func _trigger(group: String, at: Vector3, yaw_angle: float, size: Vector3) -> void:
	var a := Area3D.new()
	a.add_to_group(group)
	a.collision_layer = 16  # sled HazardProbe mask 8 (hazards) | 16 (boost, ramp)
	a.collision_mask = 0
	a.monitorable = true
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	a.add_child(cs)
	a.position = at
	a.rotation.y = yaw_angle
	add_child(a)


## Fir forest on the snowfields: batched, deterministic, thicker away from the track.
func _forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var spots: Array = [[], [], []]
	var length := SledCourse.length()
	var s := -10.0
	while s < length + 10.0:
		for side in [-1.0, 1.0]:
			for band in 3:
				if rng.randf() < 0.25 + 0.2 * band:
					var lat: float = side * rng.randf_range(10.5 + band * 9.0, 18.0 + band * 10.0)
					var at := ground_at(clampf(s, 0.0, length), lat) + Vector3.DOWN * 0.05
					spots[mini(band + rng.randi_range(0, 1), 2)].append(Transform3D(
						Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.35)), at))
		s += 4.5
	var kinds := ["fir_tree_small", "fir_tree_medium", "fir_tree_large"]
	for k in 3:
		_batch("winter", kinds[k], spots[k])


func _fences() -> void:
	var xs: Array = []
	var s := SledCourse.START_S + 4.0
	while s < SledCourse.finish_s() + 20.0:
		for side in [-1.0, 1.0]:
			var at := ground_at(s, side * 7.0)
			xs.append(Transform3D(Basis(Vector3.UP, SledCourse.yaw(s) + PI * 0.5), at))
		s += 2.2
	_batch("winter", "snow_fence_2m", xs)


## A point on the snow surface at (s, lateral), banks and fields included.
func ground_at(s: float, lat: float) -> Vector3:
	return SledCourse.point(s) + SledCourse.right(s) * lat + Vector3.UP * _field_height(absf(lat))


func _field_height(lat: float) -> float:
	if lat <= SledCourse.WIDTH * 0.5:
		return SledCourse.dish(lat)
	for i in range(8, PROFILE.size() - 1):
		var a: Array = PROFILE[i]
		var b: Array = PROFILE[i + 1]
		if lat >= float(a[0]) and lat <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (lat - float(a[0])) / (float(b[0]) - float(a[0])))
	return 3.2


## One MultiMeshInstance3D per mesh of the asset, so hundreds of trees/fence panels stay cheap.
func _batch(kit: String, asset: String, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var src := AssetPack.spawn(kit, asset)
	if src == null:
		return
	add_child(src)  # global transforms of the parts need the tree
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		var local := src.global_transform.affine_inverse() * mesh_inst.global_transform
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := mesh_inst.mesh
		for surf in mesh.get_surface_count():  # Tints.prepare puts the tint materials in overrides
			var mat := mesh_inst.get_surface_override_material(surf)
			if mat:
				if mesh == mesh_inst.mesh:
					mesh = mesh.duplicate()
				mesh.surface_set_material(surf, mat)
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_batch" % asset
		mmi.multimesh = mm
		add_child(mmi)
	src.queue_free()


func _prop(kit: String, asset: String, at: Vector3, yaw_angle: float) -> Node3D:
	return AssetPack.place(self, kit, asset, at, yaw_angle)
