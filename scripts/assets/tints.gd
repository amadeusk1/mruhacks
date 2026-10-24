class_name Tints
## Engine-side colour for the asset pack (see vault note "Tint System").
## Materials named tint_<role>__<default> are recolourable; COLOR_0 holds a baked greyscale
## shade that multiplies the colour, so recolours keep their tile-to-tile variation.

## Give this instance its own copies of every tint material (so recolouring one house doesn't
## recolour all of them) and make sure the baked shade is used. Call once per instance.
static func prepare(root: Node) -> void:
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m and String(m.resource_name).begins_with("tint_"):
				var dup := m.duplicate() as BaseMaterial3D
				dup.vertex_color_use_as_albedo = true  # the importer only sets this when the shade isn't all white
				mi.set_surface_override_material(s, dup)

## Recolour by role, e.g. Tints.apply(house, {"roof": Color("#4a7bd0"), "wall": Color("#f3e2c5")}).
## Roles not in the dictionary keep their current colour. Call prepare() first.
static func apply(root: Node, colors: Dictionary) -> void:
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as BaseMaterial3D
			if m == null:
				continue
			var r := role_of(m)
			if r.ends_with("_glow") and not colors.has(r):
				r = r.trim_suffix("_glow")  # glow regions follow their base role unless set explicitly
			if r != "" and colors.has(r):
				m.albedo_color = colors[r]
				if m.emission_enabled:  # glowing tints (team pad rims, lamp shades) glow in the new colour
					m.emission = colors[r]

## Tint roles present on an asset, for building colour pickers.
static func roles(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			var r := role_of(m) if m else ""
			if r != "" and not out.has(r):
				out.append(r)
	return out

static func role_of(m: Material) -> String:
	var n := String(m.resource_name)
	if not n.begins_with("tint_"):
		return ""
	return n.substr(5).get_slice("__", 0)

static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out
