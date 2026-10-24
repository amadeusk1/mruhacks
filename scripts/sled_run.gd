extends Node3D

## Sled Hill. The bus loads this room for the sled_hill destination.
## Retry restarts the hill. Back to town rides back to the plaza.

const TREE := preload("res://scenes/tree.tscn")
const ROCK := preload("res://scenes/rock.tscn")

@onready var sled: CharacterBody3D = $Sled
@onready var hud: CanvasLayer = $HUD

var _clock := 0.0
var _started := false
var _over := false
var _go_left := 0.0


func _ready() -> void:
	add_to_group("activity")
	var nested := get_tree().get_first_node_in_group("world") != null
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if nested:
		var environment := get_node_or_null("WorldEnvironment")
		if environment:
			environment.queue_free()
		if light:
			light.queue_free()
	elif light:
		light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	_plant_forest()
	sled.crashed.connect(_on_crashed)
	sled.finished.connect(_on_finished)
	hud.retry_pressed.connect(_on_retry)
	hud.town_pressed.connect(_on_town)
	hud.set_countdown("3")


func _process(delta: float) -> void:
	if _over:
		return
	if not _started:
		_clock += delta
		if _clock < 3.0:
			hud.set_countdown(str(3 - int(_clock)))
			return
		_started = true
		_go_left = 0.45
		hud.set_countdown("Go!")
		sled.begin()
	_go_left -= delta
	if _go_left <= 0.0:
		hud.set_countdown("")
	hud.set_distance(int(round(sled.distance)))


func _on_crashed() -> void:
	_finish_run("Wiped out", "You slid %d m." % int(round(sled.distance)))


func _on_finished() -> void:
	_finish_run("You made it", "Clean run, %d m." % int(round(sled.distance)))


func _finish_run(title: String, body: String) -> void:
	if _over:
		return
	_over = true
	hud.set_distance(int(round(sled.distance)))
	hud.show_result(title, body)


func _on_retry() -> void:
	_over = false
	_started = false
	_clock = 0.0
	_go_left = 0.0
	hud.hide_result()
	hud.set_countdown("3")
	hud.set_distance(0)
	sled.reset_run(Vector3(0.0, 0.2, 12.0))


func _on_town() -> void:
	hud.lock()
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("travel_to"):
		world.call_deferred("travel_to", "plaza")
		return
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _plant_forest() -> void:
	var decor := $Decor
	var z := 22.0
	var side := 1.0
	while z > -200.0:
		var trunk := TREE.instantiate()
		var wobble := float(int(absf(z * 10.0)) % 4) * 0.08
		trunk.position = Vector3(side * 9.7, 0.0, z)
		trunk.scale = Vector3.ONE * (0.88 + wobble)
		decor.add_child(trunk)
		if int(absf(z)) % 27 < 14:
			var stone := ROCK.instantiate()
			stone.position = Vector3(-side * 9.2, 0.0, z - 6.5)
			decor.add_child(stone)
		side *= -1.0
		z -= 13.5
