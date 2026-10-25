class_name AmbientFx
extends RefCounted

## Ambient world effects from the art pack's fx meshes (Engine Spec - Ambient World):
## chimney smoke at socket_fx_smoke, fountain/waterfall droplets at socket_fx_splash, waterfall mist at
## socket_fx_mist, steam at socket_fx_steam, and a camera-local snowfall for outdoor rooms.

static var _meshes := {}


## Emitters for every fx socket under `root` (call after the room is built).
static func dress(root: Node) -> void:
	for n in root.find_children("socket_fx_*", "Node3D", true, false):
		var kind := String(n.name).trim_prefix("socket_fx_").get_slice("_", 0)
		match kind:
			"smoke":
				n.add_child(_emitter("fx/smoke_puff_a", 5, 4.0, Vector3(0.15, 0.25, 0), 0.6, 1.6, 0.55))
			"steam":
				n.add_child(_emitter("fx/steam_wisp", 3, 2.0, Vector3(0, 0.12, 0), 0.5, 1.2, 0.4))
			"splash":
				n.add_child(_emitter("fx/splash_droplet", 8, 0.7, Vector3(0, 1.4, 0), 0.8, 0.6, 0.9, 6.0))
			"mist":  # spray drifting off the foot of a waterfall
				n.add_child(_emitter("fx/steam_wisp", 6, 2.2, Vector3(0, 0.3, 0.1), 1.6, 2.4, 0.3))


## A bounded snow field that follows `follow` (the camera rig). Outdoor rooms only.
static func snowfall(parent: Node, follow: Node3D) -> GPUParticles3D:
	var p := _emitter("fx/snow_flake_a", 90, 8.0, Vector3(0.15, -0.35, 0.05), 0.4, 1.0, 1.0, 0.05)
	p.name = "Snowfall"
	var mat := p.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(14, 0.5, 12)
	mat.spread = 15.0
	mat.scale_min = 4.0  # 3 cm flakes read as specks from the 18 m gameplay camera
	mat.scale_max = 7.0
	p.visibility_aabb = AABB(Vector3(-16, -12, -14), Vector3(32, 14, 28))
	p.set_script(load("res://scripts/world/follow_xz.gd"))
	p.set("target", follow)
	p.set("height", 9.0)
	parent.add_child(p)
	return p


static func _emitter(mesh_id: String, amount: int, lifetime: float, velocity: Vector3, spread_m: float,
		grow: float, alpha: float, gravity: float = 0.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.randomness = 0.35
	p.preprocess = lifetime  # already going when the room loads
	p.draw_pass_1 = _mesh(mesh_id)
	var m := ParticleProcessMaterial.new()
	m.direction = velocity.normalized() if velocity.length() > 0 else Vector3.UP
	m.initial_velocity_min = velocity.length() * 0.7
	m.initial_velocity_max = velocity.length() * 1.3
	m.spread = 25.0
	m.gravity = Vector3(0, -gravity, 0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = spread_m * 0.25
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.scale_min = 0.8
	m.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, grow))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = curve
	m.scale_curve = scale_tex
	var ramp := Gradient.new()  # fade in, hold, fade out
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, alpha))
	ramp.add_point(0.7, Color(1, 1, 1, alpha * 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	return p


## The fx mesh with its fx_* material set to take the particle colour ramp.
static func _mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var node := AssetPack.spawn(id.get_base_dir(), id.get_file())
	var mi := node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D if node else null
	var mesh: Mesh = null
	if mi:
		mesh = mi.mesh.duplicate() as Mesh
		for s in mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src:
				var m := src.duplicate() as BaseMaterial3D
				m.vertex_color_use_as_albedo = true  # particle COLOR carries the fade
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.billboard_keep_scale = true
				mesh.surface_set_material(s, m)
	if node:
		node.free()
	_meshes[id] = mesh
	return mesh
