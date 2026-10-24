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
				d.albedo_color = Color(palette[String(m.resource_name)])
				m3.set_surface_override_material(si, d)


static func apply(tree: SceneTree, mood: Dictionary) -> Dictionary:
	var world := tree.get_first_node_in_group("world")
	if mood.is_empty() or world == null:
		return {}
	var we := world.get_node("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	var saved := {"env": we.environment, "light_color": sun.light_color, "light_energy": sun.light_energy}
	var env := we.environment.duplicate() as Environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(mood["background"])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(mood["ambient"])
	env.ambient_light_energy = float(mood.get("ambient_energy", 0.75))
	we.environment = env
	sun.light_color = Color(mood["sun"])
	sun.light_energy = float(mood.get("sun_energy", 0.85))
	return saved


static func restore(tree: SceneTree, saved: Dictionary) -> void:
	var world := tree.get_first_node_in_group("world") if tree else null
	if saved.is_empty() or world == null:
		return
	(world.get_node("WorldEnvironment") as WorldEnvironment).environment = saved["env"]
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	sun.light_color = saved["light_color"]
	sun.light_energy = saved["light_energy"]
