extends Node3D

## Yard and snow-dome interior for the home location.
## The interior sits off to the side so the yard camera never sees it.
## Spawn names that start with "Inside" use the interior camera frame.

const _INSIDE_CENTER := Vector3(80.0, 0.0, 0.0)


func _ready() -> void:
	AssetPack.dress_home(self)


func camera_for_spawn(spawn_name: String) -> Dictionary:
	if spawn_name.begins_with("Inside"):
		return {
			"center": _INSIDE_CENTER,
			"limit_x": 2.3,
			"limit_z": 2.3,
			"height": 7.4,
			"distance": 5.8,
		}
	return {
		"center": Vector3.ZERO,
		"limit_x": 4.4,
		"limit_z": 3.2,
		"height": 10.0,
		"distance": 8.2,
	}
