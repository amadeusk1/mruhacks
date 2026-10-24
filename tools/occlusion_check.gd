extends Node
## Counts how often the "behind something" silhouette is on while standing around the docks and
## plaza (it should only show when a building/tree really covers the penguin). The behind_*
## areas are the positive control: standing north of the café/arcade must trigger it sometimes.
## Run: Godot --path . res://tools/occlusion_check.tscn
const AREAS := {"behind_cafe": [Vector3(-9, 0, -20), Vector3(-2, 0, -16)], "behind_arcade": [Vector3(7, 0, -20), Vector3(12, 0, -16)], "docks": [Vector3(-26, 0, 14), Vector3(-10, 0, 30)], "plaza": [Vector3(-8, 0, -6), Vector3(8, 0, 10)]}


func _ready() -> void:
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(1.0).timeout
	w.call("_on_solo_pressed")
	await get_tree().create_timer(6.0).timeout
	var p: CharacterBody3D = w.get_node("Penguin")
	var space := p.get_world_3d().direct_space_state
	for area in AREAS:
		var a: Vector3 = AREAS[area][0]
		var b: Vector3 = AREAS[area][1]
		var on := 0
		var n := 0
		for x in range(int(a.x), int(b.x) + 1, 2):
			for z in range(int(a.z), int(b.z) + 1, 2):
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 20, z), Vector3(x, -3, z), 1))
				if hit.is_empty() or String(hit.collider.name).begins_with("water"):
					continue
				p.global_position = hit.position + Vector3.UP * 0.05
				for f in 12: await get_tree().physics_frame
				var mi := p.get_node("Visual").find_children("*", "MeshInstance3D", true, false)
				n += 1
				if not mi.is_empty() and (mi[0] as MeshInstance3D).material_overlay != null:
					on += 1
		print("OCCLUSION %s: silhouette on %d / %d spots" % [area, on, n])
	get_tree().quit()
