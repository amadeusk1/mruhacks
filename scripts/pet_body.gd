extends Node3D

## One shop pet, loaded from Models/pets. The kit faces +Z.
## Gameplay treats -Z as forward, so the model is turned around.
## Pen mode faces the counter. Follow mode only bobs; the parent moves it.

var kind := "pengi"
var pen_mode := true

var _phase := 0.0
var _visual: Node3D
var _family := "penguin"
var _moving := false


func setup(next_kind: String, in_pen: bool) -> void:
	kind = next_kind
	pen_mode = in_pen
	_moving = false
	var info := PetCatalog.find(kind)
	_family = str(info.get("family", "penguin"))
	if _visual != null:
		_visual.free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var model_name := str(info.get("model", ""))
	var model := AssetPack.spawn("pets", model_name) if model_name != "" else null
	if model == null:
		push_error("Pet model missing for %s" % kind)
		return
	model.name = "Model"
	model.rotation.y = PI
	_visual.add_child(model)
	if pen_mode:
		_visual.rotation.y = PI


func set_follow_state(moving: bool, _splashing: bool) -> void:
	_moving = moving


func _process(delta: float) -> void:
	if _visual == null:
		return
	_phase += delta
	if pen_mode:
		_play_pen()
	else:
		_play_follow(delta)


func _play_pen() -> void:
	if _family == "fish":
		var slide := sin(_phase * 1.2)
		_visual.position = Vector3(slide * 0.05, sin(_phase * 2.1) * 0.025, 0.0)
		_visual.rotation.y = PI + slide * 0.22
	else:
		_visual.position = Vector3(0.0, sin(_phase * 1.25) * 0.018, 0.0)
		_visual.rotation.y = PI + sin(_phase * 0.55) * 0.08


func _play_follow(delta: float) -> void:
	var bob := 0.0
	if _family == "fish":
		var pace := 3.1 if _moving else 1.7
		bob = sin(_phase * pace) * (0.045 if _moving else 0.02)
		_visual.position.x = sin(_phase * 1.4) * 0.03
	else:
		var pace := 2.6 if _moving else 1.05
		bob = sin(_phase * pace) * (0.03 if _moving else 0.008)
		_visual.position.x = lerpf(_visual.position.x, 0.0, 1.0 - exp(-delta * 6.0))
	_visual.position.y = lerpf(_visual.position.y, bob, 1.0 - exp(-delta * 10.0))
	_visual.rotation.y = lerpf(_visual.rotation.y, 0.0, 1.0 - exp(-delta * 8.0))
