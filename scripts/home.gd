extends Node3D

## Yard and snow-dome interior for the home location.
## The interior sits off to the side so the yard camera never sees it.
## Spawn names that start with "Inside" use the interior camera frame.

const _INSIDE_CENTER := Vector3(80.0, 0.0, 0.0)


func _ready() -> void:
	AssetPack.dress_home(self)
	var dome: Node3D = null  # the furnished interior (dress_home can leave a second, empty copy)
	for d in find_children("snow_dome_interior*", "Node3D", true, false):
		if d.get_parent().name == "PackProps" and d.find_child("bed*", false, false):
			dome = d
	if dome:
		# somewhere for visiting friends to sit together, then every seat socket is claimable
		AssetPack._furnish(dome, "room_kit", "sofa_2seat", Vector3(-0.3, 0.12, 1.25), PI)
		AssetPack._furnish(dome, "room_kit", "armchair", Vector3(1.35, 0.12, -0.25), -PI * 0.5)
		SeatSpot.from_sockets.call_deferred(self, dome, "armchair")  # after dress_home finishes furnishing


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
