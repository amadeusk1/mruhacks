extends "res://tools/film_host.gd"

## Minigame shot: the host sits down at an arcade cabinet and plays its game through the real
## cabinet screen. fish: swims at the nearest smaller fish and away from bigger ones and jellyfish.
## star: sweeps the ship side to side, firing. trails: solo practice on the duo cabinet (Snow
## Trails against the computer), the host's snowmobile steered by the game's own AI.
## FILM READY as the game starts, FILM DONE after LENGTH seconds.
##   BOTS=0 tools/film_shot.sh film_arcade out.mkv 14 --ui --bots=0 --game=fish
## --game: fish | star | trails. --shots=DIR saves a frame every half second (framing checks).

const SEATS := {"fish": "fish", "star": "star", "trails": "arcade"}  # SeatSpot activity per game
const LENGTH := 14.0

var _game := "fish"
var _bots := 4
var _shots := ""
var _ui: Control
var _t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--game="):
			_game = a.trim_prefix("--game=")
		elif a.begins_with("--bots="):
			_bots = int(a.trim_prefix("--bots="))
		elif a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	super._ready()
	while not _w.is_inside_tree() or not _w.get("_in_game") or _w.get("_traveling"):
		await get_tree().create_timer(0.5).timeout
	while _bots_here() < _bots:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.0).timeout
	_w.call("travel_to", "arcade", "Inside")
	while _w.call("current_location_id") != "arcade" or _w.get("_traveling"):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var me: CharacterBody3D = _w.get_node("Penguin")
	if not _keep_ui:
		me.get("agent").debug_enabled = false  # the orange path preview: real, but noisy on film
	var seat: SeatSpot
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is SeatSpot and str(node.get("activity")) == SEATS[_game]:
			seat = node
			break
	var pilot := preload("res://tools/seat_pilot.gd").new()
	pilot.kit = str(seat.get("kit"))
	pilot.near = seat.get("seat_point")
	pilot.active = true
	add_child(pilot)
	while _ui == null:
		for c in UIRouter.get_children():
			var path := str(c.get_script().resource_path) if c.get_script() else ""
			if path.ends_with("cabinet_play.gd") or path.ends_with("arcade_ui.gd"):
				_ui = c
		await get_tree().create_timer(0.3).timeout
	pilot.active = false
	await get_tree().create_timer(1.5).timeout  # the camera zooms onto the cabinet
	if _game == "trails":
		_ui.set("game", "trails")
		_ui.call("start_solo")
	print("FILM READY")
	if _shots != "":
		_shoot()
	await get_tree().create_timer(LENGTH).timeout
	print("FILM DONE")


func _process(delta: float) -> void:
	if _ui == null or not is_instance_valid(_ui):
		return
	_t += delta
	match _game:
		"fish":
			_fish()
		"star":
			_press("move_forward", 1.0)
			var right := fmod(_t, 2.4) < 1.2
			_press("move_right", 1.0 if right else 0.0)
			_press("move_left", 0.0 if right else 1.0)
		"trails":
			var board: Object = _ui.get("board")
			if board != null and board.get("local") != null:
				board.get("local").call("_ai", 0)


## Toward the nearest fish smaller than us, away from anything that could eat us.
func _fish() -> void:
	var game: Object = _ui.get("_game")
	if game == null:
		return
	var at: Vector2 = game.get("_pos")
	var size: float = (game.get("_SIZES") as Array)[int(game.get("_stage"))]
	var flee := Vector2.ZERO
	var prey := Vector2(0.5, 0.5) - at  # no prey in sight: drift back to the middle
	var best := INF
	for f in game.get("_fish"):
		var to: Vector2 = (f["p"] as Vector2) - at
		if bool(f.get("jelly", false)) or float(f["r"]) >= size:
			if to.length() < 0.18:
				flee -= to.normalized() * 2.0
		elif to.length() < best:
			best = to.length()
			prey = to
	var want := flee + prey.normalized()
	want = want.normalized()
	_press("move_right", maxf(want.x, 0.0))
	_press("move_left", maxf(-want.x, 0.0))
	_press("move_back", maxf(want.y, 0.0))
	_press("move_forward", maxf(-want.y, 0.0))


func _press(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _bots_here() -> int:
	var n := 0
	for puppet in (_w.get("_puppets") as Dictionary).values():
		if is_instance_valid(puppet) and puppet.visible:
			n += 1
	return n


func _shoot() -> void:
	for i in 28:
		get_viewport().get_texture().get_image().save_jpg("%s/arcade_%02d.jpg" % [_shots, i])
		await get_tree().create_timer(0.5).timeout
