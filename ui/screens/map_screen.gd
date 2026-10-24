class_name MapScreen
extends UIModal
## Island map (board "Town HUD Map and Social", panel 2): a real top-down render of the town
## (ui/map/town_map.png, made by tools/map_capture.tscn) with cream destination chips and the
## player's dot. Locating only: there is no teleport.

const MAP_PNG := "res://ui/map/town_map.png"
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
	card.custom_minimum_size = Vector2(1220, 670)
	var sb := (UIKit.THEME.get_stylebox("panel", "Card") as StyleBoxFlat).duplicate()
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	body.get_parent().get_child(0).custom_minimum_size.y = 0   # no header row: title floats over the map
	_view = MapView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(1200, 650)
	body.add_child(_view)
	var title := UIKit.vbox(0)
	title.position = Vector2(40, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(UIKit.label("Pengloo Party", "TitleSmall"))
	title.add_child(UIKit.label("Explore together", "Subtitle"))
	_view.add_child(title)
	var x := UIKit.icon_button("close", "Close map", 56)
	x.theme_type_variation = "DockButton"
	x.expand_icon = true
	UIKit.pin(x, Vector2(1, 0), Vector2(-48, 46), Vector2(56, 56))
	x.pressed.connect(close)
	_view.add_child(x)


class MapView extends Control:
	var tex: Texture2D
	var bounds := Rect2(-40, -36, 80, 72)   # Godot x/z covered by the image
	var places := []                          # [label, icon, Vector2 world xz]
	var _chips := []
	var _t := 0.0

	func _ready() -> void:
		clip_contents = true
		if ResourceLoader.exists(MapScreen.MAP_PNG):
			tex = load(MapScreen.MAP_PNG)
		if FileAccess.file_exists(MapScreen.MAP_JSON):
			var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapScreen.MAP_JSON))
			bounds = Rect2(j["min"][0], j["min"][1], j["max"][0] - j["min"][0], j["max"][1] - j["min"][1])
		var layout = JSON.parse_string(FileAccess.get_file_as_string(MapScreen.LAYOUT)) if FileAccess.file_exists(MapScreen.LAYOUT) else {}
		var named := {}
		for m in (layout.get("markers", []) if layout is Dictionary else []):
			named[m["name"]] = m["pos"]
		for mname in TownHud.PLACES:
			if named.has(mname):
				var p: Array = named[mname]
				var it: Array = TownHud.PLACES[mname]
				var chip := UIKit.chip(it[0], it[1], 20)
				chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(chip)
				_chips.append([chip, Vector2(p[0], p[2])])
		if tex == null:
			add_child(UIKit.pin(UIWidgets.state_panel("empty", "Map not drawn yet", "Run tools/map_capture.tscn to render the island."),
				Vector2(0.5, 0.5), Vector2.ZERO, Vector2(420, 120)))
		resized.connect(_layout)
		_layout.call_deferred()

	func _image_rect() -> Rect2:
		if tex == null:
			return Rect2(Vector2.ZERO, size)
		# cover the panel (crop the sea edges) so the island fills the frame like the mockup
		var s := maxf(size.x / tex.get_width(), size.y / tex.get_height())
		var sz := Vector2(tex.get_width(), tex.get_height()) * s
		return Rect2((size - sz) * 0.5, sz)

	func to_screen(xz: Vector2) -> Vector2:
		var r := _image_rect()
		return r.position + (xz - bounds.position) / bounds.size * r.size

	func _layout() -> void:
		for c in _chips:
			var chip: Control = c[0]
			var at := to_screen(c[1])
			chip.size = chip.get_combined_minimum_size()
			chip.position = at - Vector2(chip.size.x * 0.5, chip.size.y + 10)
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
			var at := to_screen(Vector2(player.global_position.x, player.global_position.z))
			var pulse := 1.0 + 0.25 * sin(_t * 4.0)
			draw_circle(at, 18 * pulse, Color(0.1, 0.61, 0.63, 0.25))
			draw_circle(at, 11, Color.WHITE)
			draw_circle(at, 8, Color("#1A9CA0"))
