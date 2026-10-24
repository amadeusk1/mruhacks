extends Node3D

## Low-poly body for one shop pet. Eyes sit on local -Z, matching the penguins.
## Pen mode plays the stall idle. Follow mode only bobs; the parent moves it.

var kind := "pebble"
var pen_mode := true

var _phase := 0.0
var _visual: Node3D
var _splash: MeshInstance3D
var _moving := false
var _splashing := false


func setup(next_kind: String, in_pen: bool) -> void:
	kind = next_kind
	pen_mode = in_pen
	_moving = false
	_splashing = false
	if _visual != null:
		_visual.free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_shadow()
	match kind:
		"slick":
			_build_slick()
		"ember":
			_build_ember()
		_:
			_build_pebble()
	if pen_mode:
		_visual.rotation.y = PI
	else:
		_splash = _disc()


func set_follow_state(moving: bool, splashing: bool) -> void:
	_moving = moving
	_splashing = splashing and kind == "slick"


func _process(delta: float) -> void:
	if _visual == null:
		return
	_phase += delta
	if pen_mode:
		_play_pen()
	else:
		_play_follow(delta)


func _play_pen() -> void:
	match kind:
		"slick":
			var slide := sin(_phase * 1.15)
			_visual.position = Vector3(slide * 0.11, 0.0, 0.0)
			_visual.rotation.y = PI + slide * 0.18
		"ember":
			var cycle := fposmod(_phase, 1.7)
			var x := -0.09
			var hop := 0.0
			if cycle < 0.32:
				var u := cycle / 0.32
				x = lerpf(-0.09, 0.09, u)
				hop = sin(u * PI)
			elif cycle < 0.85:
				x = 0.09
			elif cycle < 1.17:
				var u := (cycle - 0.85) / 0.32
				x = lerpf(0.09, -0.09, u)
				hop = sin(u * PI)
			_visual.position = Vector3(x, hop * 0.07, 0.0)
			_visual.rotation.y = PI
		_:
			_visual.position = Vector3(0.0, sin(_phase * 1.25) * 0.03, 0.0)
			_visual.rotation.y = PI + sin(_phase * 0.55) * 0.1


func _play_follow(delta: float) -> void:
	var bob := 0.0
	if kind == "ember":
		bob = absf(sin(_phase * 8.0)) * 0.055 if _moving else 0.0
	elif kind == "slick":
		bob = sin(_phase * 2.4) * 0.012
		_visual.position.x = sin(_phase * 1.6) * 0.03
	else:
		var pace := 2.4 if _moving else 1.1
		bob = sin(_phase * pace) * (0.028 if _moving else 0.008)
		var sit := 0.76 if not _moving else 1.0
		_visual.scale.y = lerpf(_visual.scale.y, sit, 1.0 - exp(-delta * 8.0))
	if kind != "slick":
		_visual.position.x = lerpf(_visual.position.x, 0.0, 1.0 - exp(-delta * 6.0))
	_visual.position.y = lerpf(_visual.position.y, bob, 1.0 - exp(-delta * 10.0))
	_visual.rotation.y = lerpf(_visual.rotation.y, 0.0, 1.0 - exp(-delta * 8.0))
	if _splash != null:
		_splash.visible = _splashing
		if _splashing:
			var pulse := 0.75 + sin(_phase * 7.0) * 0.35
			_splash.scale = Vector3(pulse, 1.0, pulse)


func _build_pebble() -> void:
	_ball(_visual, "Body", Vector3(0.0, 0.18, 0.0), Vector3(0.34, 0.28, 0.34), Color(0.95, 0.55, 0.42))
	_eyes(Vector3(0.0, 0.24, 0.0), 0.1)
	if not pen_mode:
		return
	var zzz := Label3D.new()
	zzz.text = "z"
	zzz.font_size = 48
	zzz.pixel_size = 0.004
	zzz.outline_size = 8
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zzz.modulate = Color(0.25, 0.4, 0.32, 1)
	zzz.outline_modulate = Color(0.93, 0.98, 0.94, 1)
	zzz.position = Vector3(0.1, 0.46, 0.0)
	_visual.add_child(zzz)


func _build_slick() -> void:
	_ball(_visual, "Body", Vector3(0.0, 0.12, 0.0), Vector3(0.42, 0.16, 0.22), Color(0.25, 0.68, 0.66))
	_ball(_visual, "Belly", Vector3(0.02, 0.09, -0.06), Vector3(0.2, 0.07, 0.1), Color(0.78, 0.91, 0.88))
	_ball(_visual, "Nose", Vector3(0.22, 0.14, -0.08), Vector3(0.06, 0.045, 0.05), Color(0.16, 0.4, 0.42))
	_ball(_visual, "FlipperL", Vector3(0.02, 0.06, 0.12), Vector3(0.14, 0.035, 0.09), Color(0.18, 0.5, 0.52))
	_ball(_visual, "FlipperR", Vector3(0.02, 0.06, -0.12), Vector3(0.14, 0.035, 0.09), Color(0.18, 0.5, 0.52))
	_ball(_visual, "Tail", Vector3(-0.24, 0.12, 0.0), Vector3(0.09, 0.045, 0.09), Color(0.2, 0.55, 0.56))
	_eyes(Vector3(0.12, 0.16, 0.0), 0.05, -0.09)


func _build_ember() -> void:
	_ball(_visual, "Body", Vector3(0.0, 0.18, 0.0), Vector3(0.22, 0.2, 0.26), Color(0.74, 0.34, 0.2))
	_ball(_visual, "Chest", Vector3(0.0, 0.15, -0.1), Vector3(0.11, 0.09, 0.07), Color(0.96, 0.88, 0.74))
	_ball(_visual, "Tail", Vector3(0.0, 0.2, 0.18), Vector3(0.08, 0.07, 0.12), Color(0.55, 0.24, 0.14))
	var ear_mesh := CylinderMesh.new()
	ear_mesh.top_radius = 0.012
	ear_mesh.bottom_radius = 0.05
	ear_mesh.height = 0.16
	ear_mesh.radial_segments = 8
	var ear_l := _part(_visual, "EarL", ear_mesh, Vector3(-0.08, 0.36, -0.02), Color(0.74, 0.34, 0.2))
	ear_l.rotation_degrees = Vector3(-8.0, 0.0, 16.0)
	var ear_r := _part(_visual, "EarR", ear_mesh, Vector3(0.08, 0.36, -0.02), Color(0.74, 0.34, 0.2))
	ear_r.rotation_degrees = Vector3(-8.0, 0.0, -16.0)
	_eyes(Vector3(0.0, 0.22, 0.0), 0.07)


func _eyes(at: Vector3, spread: float, depth := -0.12) -> void:
	_ball(_visual, "EyeL", at + Vector3(-spread, 0.02, depth), Vector3(0.055, 0.055, 0.04), Color(0.96, 0.96, 0.98))
	_ball(_visual, "PupilL", at + Vector3(-spread, 0.02, depth - 0.03), Vector3(0.028, 0.028, 0.02), Color(0.08, 0.08, 0.1))
	_ball(_visual, "EyeR", at + Vector3(spread, 0.02, depth), Vector3(0.055, 0.055, 0.04), Color(0.96, 0.96, 0.98))
	_ball(_visual, "PupilR", at + Vector3(spread, 0.02, depth - 0.03), Vector3(0.028, 0.028, 0.02), Color(0.08, 0.08, 0.1))


func _shadow() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.02
	mesh.radial_segments = 16
	var shadow := _part(_visual, "Shadow", mesh, Vector3(0.0, 0.02, 0.0), Color(0.05, 0.08, 0.12, 0.28))
	var mat := shadow.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _disc() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.2
	mesh.height = 0.02
	mesh.radial_segments = 16
	var disc := _part(self, "Splash", mesh, Vector3(0.0, 0.04, 0.0), Color(0.55, 0.82, 0.95, 0.5))
	var mat := disc.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.15
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.visible = false
	return disc


func _ball(parent: Node3D, node_name: String, at: Vector3, scale: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := _part(parent, node_name, mesh, at, color)
	node.scale = scale
	return node


func _part(parent: Node3D, node_name: String, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	node.set_surface_override_material(0, mat)
	parent.add_child(node)
	return node
