extends StaticBody3D

## A town bench with one open seat beside whoever is already there.
## Press F while the prompt is showing, or click the seat from across
## the square and the walk ends by sitting down.

@export var seat_side := 1.0
@export var face_yaw := 0.0

const _SEAT_X := 0.55
const _SEAT_Y := 0.12
const _SEAT_Z := -0.06
const _STAND_Z := -1.02

var _prompt: Label3D


func _ready() -> void:
	add_to_group("bench")
	collision_layer = 2
	collision_mask = 0
	_prompt = Label3D.new()
	_prompt.name = "SitPrompt"
	_prompt.text = "F to sit"
	_prompt.font_size = 42
	_prompt.outline_size = 8
	_prompt.pixel_size = 0.005
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(0.98, 0.98, 1, 1)
	_prompt.outline_modulate = Color(0.1, 0.16, 0.24, 1)
	_prompt.visible = false
	_prompt.top_level = true
	add_child(_prompt)
	_prompt.global_position = seat_global() + Vector3(0.0, 1.15, 0.0)


func seat_global() -> Vector3:
	return _offset(Vector3(seat_side * _SEAT_X, _SEAT_Y, _SEAT_Z))


func approach_point() -> Vector3:
	return _offset(Vector3(seat_side * _SEAT_X, 0.0, _STAND_Z))


func bench_key() -> String:
	var location := ""
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("current_location_id"):
		location = str(world.call("current_location_id"))
		if location == "home" and world.has_method("home_owner_id"):
			location = "home:%s" % int(world.call("home_owner_id"))
	var room: Node = self
	while room != null:
		var parent := room.get_parent()
		if parent != null and parent.name == "LocationHost":
			break
		room = parent
	var rel := name
	if room != null:
		rel = str(room.get_path_to(self))
	return "%s:%s" % [location, rel]


func try_sit(force := false) -> bool:
	var player := _local_player()
	if player == null or not player.has_method("sit_down"):
		return false
	if player.has_method("is_sitting") and bool(player.call("is_sitting")) and player.call("current_bench") == self:
		return true
	var stand := approach_point()
	var flat := Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z)
	if not force and flat.length() > 1.35:
		return false
	if force and flat.length() > 2.2:
		return false
	if not Net.claim_bench(bench_key()):
		return false
	player.call("sit_down", self, seat_global(), face_yaw, stand)
	return true


func can_interact() -> bool:
	return _prompt.visible and _prompt.text != "Taken"


func _process(_delta: float) -> void:
	var player := _local_player() as Node3D
	if player == null:
		_prompt.visible = false
		return
	var here := false
	if player.has_method("is_sitting") and bool(player.call("is_sitting")):
		here = player.call("current_bench") == self
	var stand := approach_point()
	var flat := Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z)
	var taken := Net.bench_held_by_other(bench_key())
	_prompt.text = "Taken" if taken else "F to sit"
	_prompt.visible = not here and flat.length() < 1.7


func _local_player() -> Node:
	return get_tree().get_first_node_in_group("local_player")


func _offset(amount: Vector3) -> Vector3:
	var basis := global_transform.basis
	return global_position + basis.x.normalized() * amount.x + basis.y.normalized() * amount.y + basis.z.normalized() * amount.z
