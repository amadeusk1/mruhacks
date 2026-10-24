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
	"arcade": "joystick", "arcade_interior": "joystick", "home": "home", "homes": "home", "casino": "dice", "casino_interior": "dice",
	"fishing": "fish", "basketball": "ball", "sketch": "brush", "snowballs": "snowflake", "sled": "sled",
}
## destinations shown on the map and used for the location chip: marker → (label, icon)
const PLACES := {
	"Spawn": ["Plaza", "pin"], "CafeDoor": ["Café", "cup"], "CinemaDoor": ["Cinema", "film"],
	"ArcadeDoor": ["Arcade", "joystick"], "HomesGate": ["Homes", "home"], "SketchEntry": ["Sketch Club", "brush"],
	"SledStart": ["Sled Hill", "sled"], "ArenaGate": ["Snowballs", "snowflake"], "CourtEntry": ["Court", "ball"],
	"FishingSpot0": ["Fishing", "fish"], "@casino/casino_exterior": ["Casino", "dice"],
}
const LAYOUT := "res://Models/world/town_layout.json"


## Godot-space position of a PLACES key: a marker name, or "@kit/asset" = that placement's socket_door.
static func place_position(key: String, layout: Dictionary, markers: Dictionary) -> Variant:
	if not key.begins_with("@"):
		return markers.get(key)
	var id := key.substr(1)
	for p in layout.get("placements", []):
		if p["id"] != id:
			continue
		var at := Vector3(p["pos"][0], p["pos"][1], p["pos"][2])
		var sock := Vector3.ZERO
		var s = AssetRegistry.sockets(id).get("socket_door")
		if s != null:
			sock = Vector3(s[0], s[2], -s[1])   # Blender Z-up -> Godot Y-up
		return at + sock.rotated(Vector3.UP, deg_to_rad(float(p.get("rot_y_deg", 0))))
	return null

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
	var coin := get_parent().get_node_or_null("CoinBadge") as PanelContainer
	if coin:  # teammate's fishing coins: themed chip left of the mic button
		coin.offset_left -= 104
		coin.offset_right -= 104
		coin.offset_top = 20
		coin.offset_bottom = 84
		coin.add_theme_stylebox_override("panel", UIKit.THEME.get_stylebox("panel", "Chip"))
		var amount := coin.find_child("Amount", true, false) as Label
		if amount:
			amount.theme_type_variation = "Strong"
			amount.add_theme_font_size_override("font_size", 30)
			amount.add_theme_color_override("font_color", T.NAVY_TITLE)
	_restyle_chat()
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


## Teammate's chat box in the theme: ivory panel, navy text, bottom aligned with the dock. Visual only.
func _restyle_chat() -> void:
	var chat := get_parent().get_node_or_null("Chat") as Control
	if chat == null:
		return
	# bottom of the entry lines up with the dock's bottom edge (dock: 104 tall, 22 above screen edge)
	chat.offset_left = 22
	chat.offset_right = 22 + 372
	chat.offset_bottom = -22
	chat.offset_top = -22 - 214
	var log_panel := chat.get_node_or_null("Log") as PanelContainer
	if log_panel:
		var sb := (UIKit.THEME.get_stylebox("panel", "Card") as StyleBoxFlat).duplicate()
		sb.bg_color = Color(T.PANEL, 0.94)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		sb.set_corner_radius_all(20)
		log_panel.add_theme_stylebox_override("panel", sb)
		var lines := log_panel.find_child("Lines", true, false) as Label
		if lines:
			lines.add_theme_font_size_override("font_size", 20)
	var entry := chat.get_node_or_null("Entry") as LineEdit
	if entry:
		entry.custom_minimum_size.y = 58
		for st in ["normal", "focus"]:
			var e := (UIKit.THEME.get_stylebox(st, "LineEdit") as StyleBoxFlat).duplicate()
			e.set_corner_radius_all(18)
			e.bg_color = T.PANEL
			entry.add_theme_stylebox_override(st, e)
		entry.add_theme_color_override("font_color", T.NAVY)
		entry.add_theme_color_override("font_placeholder_color", T.MUTED)
		entry.add_theme_font_size_override("font_size", 21)


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
		for key in PLACES:
			var at = _place_world(key, room)
			if at != null:
				var d := _flat((at as Vector3) - player.global_position)
				if d < best:
					best = d
					text = "Town Plaza" if key == "Spawn" else PLACES[key][0]
		if best > 14.0:
			text = "Town"
	_chip_label.text = text


var _layout_cache := {}


func _place_world(key: String, room: Node) -> Variant:
	if not key.begins_with("@"):
		var m := room.get_node_or_null(key) as Node3D
		return m.global_position if m else null
	if _layout_cache.is_empty() and FileAccess.file_exists(LAYOUT):
		_layout_cache = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return place_position(key, _layout_cache, {})


func _update_action(player: Node3D) -> void:
	var w := get_tree().get_first_node_in_group("world")
	if UIRouter.is_open() or (w and w.has_method("is_bus_menu_open") and bool(w.call("is_bus_menu_open"))):
		_action.visible = false
		return
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactables"):
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
	_action_kind = "interactable"
	_action.set_caption(str(best.call("prompt_text")) if best.has_method("prompt_text") else "Enter")
	var key := str(best.get("activity")) if str(best.get("activity")) != "" else str(best.get("location"))
	_action._icon_rect.texture = UIKit.icon(ICONS.get(key, ICONS.get(str(best.get("title")).to_lower(), "door")))


func _do_action() -> void:
	if _action_target == null:
		return
	if _action_target.has_method("interact"):
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
