extends Node3D

## Yard and igloo interior for the home location.
## The interior sits off to the side so the yard camera never sees it.
## Spawn names that start with "Inside" use the interior camera frame.

const _INSIDE_CENTER := Vector3(80.0, 0.0, 0.0)


func camera_for_spawn(spawn_name: String) -> Dictionary:
	if spawn_name.begins_with("Inside"):
		return {"center": _INSIDE_CENTER, "limit_x": 2.0, "limit_z": 2.2}
	return {"center": Vector3.ZERO, "limit_x": 3.2, "limit_z": 2.2}
