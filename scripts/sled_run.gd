extends Node3D

## Sled Hill. The bus loads this room for the sled_hill destination.
## Online, everyone on the hill shares the countdown and can see each other.
## Retry queues the next shared start. Back to town rides back to the plaza.

const TREE := preload("res://scenes/tree.tscn")
const ROCK := preload("res://scenes/rock.tscn")

@onready var sled: CharacterBody3D = $Sled
@onready var hud: CanvasLayer = $HUD

var _clock := 0.0
var _started := false
var _over := false
var _waiting := false
var _go_left := 0.0
var _race_id := 0
var _ghosts: Dictionary = {}


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
	var mine := Net.local_profile()
	sled.apply_identity(str(mine["name"]), int(mine["color"]))
	if Net.is_online():
		hud.set_countdown("")
		Net.sled_gate.connect(_on_sled_gate)
		Net.sled_pose.connect(_on_sled_pose)
	else:
		hud.set_countdown("3")


func _process(delta: float) -> void:
	if Net.is_online():
		_sync_ghosts()
	if _over or _waiting:
		return
	if Net.is_online() and _race_id == 0:
		return
	if not _started:
		_clock += delta
		if _clock < 3.0:
			hud.set_countdown(str(3 - int(_clock)))
			return
		if Net.is_online():
			hud.set_countdown("")
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
	Net.sled_done()


func _on_retry() -> void:
	if Net.is_online():
		Net.sled_retry()
		return
	_over = false
	_started = false
	_clock = 0.0
	_go_left = 0.0
	hud.hide_result()
	hud.set_countdown("3")
	hud.set_distance(0)
	sled.reset_run(Vector3(0.0, 0.2, 12.0))


func _on_sled_gate(race_id: int, phase: String, seconds: float) -> void:
	if phase == "countdown":
		_race_id = race_id
		_waiting = false
		_over = false
		_started = false
		_go_left = 0.0
		_clock = 3.0 - clampf(seconds, 0.0, 3.0)
		hud.hide_result()
		hud.set_hint("A and D to steer")
		hud.set_distance(0)
		sled.reset_run(_lane(Net.local_id()))
		hud.set_countdown(str(maxi(1, int(ceil(seconds)))))
		return
	if phase == "go":
		if _started and _race_id == race_id:
			return
		_race_id = race_id
		_waiting = false
		_over = false
		_started = true
		_go_left = 0.45
		hud.hide_result()
		hud.set_hint("A and D to steer")
		hud.set_countdown("Go!")
		sled.begin()
		return
	if phase == "wait":
		_waiting = true
		_over = false
		_started = false
		_go_left = 0.0
		hud.hide_result()
		hud.set_countdown("")
		hud.set_hint("Next race")
		hud.set_distance(0)
		sled.reset_run(_lane(Net.local_id()))


func _on_sled_pose(peer_id: int, x: float, y: float, z: float, yaw: float, steer: float, crashed: bool) -> void:
	if not _ghosts.has(peer_id):
		_sync_ghosts()
	var ghost: Object = _ghosts.get(peer_id)
	if ghost != null and is_instance_valid(ghost):
		ghost.present_remote(Vector3(x, y, z), yaw, steer, crashed)


func _sync_ghosts() -> void:
	if not Net.is_online():
		_clear_ghosts()
		return
	var live: Dictionary = {}
	for entry in Net.roster():
		var id := int(entry.get("id", 0))
		if id == Net.local_id():
			continue
		if str(entry.get("location", "")) != "sled_hill" or bool(entry.get("hidden", false)):
			continue
		live[id] = true
		if _ghosts.has(id) and is_instance_valid(_ghosts[id]):
			continue
		var ghost := sled.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as CharacterBody3D
		ghost.name = "Guest%s" % id
		ghost.set_meta("remote_peer", id)
		add_child(ghost)
		ghost.reset_run(_lane(id))
		ghost.apply_identity(str(entry.get("name", "Penguin")), int(entry.get("color", 0)))
		_ghosts[id] = ghost
		print("Sled sees %s (%s)" % [str(entry.get("name", "Penguin")), id])
	var stale: Array = []
	for id in _ghosts.keys():
		if not live.has(int(id)):
			stale.append(int(id))
	for id in stale:
		var node: Node = _ghosts[id]
		_ghosts.erase(id)
		if is_instance_valid(node):
			node.queue_free()


func _clear_ghosts() -> void:
	for id in _ghosts.keys():
		var node: Node = _ghosts[id]
		if is_instance_valid(node):
			node.queue_free()
	_ghosts.clear()


func _lane(peer_id: int) -> Vector3:
	var ids: Array[int] = []
	if Net.is_online():
		for entry in Net.roster():
			if str(entry.get("location", "")) == "sled_hill" and not bool(entry.get("hidden", false)):
				ids.append(int(entry.get("id", 0)))
	if not ids.has(peer_id):
		ids.append(peer_id)
	ids.sort()
	var index := ids.find(peer_id)
	var span := 1.8
	var origin := -span * float(ids.size() - 1) * 0.5
	return Vector3(origin + span * float(index), 0.2, 12.0)


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
