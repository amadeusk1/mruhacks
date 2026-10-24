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


## Indoor lamps glow, they don't flood: emission on glow, bulb and window materials is clamped.
static func calm(node: Node, max_energy := 0.9) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for si in m3.mesh.get_surface_count():
			var m := m3.get_active_material(si) as BaseMaterial3D
			if m and m.emission_enabled and m.emission_energy_multiplier > max_energy:
				var d := m.duplicate() as BaseMaterial3D
				d.emission_energy_multiplier = max_energy
				m3.set_surface_override_material(si, d)


static func restore(tree: SceneTree, saved: Dictionary) -> void:
	var world := tree.get_first_node_in_group("world") if tree else null
	if saved.is_empty() or world == null:
		return
	(world.get_node("WorldEnvironment") as WorldEnvironment).environment = saved["env"]
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	sun.visible = saved["sun_visible"]
	sun.light_color = saved["light_color"]
	sun.light_energy = saved["light_energy"]
