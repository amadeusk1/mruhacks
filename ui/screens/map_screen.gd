class_name MapScreen
extends UIModal
## Island map (board "Town HUD Map and Social", panel 2): a real top-down render of the town
## (ui/map/town_map.png, made by tools/map_capture.tscn) with cream destination chips and the
## player's dot. A chip takes you to that place.

const MAP_PNG := "res://ui/map/town_map.png"
const ANGLED_PNG := "res://ui/map/town_map_angled.png"   # default: illustrated three-quarter view
const ANGLED_JSON := "res://ui/map/town_map_angled.json"
const MAP_JSON := "res://ui/map/town_map.json"
const LAYOUT := "res://Models/world/town_layout.json"

var _view: MapView


func _init() -> void:
	setup("", "", 1220, false, false)
	var cc: Control = card.get_parent()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_left = 22
	cc.offset_right = -22
	cc.offset_top = 22
	cc.offset_bottom = -22
	card.custom_minimum_size = Vector2.ZERO if Mobile.active() else Vector2(1220, 670)
	var sb := (UIKit.THEME.get_stylebox("panel", "Card") as StyleBoxFlat).duplicate()
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	body.get_parent().get_child(0).custom_minimum_size.y = 0   # no header row: title floats over the map
	_view = MapView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(0, 480) if Mobile.active() else Vector2(1200, 650)
	body.add_child(_view)
	var title := UIKit.vbox(0)
	title.position = Vector2(40, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(UIKit.label("Pengloo Party", "TitleSmall"))
	title.add_child(UIKit.label("Tap a place to go there." if Mobile.active() else "Click a place to go there.", "Subtitle"))
	for child in title.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(title)
	var x := UIKit.icon_button("close", "Close map", 64)
	UIKit.pin(x, Vector2(1, 0), Vector2(-52, 50), Vector2(64, 64))
	x.pressed.connect(close)
	_view.add_child(x)


class MapView extends Control:
	var tex: Texture2D
	var bounds := Rect2(-40, -36, 80, 72)   # Godot x/z covered by the image
	var cam_xf: Transform3D                   # angled map camera (orthographic)
	var cam_size := 0.0
	var cam_aspect := 1.6
	## Map chip → [location id, spawn marker]. Town activities land on their marker.
	const TRIPS := {
		"Spawn": ["town", "Spawn"],
		"CafeDoor": ["cafe", "Inside"],
		"CinemaDoor": ["cinema", "InsideLobby"],
		"ArcadeDoor": ["arcade", "Inside"],
		"HomesGate": ["town", "HomesGate"],
		"SketchEntry": ["town", "SketchEntry"],
		"SledStart": ["sled_hill", "BusArrival"],
		"ArenaGate": ["town", "ArenaGate"],
		"CourtEntry": ["town", "CourtEntry"],
		"FishingSpot0": ["town", "FishingSpot0"],
		"@casino/casino_exterior": ["casino", "Inside"],
	}

	var _chips := []
	var _t := 0.0

	func _ready() -> void:
		clip_contents = true
		if ResourceLoader.exists(MapScreen.ANGLED_PNG) and FileAccess.file_exists(MapScreen.ANGLED_JSON):
			tex = load(MapScreen.ANGLED_PNG)
			var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapScreen.ANGLED_JSON))
			var v := func(k): return Vector3(c[k][0], c[k][1], c[k][2])
			cam_xf = Transform3D(Basis(v.call("x"), v.call("y"), v.call("z")), v.call("origin"))
			cam_size = float(c["size"])
			cam_aspect = float(c["aspect"])
		elif ResourceLoader.exists(MapScreen.MAP_PNG):
			tex = load(MapScreen.MAP_PNG)
		if FileAccess.file_exists(MapScreen.MAP_JSON):
			var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapScreen.MAP_JSON))
			bounds = Rect2(j["min"][0], j["min"][1], j["max"][0] - j["min"][0], j["max"][1] - j["min"][1])
		var layout = JSON.parse_string(FileAccess.get_file_as_string(MapScreen.LAYOUT)) if FileAccess.file_exists(MapScreen.LAYOUT) else {}
		var named := {}
		for m in (layout.get("markers", []) if layout is Dictionary else []):
			named[m["name"]] = Vector3(m["pos"][0], m["pos"][1], m["pos"][2])
		var here := _location_id()
		for key in TownHud.PLACES:
			var at = TownHud.place_position(key, layout if layout is Dictionary else {}, named)
			if at == null or not TRIPS.has(key):
				continue
			var it: Array = TownHud.PLACES[key]
			var chip := _place_button(str(it[0]), str(it[1]), key, here)
			add_child(chip)
			_chips.append([chip, at])
		if tex == null:
			add_child(UIKit.pin(UIWidgets.state_panel("empty", "Map not drawn yet", "Run tools/map_capture.tscn to render the island."),
				Vector2(0.5, 0.5), Vector2.ZERO, Vector2(420, 120)))
		resized.connect(_layout)
		_layout.call_deferred()

	func _place_button(place_name: String, icon_name: String, key: String, here: String) -> Button:
		var button := Button.new()
		button.text = place_name
		button.icon = UIKit.icon(icon_name)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var trip: Array = TRIPS[key]
		var here_now := str(trip[0]) == here and (str(trip[0]) != "town" or key == "Spawn")
		var base := UIKit.THEME.get_stylebox("panel", "Chip").duplicate() as StyleBoxFlat
		base.content_margin_left = 14
		base.content_margin_right = 16
		base.content_margin_top = 8
		base.content_margin_bottom = 8
		if here_now:
			base.border_color = Color("#1A9CA0")
			base.set_border_width_all(3)
		var hover := base.duplicate() as StyleBoxFlat
		hover.bg_color = base.bg_color.lightened(0.06)
		var pressed := base.duplicate() as StyleBoxFlat
		pressed.bg_color = base.bg_color.darkened(0.06)
		button.add_theme_stylebox_override("normal", base)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", base)
		button.add_theme_color_override("font_color", Color("#15274D"))
		button.add_theme_color_override("font_hover_color", Color("#15274D"))
		button.add_theme_color_override("font_pressed_color", Color("#15274D"))
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_go.bind(key))
		return button

	func _go(key: String) -> void:
		var trip: Array = TRIPS[key]
		var loc := str(trip[0])
		var spawn := str(trip[1])
		var world := get_tree().get_first_node_in_group("world")
		if world != null:
			var here := _location_id()
			if here == loc and loc == "town" and world.has_method("shift_to_marker"):
				world.call("shift_to_marker", spawn)
			elif here != loc and world.has_method("travel_to"):
				world.call("travel_to", loc, spawn)
		var screen := get_parent()
		while screen != null and not (screen is MapScreen):
			screen = screen.get_parent()
		if screen is MapScreen:
			(screen as MapScreen).close()

	func _location_id() -> String:
		var world := get_tree().get_first_node_in_group("world")
		if world != null and world.has_method("current_location_id"):
			return str(world.call("current_location_id"))
		return ""

	func _image_rect() -> Rect2:
		if tex == null:
			return Rect2(Vector2.ZERO, size)
		# cover the panel (crop the sea edges) so the island fills the frame like the mockup
		var s := maxf(size.x / tex.get_width(), size.y / tex.get_height())
		var sz := Vector2(tex.get_width(), tex.get_height()) * s
		return Rect2((size - sz) * 0.5, sz)

	func to_screen(p: Vector3) -> Vector2:
		var r := _image_rect()
		if cam_size > 0.0:  # orthographic projection through the angled render's camera
			var c := cam_xf.affine_inverse() * p
			var uv := Vector2(0.5 + c.x / (cam_size * cam_aspect), 0.5 - c.y / cam_size)
			return r.position + uv * r.size
		return r.position + (Vector2(p.x, p.z) - bounds.position) / bounds.size * r.size

	func _layout() -> void:
		for c in _chips:
			var chip: Control = c[0]
			var at := to_screen(c[1])
			chip.size = chip.get_combined_minimum_size()
			# keep chips inside the clipped view: the sled hill top sits above the map's top edge
			chip.position = (at - Vector2(chip.size.x * 0.5, chip.size.y + 10)).clamp(Vector2.ZERO, size - chip.size)
		queue_redraw()

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#5FC6D6")
		bg.set_corner_radius_all(20)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		if tex:
			draw_texture_rect(tex, _image_rect(), false)
		for c in _chips:  # small anchor dot under each chip
			var at := to_screen(c[1])
			draw_circle(at, 6, Color.WHITE)
			draw_circle(at, 4, Color("#15274D"))
		var player := get_tree().get_first_node_in_group("local_player") as Node3D
		if player and player.is_visible_in_tree():
			var at := to_screen(player.global_position)
			var pulse := 1.0 if UIRouter.settings.get("reduce_motion", false) else 1.0 + 0.25 * sin(_t * 4.0)
			draw_circle(at, 18 * pulse, Color(0.1, 0.61, 0.63, 0.25))
			draw_circle(at, 11, Color.WHITE)
			draw_circle(at, 8, Color("#1A9CA0"))
