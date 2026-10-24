extends Node3D

## Town square plus the three shop interiors.
## Interiors sit far east of the square so the square camera never sees them.
## Spawn names that start with "Inside" pick that shop's camera frame.

const _CLOTHES := Vector3(120.0, 0.0, 0.0)
const _FURNITURE := Vector3(120.0, 0.0, 50.0)
const _PETS := Vector3(120.0, 0.0, 100.0)


func camera_for_spawn(spawn_name: String) -> Dictionary:
	if spawn_name.begins_with("InsideClothes"):
		return {"center": _CLOTHES, "limit_x": 2.2, "limit_z": 2.3}
	if spawn_name.begins_with("InsideFurniture"):
		return {"center": _FURNITURE, "limit_x": 2.2, "limit_z": 2.3}
	if spawn_name.begins_with("InsidePet"):
		return {"center": _PETS, "limit_x": 2.2, "limit_z": 2.3}
	return {
		"center": Vector3.ZERO,
		"limit_x": 10.0,
		"limit_z": 8.5,
		"height": 14.2,
		"distance": 10.8,
	}
