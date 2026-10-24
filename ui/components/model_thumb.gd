class_name ModelThumb
extends SubViewportContainer
## Renders a pack model (e.g. "homes/round_cottage_exterior") into a UI tile, auto-framed from its
## AABB, front three-quarter view on a soft sky/snow backdrop. For kits without icon PNGs.

var asset_id := ""
var bg := Color("#CFE7F1")
var yaw_deg := -28.0


func _init(p_asset := "", p_bg := Color("#CFE7F1")) -> void:
	asset_id = p_asset
	bg = p_bg
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 0.97, 0.92)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var path := "res://Models/%s.glb" % asset_id
	if not ResourceLoader.exists(path):
		return
	var m := (load(path) as PackedScene).instantiate() as Node3D
	vp.add_child(m)
	Tints.prepare(m)
	m.rotation.y = deg_to_rad(yaw_deg)
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var dist := r / sin(deg_to_rad(cam.fov * 0.5)) * 0.62
	cam.position = c + Vector3(0, r * 0.35, dist)
	cam.look_at(c)
