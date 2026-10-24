extends Node3D

## Cinema lot, lobby, and auditorium.
## The lobby and the screen sit far east so the forecourt camera never sees them.
## InsideLobby and ScreenReturn use the lobby camera. InsideScreen uses the auditorium.


func _ready() -> void:
	AssetPack.dress_cinema(self)


func camera_for_spawn(spawn_name: String) -> Dictionary:
	if spawn_name == "InsideScreen":
		return {
			"center": get_meta("hall_center", Vector3(240.0, 0.0, 50.0)),
			"limit_x": 2.2,
			"limit_z": 3.0,
			"height": 8.6,
			"distance": 5.6,
		}
	if spawn_name.begins_with("Inside") or spawn_name == "ScreenReturn":
		return {
			"center": get_meta("lobby_center", Vector3(240.0, 0.0, 0.0)),
			"limit_x": 3.4,
			"limit_z": 2.4,
			"height": 8.2,
			"distance": 5.4,
		}
	return {
		"center": Vector3(0.0, 0.0, 0.6),
		"limit_x": 7.2,
		"limit_z": 6.2,
		"height": 13.0,
		"distance": 10.0,
	}
