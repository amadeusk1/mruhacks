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
	if c.has_signal("intent"):
		c.connect("intent", func(action: String, _v = null) -> void:
			if action in ["leave", "close", "leave_seat"] and is_instance_valid(c):
				c.queue_free())
	c.tree_exiting.connect(func() -> void: UIRouter.remove(c))
	UIRouter.push(c)
	_open = c
	return c


## Decorate the current home interior (the teammate's home scene spawns homes/snow_dome_interior).
func _open_home_edit() -> Control:
	var room: Node3D = null
	for n in get_tree().root.find_children("snow_dome_interior*", "Node3D", true, false):
		room = n
		break
	var cam := get_viewport().get_camera_3d()
	if room == null or cam == null:
		push_warning("home_edit: no home interior loaded")
		return null
	var ui: Control = (load("res://ui/activities/home/decor_ui.gd") as GDScript).new()
	UIRouter.push(ui)
	ui.tree_exiting.connect(func() -> void: UIRouter.remove(ui))
	ui.call("start", room, "homes/snow_dome_interior", cam)
	_open = ui
	return ui
