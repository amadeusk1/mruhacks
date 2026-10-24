class_name CinemaScreen
extends MeshInstance3D
## Puts the shared film on the auditorium's big screen (cinema port 3/5, flag pengloo/cinema/screen_video).
## The art pack's `insert_cinema_screen` surface has no UVs, so a QuadMesh sized to that surface's
## bounds is placed 2 cm in front of it (toward the seats) and shows the shared player's frames;
## the curtains slide open while it plays. Signals use methods on this node, so they disconnect
## when the cinema is freed. Returns the screen, or null if the screen surface isn't found.

const SCREEN_MATERIAL := "insert_cinema_screen"


var player: CinemaScreenPlayer
var hall: Node3D
var _mat: StandardMaterial3D


static func attach(hall: Node3D, player: CinemaScreenPlayer) -> CinemaScreen:
	var box := _screen_bounds(hall)  # in hall space
	if box.size == Vector3.ZERO:
		push_warning("CinemaScreen: no '%s' surface in %s" % [SCREEN_MATERIAL, hall.name])
		return null
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#0b0e16")  # dark until the first frame arrives
	var quad := CinemaScreen.new()
	quad.name = "CinemaScreen"
	quad.hall = hall
	quad.player = player
	quad._mat = mat
	var thin := 0 if box.size.x < box.size.y and box.size.x < box.size.z else (1 if box.size.y < box.size.z else 2)
	var center := box.get_center()
	var toward := signf(-center[thin]) if absf(center[thin]) > 0.01 else 1.0  # toward the hall middle
	var face := Vector3.ZERO
	face[thin] = toward
	var dims := [box.size.x, box.size.y, box.size.z]
	dims.remove_at(thin)
	quad.mesh = QuadMesh.new()
	(quad.mesh as QuadMesh).size = Vector2(maxf(dims[0], dims[1]), minf(dims[0], dims[1]))
	quad.material_override = mat
	hall.add_child(quad)
	quad.position = center + face * (box.size[thin] * 0.5 + 0.02)
	quad.look_at(hall.to_global(quad.position + face), Vector3.UP if thin != 1 else Vector3.FORWARD)
	quad.rotate_object_local(Vector3.UP, PI)  # look_at points -Z at the target; the quad's front is +Z
	player.texture_changed.connect(quad._on_texture)
	player.playing_changed.connect(quad._on_playing)
	if player.texture:
		quad._on_texture(player.texture)
	quad._on_playing(player.playing)
	return quad


func _on_texture(t: Texture2D) -> void:
	_mat.albedo_texture = t
	_mat.albedo_color = Color.WHITE


func _on_playing(on: bool) -> void:
	curtains(on, hall)


static func _screen_bounds(hall: Node3D) -> AABB:
	var out := AABB()
	# `hall` may itself be the mesh (the scene's find_child hits the inner MeshInstance3D first)
	for mi in [hall] + hall.find_children("*", "MeshInstance3D", true, false):
		if not mi is MeshInstance3D or (mi as MeshInstance3D).mesh == null:
			continue
		var mesh := (mi as MeshInstance3D).mesh
		var to_hall := hall.global_transform.affine_inverse() * (mi as Node3D).global_transform
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m == null or m.resource_name != SCREEN_MATERIAL:
				continue
			for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = to_hall * v
				out = AABB(p, Vector3.ZERO) if out.size == Vector3.ZERO and out.position == Vector3.ZERO else out.expand(p)
	return out


## Slides the curtain parts open (film playing) or shut, along the art pack's part motion
## (manifest "parts": slide along x, inner 2.5 m, outer 1.3 m).
static func curtains(open: bool, hall: Node3D) -> void:
	for part in [[ "part_curtain_l_inner", -2.505], ["part_curtain_l_outer", -1.3], ["part_curtain_r_inner", 2.505], ["part_curtain_r_outer", 1.3]]:
		var n := hall.find_child(part[0], true, false) as Node3D
		if n == null:
			continue
		if not n.has_meta("closed_x"):
			n.set_meta("closed_x", n.position.x)
		var tw := n.create_tween()
		tw.tween_property(n, "position:x", float(n.get_meta("closed_x")) + (float(part[1]) if open else 0.0), 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
