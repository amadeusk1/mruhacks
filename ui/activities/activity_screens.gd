extends Node
## ActivityScreens autoload: opens the activity/wardrobe/home screens.
## - Town interactables call Activities.request(activity, ...); we open the matching screen.
## - HUD dock buttons (Outfit / Home) call ActivityScreens.open("wardrobe" | "home_edit" | ...).
## Screens go on the UIRouter stack, so Escape closes them and world input is suppressed meanwhile.

const SCREENS := {
	"wardrobe": "res://ui/activities/wardrobe/wardrobe.gd",
	"inventory": "res://ui/activities/wardrobe/inventory.gd",
	"home_choose": "res://ui/activities/home/home_select.gd",
	"home_visitors": "res://ui/activities/home/home_select.gd",
	"cinema": "res://ui/activities/cinema/cinema_ui.gd",
	"arcade": "res://ui/activities/arcade/arcade_ui.gd",
	"sketch": "res://ui/activities/sketch/sketch_ui.gd",
	"snowballs": "res://ui/activities/winter/winter_ui.gd",
	"basketball": "res://ui/activities/winter/winter_ui.gd",
}

var _open: Control


func _ready() -> void:
	var acts := get_node_or_null("/root/Activities")
	if acts:
		acts.requested.connect(func(activity: String, _anchor: Node, _player: Node) -> void: open(activity))


func handles(activity: String) -> bool:
	return SCREENS.has(activity)


func open(screen: String) -> Control:
	if screen == "home_edit":
		return _open_home_edit()
	if not SCREENS.has(screen):
		return null
	if is_instance_valid(_open):
		_open.queue_free()
	var c: Control = (load(SCREENS[screen]) as GDScript).new()
	match screen:
		"home_visitors":
			c.set("mode", "visitors")
		"snowballs":
			# shortcut: no match server yet; lobby shows you alone until a session layer fills teams
			c.set("state", {"mode": "lobby", "coral": [Net.local_profile()["name"]], "teal": [], "waiting": true})
		"basketball":
			c.set("state", {"mode": "court", "score": 0, "time_left": 60.0, "standings": [[Net.local_profile()["name"], 0]], "power": 0.0, "band": [0.62, 0.78]})
	if screen == "sketch":
		_wire_sketch(c)
	if c.has_signal("intent"):
		c.connect("intent", func(action: String, _v = null) -> void:
			if action in ["leave", "close", "leave_seat"] and is_instance_valid(c):
				c.queue_free())
	c.tree_exiting.connect(func() -> void: UIRouter.remove(c))
	UIRouter.push(c)
	_open = c
	return c


## Sketch Club runs on the real SketchClub session: seated players join the table, everyone
## else watches (lobby/progress/reveal). Leaving frees the seat and the slot.
func _wire_sketch(c: Control) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	var seated := player != null and player.has_method("is_sitting") and bool(player.call("is_sitting"))
	if seated:
		SketchClub.join()
	c.connect("intent", _sketch_intent.bind(player))
	var push := func(v: Dictionary) -> void:
		if is_instance_valid(c) and not v.is_empty():
			c.call("apply_state", v)
	SketchClub.view_changed.connect(push)
	c.tree_exiting.connect(func() -> void: SketchClub.view_changed.disconnect(push))
	if not SketchClub.view.is_empty():
		push.call(SketchClub.view)
	elif not seated:
		c.call("apply_state", {"phase": "lobby", "players": [], "seated": false})


func _sketch_intent(action: String, v: Variant, player: Node) -> void:
	match action:
		"ready":
			SketchClub.ready()
		"submit_text":
			SketchClub.submit_text(str(v))
		"submit_drawing":
			SketchClub.submit_drawing(v)
		"next_entry":
			SketchClub.next_entry()
		"play_again":
			SketchClub.play_again()
		"leave":
			SketchClub.leave()
			if is_instance_valid(player) and player.has_method("stand_up") and bool(player.call("is_sitting")):
				player.call("stand_up")


## Decorate the interior the local player is standing in. Only their own home.
func _open_home_edit() -> Control:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or str(world.call("current_location_id")) != "home":
		return null
	if int(world.call("home_owner_id")) != Net.local_id():
		return null
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	var room: Node3D = null
	var best := INF
	for n in get_tree().root.find_children("snow_dome_interior*", "Node3D", true, false):
		var d := INF if player == null else player.global_position.distance_to((n as Node3D).global_position)
		if d < best:
			best = d
			room = n
	var cam := get_viewport().get_camera_3d()
	if room == null or cam == null or best > 5.0:
		push_warning("home_edit: no home interior loaded")
		return null
	var ui: Control = (load("res://ui/activities/home/decor_ui.gd") as GDScript).new()
	UIRouter.push(ui)
	ui.tree_exiting.connect(func() -> void: UIRouter.remove(ui))
	ui.call("start", room, "homes/snow_dome_interior", cam)
	_open = ui
	return ui
