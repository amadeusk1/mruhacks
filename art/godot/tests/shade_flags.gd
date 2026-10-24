extends SceneTree
func scan(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			var m: Material = n.get_active_material(s)
			if m and String(m.resource_name).begins_with("tint_"):
				var arr: Array = n.mesh.surface_get_arrays(s)
				var cols = arr[Mesh.ARRAY_COLOR]
				var lo := 1.0
				if cols != null:
					for c in cols: lo = min(lo, c.r)
				out.append([String(m.resource_name), m.vertex_color_use_as_albedo, snappedf(lo, 0.01)])
	for c in n.get_children(): scan(c, out)
func _init() -> void:
	var bad := 0
	var good := 0
	for kit in DirAccess.get_directories_at("res://models"):
		for f in DirAccess.get_files_at("res://models/" + kit):
			if not f.ends_with(".glb"): continue
			var _ps = load("res://models/%s/%s" % [kit, f])
			if _ps == null:
				print("LOAD_FAILED ", kit, "/", f)
				continue
			var r: Node = _ps.instantiate()
			var out := []
			scan(r, out)
			for o in out:
				if not o[1] and o[2] < 0.999: bad += 1; print("SHADED_BUT_OFF ", kit, "/", f, " ", o)
				elif o[1]: good += 1
			r.free()
	print("RESULT vcol_on=", good, " shaded_but_flag_off=", bad)
	quit()
