extends SceneTree
# Imports every GLB under res://models and reports what Godot actually sees.
var report := {}

func walk(n: Node, info: Dictionary) -> void:
	if n.name.begins_with("socket_"):
		info.sockets += 1
	if n is MeshInstance3D:
		var mesh: Mesh = n.mesh
		for s in mesh.get_surface_count():
			var m: Material = n.get_active_material(s)
			if m == null:
				continue
			var nm: String = String(m.resource_name)
			if nm.begins_with("tint_"):
				info.tint_surfaces += 1
				var has_col: bool = (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0
				if m is BaseMaterial3D and not m.vertex_color_use_as_albedo:
					info.tint_no_vcol += 1
				if not has_col:
					info.tint_no_color_attr += 1
			info.mats[nm] = true
		if mesh is ArrayMesh and mesh.get_blend_shape_count() > 0:
			info.morphs = mesh.get_blend_shape_count()
	if n is Skeleton3D:
		info.bones = n.get_bone_count()
	if n is AnimationPlayer:
		info.anims = n.get_animation_list().size()
	for c in n.get_children():
		walk(c, info)

func _init() -> void:
	var files := []
	for kit in DirAccess.get_directories_at("res://models"):
		for f in DirAccess.get_files_at("res://models/" + kit):
			if f.ends_with(".glb"):
				files.append("res://models/%s/%s" % [kit, f])
	var tot := {"files": 0, "failed": [], "tint_surfaces": 0, "tint_no_color_attr": [], "sockets": 0, "rigged": 0, "anim_files": []}
	for p in files:
		var ps = load(p)
		tot.files += 1
		if ps == null:
			tot.failed.append(p); continue
		var root: Node = ps.instantiate()
		var info := {"sockets": 0, "tint_surfaces": 0, "tint_no_vcol": 0, "tint_no_color_attr": 0, "mats": {}, "bones": 0, "anims": 0, "morphs": 0}
		walk(root, info)
		tot.tint_surfaces += info.tint_surfaces
		tot.sockets += info.sockets
		if info.tint_no_color_attr: tot.tint_no_color_attr.append(p)
		if info.bones: tot.rigged += 1
		if info.anims: tot.anim_files.append("%s:%d" % [p.get_file(), info.anims])
		root.free()
	# Shade-flag problems are reported by shade_flags.gd (only surfaces with real shade matter;
	# Tints.prepare() forces the flag on at runtime anyway).
	print("REPORT ", JSON.stringify(tot))
	quit()
