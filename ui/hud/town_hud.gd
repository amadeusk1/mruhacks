class_name TownHud
extends Control
## In-world HUD (board "Town HUD Map and Social", panel 1): location chip, mic state, a compact dock
## (Map / Outfit / Home / Friends / Emotes) and one contextual action for the nearest door/activity.
## Lives under the teammate's PlayHud, so it shows and hides with it.

const T := preload("res://ui/theme/ui_tokens.gd")
const RANGE := 3.4
## Interactable activity / location / title → dock icon
const ICONS := {
	"cinema": "film", "cinema_lobby": "film", "café": "cup", "cafe": "cup", "cafe_interior": "cup",
	"arcade": "joystick", "arcade_interior": "joystick", "home": "home", "homes": "home",
	"fishing": "fish", "basketball": "ball", "sketch": "brush", "snowballs": "snowflake", "sled": "sled",
}
## destinations shown on the map and used for the location chip: marker → (label, icon)
const PLACES := {
	"Spawn": ["Plaza", "pin"], "CafeDoor": ["Café", "cup"], "CinemaDoor": ["Cinema", "film"],
	"ArcadeDoor": ["Arcade", "joystick"], "HomesGate": ["Homes", "home"], "SketchEntry": ["Sketch Club", "brush"],
	"SledStart": ["Sled Hill", "sled"], "ArenaGate": ["Snowballs", "snowflake"], "CourtEntry": ["Court", "ball"],
	"FishingSpot0": ["Fishing", "fish"],
}

var _chip: PanelContainer
var _chip_label: Label
var _mic: Button
var _action: IconTextButton
var _action_target: Node3D
var _action_kind := ""
var _tick := 0.0


func _ready() -> void:
	add_to_group("town_hud")
	theme = UIKit.THEME
	UIKit.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ControlsScreen.ensure_actions()
	_chip = UIKit.chip("Town", "pin", 30)
	_chip_label = _chip.find_children("*", "Label", true, false)[0]
	_chip.position = Vector2(22, 20)
	add_child(_chip)
	_mic = UIKit.icon_button("mic" if UIRouter.settings["mic"] else "mic_off", "Microphone", 80)
	_mic.theme_type_variation = "DockButton"
	_mic.expand_icon = true
	_mic.add_theme_constant_override("icon_max_width", 0)
	UIKit.pin(_mic, Vector2(1, 0), Vector2(-62, 62), Vector2(80, 80))
	_mic.pressed.connect(func() -> void:
		var m := MicrophoneScreen.new()
		m.closed.connect(_refresh_mic)
		UIRouter.push(m))
	add_child(_mic)
	var coin := get_parent().get_node_or_null("CoinBadge") as Control
	if coin:  # teammate's coin badge moves left of the mic button
		coin.offset_left -= 104
		coin.offset_right -= 104
	var dock := UIKit.hbox(14)
	for it in [["Map", "map", _open_map], ["Outfit", "shirt", _open_outfit], ["Home", "home", _go_home],
			["Friends", "friends", _open_friends], ["Emotes", "smile", _open_emotes]]:
		var b := UIKit.dock_button(it[0], it[1])
		b.pressed.connect(it[2])
		dock.add_child(b)
	add_child(UIKit.pin(dock, Vector2(0.5, 1), Vector2(142, -74), Vector2(806, 104)))
	_action = UIKit.button("Enter café", "primary", "cup", Vector2(300, 84)) as IconTextButton
	for st in ["normal", "hover", "pressed"]:
		var sb := (UIKit.THEME.get_stylebox(st, "PrimaryButton") as StyleBoxFlat).duplicate()
		sb.set_border_width_all(5)
		sb.border_color = Color.WHITE
		sb.set_corner_radius_all(26)
		_action.add_theme_stylebox_override(st, sb)
	_action.visible = false
	_action.pressed.connect(_do_action)
	add_child(UIKit.pin(_action, Vector2(0.5, 0.5), Vector2(300, -20), Vector2(320, 84)))
	UIRouter.stack_changed.connect(_refresh_mic)


func _refresh_mic() -> void:
	_mic.icon = UIKit.icon("mic" if UIRouter.settings["mic"] else "mic_off")


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.15
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null or not player.is_visible_in_tree():
		_action.visible = false
		return
	_update_chip(player)
	_update_action(player)


func _room() -> Node:
	var w := get_tree().get_first_node_in_group("world")
	return w.get_node_or_null("LocationHost").get_child(0) if w and w.get_node_or_null("LocationHost") and w.get_node("LocationHost").get_child_count() > 0 else null


func _location_id() -> String:
	var w := get_tree().get_first_node_in_group("world")
	return str(w.call("current_location_id")) if w and w.has_method("current_location_id") else ""


func _update_chip(player: Node3D) -> void:
	var id := _location_id()
	var text := LocationCatalog.title_of(id) if LocationCatalog.has_location(id) else "Pengloo Party"
	var room := _room()
	if id == LocationCatalog.MAIN and room:
		var best := INF
		for mname in PLACES:
			var m := room.get_node_or_null(mname) as Node3D
			if m:
				var d := _flat(m.global_position - player.global_position)
				if d < best:
					best = d
					text = "Town Plaza" if mname == "Spawn" else PLACES[mname][0]
		if best > 14.0:
			text = "Town"
	_chip_label.text = text


func _update_action(player: Node3D) -> void:
	var w := get_tree().get_first_node_in_group("world")
	if UIRouter.is_open() or (w and w.has_method("is_bus_menu_open") and bool(w.call("is_bus_menu_open"))):
		_action.visible = false
		return
	# the scene builder's Interactables (doors, activity entrances) and the teammate's bus stop
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactables") + get_tree().get_nodes_in_group("bus_stop"):
		if not n.has_method("can_interact") or not bool(n.call("can_interact")):
			continue
		var d := _flat((n as Node3D).global_position - player.global_position)
		if d < best_d:
			best_d = d
			best = n
	_action_target = best
	_action.visible = best != null
	if best == null:
		return
	if best.is_in_group("bus_stop"):
		_action_kind = "bus"
		_action.set_caption("Take the bus")
		_action._icon_rect.texture = UIKit.icon("bus")
		return
	_action_kind = "interactable"
	_action.set_caption(str(best.call("prompt_text")) if best.has_method("prompt_text") else "Enter")
	var key := str(best.get("activity")) if str(best.get("activity")) != "" else str(best.get("location"))
	_action._icon_rect.texture = UIKit.icon(ICONS.get(key, ICONS.get(str(best.get("title")).to_lower(), "door")))


func _do_action() -> void:
	if _action_target == null:
		return
	if _action_kind == "bus" and _action_target.has_method("try_open"):
		_action_target.call("try_open")
	elif _action_target.has_method("interact"):
		_action_target.call("interact", get_tree().get_first_node_in_group("local_player"))


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _unhandled_input(event: InputEvent) -> void:
	if UIRouter.is_open() or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("open_map"):
		_open_map()
	elif event.is_action_pressed("open_emotes"):
		_open_emotes()


# ---- dock ------------------------------------------------------------------------------
func _open_map() -> void:
	UIRouter.push(MapScreen.new())


func _open_outfit() -> void:
	if not UIScreens.open("wardrobe"):
		UIWidgets.toast(self, "The wardrobe opens soon.", "shirt")


func _go_home() -> void:
	var w := get_tree().get_first_node_in_group("world")
	if w and w.has_method("travel_to"):
		w.call("travel_to", "home", "BusArrival")


func _open_friends() -> void:
	UIRouter.push(FriendsPanel.make())


func _open_emotes() -> void:
	UIRouter.push(EmotePicker.new())


func debug_open(s: String) -> void:
	match s:
		"map": _open_map()
		"friends": _open_friends()
		"emotes": _open_emotes()
		"player_card": UIRouter.push(PlayerCard.make({"id": 2, "name": "Milo", "color": 1, "location": "town"}))
		"results": ResultsScreen.show_results("Round complete", [
			{"name": "You", "score": 6, "team": "coral", "color": 0}, {"name": "Milo", "score": 4, "team": "teal", "color": 1}],
			func() -> void: pass, func() -> void: pass, "Reusable result layout for court and snowballs.")
