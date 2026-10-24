extends Node
## Map review shots at gameplay-camera angles over named spots (town layout coordinates, Godot space).
## Run: Godot --path . res://tools/capture_zones.tscn -- --out=/abs/dir/ --tag=before
const SPOTS := {
	"plaza": Vector3(0, 0, 0), "homes": Vector3(-23.5, 0, 0), "dock": Vector3(-18, 0, 18),
	"sled": Vector3(-21, 0, -24), "arena": Vector3(26, 0, -20), "court": Vector3(25.5, 0, 19.2),
	"stream": Vector3(13, 0, 2), "casino": Vector3(22, 0, -6),
}
func _ready() -> void:
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	var out := "user://"
	var tag := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
	var cam: Camera3D = w.get_node("CameraRig/Camera3D")
	(w.get_node("CameraRig") as Node3D).set_process(false)
	for c in w.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam.far = 300.0
	for k in SPOTS:
		var t: Vector3 = SPOTS[k]
		cam.global_position = t + Vector3(0, 13, 13)
		cam.look_at(t, Vector3.UP)
		for i in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%szone_%s_%s.png" % [out, k, tag])
		print("SAVED ", k)
	get_tree().quit()
