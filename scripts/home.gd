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

var _visit: Array = []  # [owner id, DecorEditor, dome] while visiting someone else's home


## Interior Personalities (Botanical Nook): warm plaster and a warm room light inside the dome.
const MOOD := {"background": "#EADBC6", "ambient": "#FFE2C2", "sun": "#FFDDB4"}
var _saved_mood := {}


func _exit_tree() -> void:
	InteriorMood.restore(get_tree(), _saved_mood)


func _ready() -> void:
	AssetPack.dress_home(self)
	InteriorMood.calm(self)
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
		var w := get_tree().get_first_node_in_group("world")
		var owner_id: int = w.call("home_owner_id") if w else 0
		if Net.is_online() and owner_id != Net.local_id():
			# a visit: show the owner's furniture (starter set until it arrives), never touch our save
			layout.load_layout(_STARTER, {})
			_visit = [owner_id, layout, dome]
			Net.home_layout.connect(_on_home_layout)
			Net.fetch_home(owner_id)
		elif FileAccess.file_exists(layout.save_path()):
			layout.load_layout()
		else:
			layout.load_layout(_STARTER)
			layout.save_layout()
		layout.saved.connect(func(ok: bool) -> void:
			_seat(dome)
			if ok:
				Net.publish_home(FileAccess.get_file_as_string(layout.save_path())))
		_seat.call_deferred(dome)
	var nav := get_node_or_null("NavigationRegion3D")
	for model in find_children("snow_dome*", "Node3D", true, false):  # floors where they're drawn
		if nav and model.get_parent().name == "PackProps":
			WalkSurface.build(model, nav, model.global_position.y - 0.3, model.name + "_walk")
	if nav and nav.has_method("rebake"):
		nav.call("rebake")


func _on_home_layout(owner_id: int, json: String) -> void:
	if _visit.is_empty() or owner_id != _visit[0] or json == "":
		return
	_visit[1].clear_items()
	_visit[1].load_layout(_STARTER, JSON.parse_string(json))
	_seat(_visit[2])


func _seat(dome: Node3D) -> void:
	for child in get_children():
		if child is SeatSpot:
			child.queue_free()
	SeatSpot.from_sockets(self, dome, "armchair")


## Indoor light only while the player is inside: the yard / forecourt keep the town's sky and sun.
func _set_indoor(on: bool) -> void:
	if on and _saved_mood.is_empty():
		_saved_mood = InteriorMood.apply(get_tree(), MOOD)
	elif not on and not _saved_mood.is_empty():
		InteriorMood.restore(get_tree(), _saved_mood)
		_saved_mood = {}


func camera_for_spawn(spawn_name: String) -> Dictionary:
	_set_indoor(spawn_name.begins_with("Inside"))
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
