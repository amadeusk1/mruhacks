extends Node3D

## Yard and snow-dome interior for the home location.
## The interior sits off to the side so the yard camera never sees it.
## Spawn names that start with "Inside" use the interior camera frame.

const _INSIDE_CENTER := Vector3(80.0, 0.0, 0.0)
const _SHELL := "homes/snow_dome_interior"
## First visit, before user://home_snow_dome_interior.json exists.
const _STARTER := [
	{"id": "room_kit/sofa_2seat", "cell": [5, 7], "rot": 180},
	{"id": "room_kit/armchair", "cell": [7, 4], "rot": 270},
	{"id": "room_kit/bed", "cell": [6, 2], "rot": 0},
	{"id": "room_kit/rug_round", "cell": [5, 6], "rot": 0},
	{"id": "room_kit/floor_lamp", "cell": [8, 6], "rot": 0},
]


## Interior Personalities (Botanical Nook): warm plaster and a warm room light inside the dome.
const MOOD := {"background": "#EADBC6", "ambient": "#FFE2C2", "sun": "#FFDDB4"}
var _saved_mood := {}


func _exit_tree() -> void:
	InteriorMood.restore(get_tree(), _saved_mood)


func _ready() -> void:
	AssetPack.dress_home(self)
	_saved_mood = InteriorMood.apply(get_tree(), MOOD)
	for d in find_children("snow_dome_interior*", "Node3D", true, false):
		if d.get_parent().name == "PackProps":
			InteriorMood.paint(d, {"wall": "#F2E2C6"}, {})
	var dome: Node3D = null
	for d in find_children("snow_dome_interior*", "Node3D", true, false):
		if d.get_parent().name == "PackProps":
			dome = d
			break
	if dome:
		var layout := DecorEditor.new()
		layout.name = "HouseLayout"
		dome.add_child(layout)
		layout.setup(dome, _SHELL, get_viewport().get_camera_3d())
		if FileAccess.file_exists(layout.save_path()):
			layout.load_layout()
		else:
			layout.load_layout(_STARTER)
			layout.save_layout()
		layout.saved.connect(func(_ok: bool) -> void: _seat(dome))
		_seat.call_deferred(dome)
	var nav := get_node_or_null("NavigationRegion3D")
	for model in find_children("snow_dome*", "Node3D", true, false):  # floors where they're drawn
		if nav and model.get_parent().name == "PackProps":
			WalkSurface.build(model, nav, model.global_position.y - 0.3, model.name + "_walk")
	if nav and nav.has_method("rebake"):
		nav.call("rebake")


func _seat(dome: Node3D) -> void:
	for child in get_children():
		if child is SeatSpot:
			child.queue_free()
	SeatSpot.from_sockets(self, dome, "armchair")


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
