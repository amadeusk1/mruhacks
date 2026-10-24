extends SceneTree
func _init() -> void:
	var ok := true
	for p in ["res://models/home_themes/beanbag.glb", "res://models/cafe/cafe_exterior.glb", "res://models/room_kit/sofa_2seat.glb"]:
		var a: Node = load(p).instantiate()
		var b: Node = load(p).instantiate()
		Tints.prepare(a); Tints.prepare(b)
		var rs := Tints.roles(a)
		var col := {}
		for r in rs: col[r] = Color(0.2, 0.4, 0.9)
		Tints.apply(a, col)
		# a recoloured, b untouched, flag on everywhere
		for mi in Tints._meshes(a):
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s) as BaseMaterial3D
				if m and (not m.vertex_color_use_as_albedo or not m.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.9))): ok = false
		for mi in Tints._meshes(b):
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s) as BaseMaterial3D
				if m and m.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.9)): ok = false
		print("ROLES ", p.get_file(), " ", rs, " sockets=", Sockets.all(a).keys())
		a.free(); b.free()
	print("TINT_TEST ", "PASS" if ok else "FAIL")
	quit()
