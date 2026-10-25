class_name InteriorMood
extends RefCounted

## Concept-sheet look for a room: named materials recoloured, tint roles applied, and a warm
## indoor light (room-tone background and ambient instead of the cold sky; shadows read blue
## indoors otherwise). apply() returns what it replaced; pass that to restore() on exit.


static func paint(node: Node, roles: Dictionary, palette: Dictionary) -> void:
	if not roles.is_empty():
		var colors := {}
		for r in roles:
			colors[r] = Color(roles[r])
		Tints.apply(node, colors)
	if palette.is_empty():
		return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for si in m3.mesh.get_surface_count():
			var m := m3.get_active_material(si) as BaseMaterial3D
			if m and palette.has(String(m.resource_name)):
				var d := m.duplicate() as BaseMaterial3D
				var v := String(palette[String(m.resource_name)])
				if v.begins_with("glow:"):  # step and aisle lights, lamp glass: lit, not just coloured
					d.albedo_color = Color(v.trim_prefix("glow:"))
					d.emission_enabled = true
					d.emission = d.albedo_color
					d.emission_energy_multiplier = 0.9
				else:
					d.albedo_color = Color(v)
				m3.set_surface_override_material(si, d)


static func apply(tree: SceneTree, mood: Dictionary) -> Dictionary:
	var world := tree.get_first_node_in_group("world")
	if mood.is_empty() or world == null:
		return {}
	var we := world.get_node("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	var saved := {"env": we.environment, "sun_visible": sun.visible, "light_color": sun.light_color, "light_energy": sun.light_energy}
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	# one indoor environment: no sun, a low warm ambient, filmic tone and (almost) no glow; the
	# outdoor sky ambient and sun stacked with the room lamps washed every room out
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(mood["background"])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(mood["ambient"])
	env.ambient_light_energy = float(mood.get("ambient_energy", 0.32)) * (0.85 if compat else 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(mood.get("exposure", 1.0)) * (0.9 if compat else 1.0)
	env.glow_enabled = not compat
	env.glow_intensity = 0.15
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	we.environment = env
	sun.visible = false
	return saved


## Indoor finish for a room, one duplicated material per original:
##  - emission on glow, bulb and window materials clamped (lamps glow, they don't flood);
##  - a soft rim on every surface, so flat toon faces read as forms instead of flat or blown out;
##  - floors (`floors`: material names) get a faint low-frequency noise, triplanar, so big tiled
##    or planked areas aren't one flat colour.
static func calm(node: Node, max_energy := 0.9, floors: Array = []) -> void:
	var done := {}
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for si in m3.mesh.get_surface_count():
			var m := m3.get_active_material(si) as BaseMaterial3D
			if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if not done.has(m):
				var d := m.duplicate() as BaseMaterial3D
				if d.emission_enabled:
					d.emission_energy_multiplier = minf(d.emission_energy_multiplier, max_energy)
				d.rim_enabled = true
				d.rim = 0.18
				d.rim_tint = 0.65
				if floors.has(String(m.resource_name)):
					d.albedo_texture = _floor_noise()
					d.uv1_triplanar = true
					d.uv1_scale = Vector3.ONE * 0.35
				done[m] = d
			m3.set_surface_override_material(si, done[m])


static var _noise: NoiseTexture2D


static func _floor_noise() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.02
		_noise = NoiseTexture2D.new()
		_noise.noise = n
		_noise.seamless = true
		_noise.width = 256
		_noise.height = 256
		var ramp := Gradient.new()  # 0.86..1.0: a faint wash, never a pattern
		ramp.set_color(0, Color(0.86, 0.86, 0.86))
		ramp.set_color(1, Color(1, 1, 1))
		_noise.color_ramp = ramp
	return _noise


## Contact shadows: a soft dark disc on the floor under each piece of furniture, the cheap
## stand-in for ambient occlusion the web renderer can't do (no SSAO in Compatibility).
static func contact_shadows(parent: Node3D, props: Array, floor_y: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.07, 0.04, 0.42)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	mat.albedo_texture = tex
	for node in props:
		if not is_instance_valid(node):
			continue
		var box := AABB()
		var first := true
		for mi in (node as Node3D).find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first or box.position.y > floor_y + 0.3:
			continue  # wall-mounted
		var quad := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(box.size.x, box.size.z) * 1.35
		quad.mesh = plane
		quad.material_override = mat
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(quad)
		quad.global_position = Vector3(box.get_center().x, floor_y + 0.012, box.get_center().z)


static func restore(tree: SceneTree, saved: Dictionary) -> void:
	var world := tree.get_first_node_in_group("world") if tree else null
	if saved.is_empty() or world == null:
		return
	(world.get_node("WorldEnvironment") as WorldEnvironment).environment = saved["env"]
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	sun.visible = saved["sun_visible"]
	sun.light_color = saved["light_color"]
	sun.light_energy = saved["light_energy"]
