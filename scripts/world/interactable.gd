class_name Interactable
extends Area3D

## A contextual action in the world (door, activity entrance). Group "interactables".
## UI/HUD API: prompt_text() and interact(player). The penguin's F key also finds these through
## can_interact() / approach_point(), like the teammate's benches, fishing spots and bus stop.
## Either travels (location + spawn_name) or asks the Activities autoload to start `activity`.

@export var title := ""          # shown in the prompt, e.g. "Cinema"
@export var verb := "Enter"
@export var activity := ""       # "sled", "snowballs", "basketball", "sketch", ...
@export var location := ""       # travel target in LocationCatalog
@export var spawn_name := "BusArrival"
@export var reach := 2.2

var _label: Label3D
var _note := ""  # temporary message replacing the prompt ("Opening soon")
var _note_until := 0.0


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 0
	collision_mask = 0
	_label = Label3D.new()
	_label.font_size = 42
	_label.outline_size = 8
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_modulate = Color(0.08, 0.2, 0.28)
	_label.position = Vector3(0, 1.6, 0)
	_label.visible = false
	add_child(_label)


func prompt_text() -> String:
	if _note != "":
		return _note
	return "%s %s" % [verb, title] if title != "" else verb


func approach_point() -> Vector3:
	return global_position


func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		return false
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	return d.length() < reach


func interact(player: Node) -> bool:
	if location != "":
		var world := get_tree().get_first_node_in_group("world")
		if world == null or not world.has_method("travel_to"):
			return false
		world.call("travel_to", location, spawn_name)
		return true
	if Activities.request(activity, self, player):
		return true
	_note = "%s opens soon" % title  # honest: no handler for this activity yet
	_note_until = Time.get_ticks_msec() / 1000.0 + 2.0
	return true


func _process(_delta: float) -> void:
	if _note != "" and Time.get_ticks_msec() / 1000.0 > _note_until:
		_note = ""
	# the town HUD shows this prompt as its action button (UI mockup); keep the 3D label as fallback
	_label.visible = can_interact() and get_tree().get_first_node_in_group("town_hud") == null
	if _label.visible:
		_label.text = "F  " + prompt_text()
