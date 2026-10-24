extends Node
## Renders the island straight down (orthographic) into res://ui/map/town_map.png + town_map.json.
## Re-run whenever the town layout changes:  Godot --path . res://tools/map_capture.tscn
const SIZE := 2048
const HALF := Vector2(46, 44)    # metres of Godot x/z either side of the centre
const CENTER := Vector2(0, -1)


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, int(SIZE * HALF.y / HALF.x))
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e: Environment = (load("res://scenes/env/town_env_forward.tres") as Environment).duplicate(true)
	e.fog_enabled = false
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_color = Color("#FFE6C2")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	vp.add_child(sun)
	vp.add_child(load("res://scenes/locations/town.tscn").instantiate())
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = HALF.y * 2.0
	cam.far = 200
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(CENTER.x, 80, CENTER.y), Vector3(CENTER.x, 0, CENTER.y), Vector3(0, 0, -1))
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://ui/map/town_map.png")
	var meta := {"min": [CENTER.x - HALF.x, CENTER.y - HALF.y], "max": [CENTER.x + HALF.x, CENTER.y + HALF.y]}
	var f := FileAccess.open("res://ui/map/town_map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	print("MAP saved")
	# world-select thumbnails (Choose a World rows): three village views like the mockup
	var shots := [[Vector3(-4, 7, 24), Vector3(-15, 0, 18)], [Vector3(14, 8, 8), Vector3(-2, 1, -8)], [Vector3(26, 6, 6), Vector3(10, 1, -2)]]
	vp.size = Vector2i(520, 330)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 48
	for i in shots.size():
		cam.look_at_from_position(shots[i][0], shots[i][1], Vector3.UP)
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://ui/screens/world_thumb_%d.png" % i)
	print("THUMBS saved")
	get_tree().quit()
