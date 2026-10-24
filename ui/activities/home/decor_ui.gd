extends Control
## "Make it home" overlay (Images/UI - Home Decoration.png): Home HUD -> Decorate -> blocked
## placement -> selected object & save. Drives a DecorEditor on the current interior shell.
## Clicks on empty space pass through to the 3D room; panels stop them.

signal closed

const A := preload("res://ui/activities/act_style.gd")
const CATS := [["Seating", "sofa"], ["Tables", "table"], ["Lights", "lamp"], ["Plants", "plant"], ["Wall", "frame"], ["Rugs", "rug"], ["More", "plus"]]
const SWATCHES := ["#E86D58", "#2FA3A3", "#3D7BD9", "#5DAA3C", "#E3A92B", "#7B4FC4", "#F3E2C5", "#3A3D44"]

var editor: DecorEditor
var home_name := "My Home"
var home_kind := "Cozy Cottage"
var _mode := "home"            ## home | decorate | selected
var _cat := "Seating"
var _catalog := {}             ## category -> [asset ids]
var _pick := ""
var _hud: Control
var _deco: Control
var _rail: VBoxContainer
var _strip: HBoxContainer
var _ghost_bar: HBoxContainer
var _place_btn: Button
var _bubble: PanelContainer
var _bubble_text: Label
var _sel_bar: PanelContainer
var _undo_btn: Button
var _toast: PanelContainer
var _toast_text: Label
var _swatches: PanelContainer
var _visitors_on := true
var _grid: MeshInstance3D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_catalog()
	_build_hud()
	_build_decorate()
	_show("home")


## Attach to a real interior: shell id like "homes/snow_dome_interior".
func start(room: Node3D, shell_id: String, camera: Camera3D, default_items: Array = []) -> void:
	editor = DecorEditor.new()
	room.add_child(editor)
	editor.setup(room, shell_id, camera)
	editor.load_layout(default_items)
	editor.ghost_changed.connect(_on_ghost)
	editor.selection_changed.connect(_on_selection)
	editor.saved.connect(_on_saved)
	editor.layout_changed.connect(func() -> void: _undo_btn.disabled = not editor.can_undo())


# ---------------------------------------------------------------- catalogue --
func _build_catalog() -> void:
	for c in CATS:
		_catalog[c[0]] = []
	for kit in ["room_kit", "home_themes"]:
		var f := FileAccess.open("res://Models/%s/manifest.json" % kit, FileAccess.READ)
		if f == null:
			continue
		for a in JSON.parse_string(f.get_as_text()):
			var id := str(a["id"])
			var pl = a.get("placement", {})
			var layer: String = str(pl.get("layer", "")) if pl is Dictionary else ""
			if layer == "" or layer == "surface":
				continue   # small decor goes on tables/shelves (surface slots), not the floor catalogue
			_catalog[_category(id.get_slice("/", 1), layer)].append(id)


static func _category(n: String, layer: String) -> String:
	if layer == "rug":
		return "Rugs"
	if layer == "wall":
		return "Wall"
	for k in ["chair", "sofa", "armchair", "stool", "beanbag", "pouf", "bench", "cushion", "seat"]:
		if n.contains(k):
			return "Seating"
	for k in ["table", "desk", "console"]:
		if n.contains(k):
			return "Tables"
	for k in ["lamp", "lantern", "stove", "light"]:
		if n.contains(k):
			return "Lights"
	for k in ["plant", "monstera", "flower", "planter"]:
		if n.contains(k):
			return "Plants"
	return "More"


# ---------------------------------------------------------------- HOME HUD --
func _build_hud() -> void:
	_hud = A.screen_root()
	add_child(_hud)
	var card := A.chip("", A.WHITE, A.NAVY, "", 18, Vector2(22, 12))
	card.get_child(0).queue_free()
	var row := A.hbox(16)
	card.add_child(row)
	row.add_child(A.icon("home", 46, A.CORAL))
	var txt := A.vbox(-2)
	row.add_child(txt)
	txt.add_child(A.label(home_name, 26, A.NAVY, true))
	txt.add_child(A.label(home_kind, 18, A.SUB))
	A.pin(_hud, card, Vector4(0, 0, 0, 0), Vector4(30, 28, 330, 118))
	var vis := A.chip("", A.WHITE, A.NAVY, "", 18, Vector2(26, 16))
	vis.get_child(0).queue_free()
	var vc := A.vbox(10)
	vis.add_child(vc)
	var vh := A.hbox(10)
	vh.add_child(A.icon("users", 26, A.NAVY))
	vh.add_child(A.label("Visitors", 21, A.NAVY, true))
	vc.add_child(vh)
	var sw := CheckButton.new()
	sw.button_pressed = _visitors_on
	sw.focus_mode = Control.FOCUS_ALL
	sw.tooltip_text = "Allow visitors"
	sw.toggled.connect(func(on: bool) -> void: _visitors_on = on)
	sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for k in ["checked", "unchecked"]:
		var tex := UIKit.icon("toggle_on" if k == "checked" else "toggle_off")
		if tex:
			sw.add_theme_icon_override(k, tex)
	sw.custom_minimum_size = Vector2(80, 44)
	sw.expand_icon = true
	vc.add_child(sw)
	A.pin(_hud, vis, Vector4(0, 0, 0, 0), Vector4(30, 250, 210, 372))
	var edit := A.button("Edit Home", "primary", "brush", 26, Vector2(270, 84))
	edit.pressed.connect(func() -> void: _show("decorate"))
	A.pin(_hud, edit, Vector4(0, 0, 0, 0), Vector4(30, 392, 300, 476))
	var x := A.close_disc(60)
	x.pressed.connect(_close)
	A.pin(_hud, x, Vector4(1, 0, 1, 0), Vector4(-88, 22, -28, 82))


# ---------------------------------------------------------------- DECORATE --
func _build_decorate() -> void:
	_deco = A.screen_root()
	add_child(_deco)
	var rail_p := A.chip("", A.WHITE, A.NAVY, "", 18, Vector2(12, 14))
	rail_p.get_child(0).queue_free()
	_rail = A.vbox(4)
	rail_p.add_child(_rail)
	A.pin(_deco, rail_p, Vector4(0, 0, 0, 0), Vector4(16, 26, 216, 0))
	var strip_p := A.chip("", A.WHITE, A.NAVY, "", 18, Vector2(14, 12))
	strip_p.get_child(0).queue_free()
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(800, 136)
	strip_p.add_child(sc)
	_strip = A.hbox(12)
	sc.add_child(_strip)
	A.pin(_deco, strip_p, Vector4(0.5, 1, 0.5, 1), Vector4(-360, -178, 470, -20))
	var done := A.button("Done", "primary", "", 26, Vector2(160, 64))
	done.pressed.connect(_done)
	A.pin(_deco, done, Vector4(1, 0, 1, 0), Vector4(-268, 22, -100, 86))
	var x := A.close_disc(60)
	x.pressed.connect(_close)
	A.pin(_deco, x, Vector4(1, 0, 1, 0), Vector4(-88, 22, -28, 82))
	_undo_btn = A.chip_button("Undo", "undo", "light", 20)
	_undo_btn.disabled = true
	_undo_btn.pressed.connect(func() -> void: if editor: editor.undo())
	A.pin(_deco, _undo_btn, Vector4(0, 0, 0, 0), Vector4(232, 26, 362, 80))
	# ghost controls follow the ghost on screen
	_ghost_bar = A.hbox(16)
	_ghost_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rot := A.chip_button("Rotate", "rotate", "light", 20)
	rot.custom_minimum_size = Vector2(160, 62)
	rot.pressed.connect(func() -> void: if editor: editor.rotate_ghost())
	_ghost_bar.add_child(rot)
	_place_btn = A.button("Place", "primary", "check", 24, Vector2(200, 66))
	_place_btn.pressed.connect(func() -> void: if editor: editor.place_ghost())
	_ghost_bar.add_child(_place_btn)
	var cancel := A.chip_button("Cancel", "close", "light", 20)
	cancel.name = "Cancel"
	cancel.custom_minimum_size = Vector2(150, 62)
	cancel.pressed.connect(_cancel_ghost)
	_ghost_bar.add_child(cancel)
	_deco.add_child(_ghost_bar)
	_bubble = A.chip("", A.WHITE, Color("#D6453C"), "alert", 20, Vector2(20, 12))
	_bubble_text = _bubble.find_child("Text", true, false) as Label
	_deco.add_child(_bubble)
	# selected-object toolbar
	_sel_bar = A.chip("", A.WHITE, A.NAVY, "", 18, Vector2(18, 12))
	_sel_bar.get_child(0).queue_free()
	var tb := A.hbox(0)
	_sel_bar.add_child(tb)
	for t in [["Move", "move"], ["Rotate", "rotate"], ["Color", "palette"], ["Remove", "trash"]]:
		tb.add_child(_tool(t[0], t[1]))
	A.pin(_deco, _sel_bar, Vector4(0.5, 1, 0.5, 1), Vector4(-280, -176, 330, -20))
	_swatches = A.chip("", A.WHITE, A.NAVY, "", 18, Vector2(14, 12))
	_swatches.get_child(0).queue_free()
	var srow := A.hbox(10)
	_swatches.add_child(srow)
	for h in SWATCHES:
		srow.add_child(UIKit.swatch(Color(h), func() -> void: if editor: editor.recolor_selected(Color(h))))
	A.pin(_deco, _swatches, Vector4(0.5, 1, 0.5, 1), Vector4(-200, -250, 260, -188))
	_toast = A.chip("Saved!", A.WHITE, A.NAVY, "check_badge", 22, Vector2(20, 12))
	_toast_text = _toast.find_child("Text", true, false) as Label
	((_toast.get_child(0) as HBoxContainer).get_child(0) as TextureRect).modulate = Color("#18A36F")
	A.pin(_deco, _toast, Vector4(1, 0, 1, 0), Vector4(-250, 104, -36, 162))
	_toast.hide()
	_refresh_rail()


func _tool(text: String, icon_name: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "QuietButton"
	b.custom_minimum_size = Vector2(150, 118 if text == "Remove" else 118)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = text
	var v := A.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := A.icon(icon_name, 42, Color("#E2534A") if text == "Remove" else A.NAVY)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(A.label(text, 22, Color("#D6453C") if text == "Remove" else A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	if text == "Remove":
		v.add_child(A.label("Return to inventory", 15, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
		var hl := A.box(T_ROW_COLOR(), 14)
		b.add_theme_stylebox_override("normal", hl)
	b.pressed.connect(func() -> void: _on_tool(text))
	return b


static func T_ROW_COLOR() -> Color:
	return Color("#F6F1E8")


func _on_tool(t: String) -> void:
	if editor == null or editor.selected.is_empty():
		return
	match t:
		"Move":
			editor.begin_move(editor.selected)
			editor.select({})
		"Rotate":
			editor.rotate_ghost()
		"Color":
			_swatches.visible = not _swatches.visible
		"Remove":
			editor.remove_selected()


func _cancel_ghost() -> void:
	if editor:
		editor.cancel_ghost()
	_ghost_bar.hide()
	_bubble.hide()


func _pick_item(id: String) -> void:
	_pick = id
	_refresh_rail()
	if editor:
		editor.begin_place(id)


func _refresh_rail() -> void:
	for c in _rail.get_children():
		c.queue_free()
	for c in CATS:
		if _catalog.get(c[0], []).is_empty():
			continue
		var on: bool = c[0] == _cat
		var b := A.button(c[0], "ghost", c[1], 20, Vector2(176, 58))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 30)
		if on:
			b.add_theme_stylebox_override("normal", A.box(Color("#DCEFEC"), 14, 0, Color.TRANSPARENT, 14))
		b.pressed.connect(func() -> void: _cat = c[0]; _refresh_rail())
		_rail.add_child(b)
	for c in _strip.get_children():
		c.queue_free()
	for id in _catalog.get(_cat, []):
		var sel: bool = id == _pick
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 112)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = Outfit.pretty(str(id).get_slice("/", 1))
		b.add_theme_stylebox_override("normal", A.card_box(sel, 16))
		b.add_theme_stylebox_override("hover", A.card_box(sel, 16))
		b.add_theme_stylebox_override("pressed", A.card_box(true, 16))
		b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 18, 3, A.NAVY, 0))
		var t := TextureRect.new()
		t.texture = A.asset_icon(id)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.offset_left = 10; t.offset_top = 8; t.offset_right = -10; t.offset_bottom = -8
		b.add_child(t)
		b.pressed.connect(_pick_item.bind(id))
		_strip.add_child(b)


# ---------------------------------------------------------------- state --
func _show(mode: String) -> void:
	_mode = mode
	_hud.visible = mode == "home"
	_deco.visible = mode != "home"
	_sel_bar.visible = mode == "selected"
	_swatches.visible = false
	_ghost_bar.visible = editor != null and editor.has_ghost()
	_bubble.visible = false
	var strip_on := mode == "decorate"
	_strip.get_parent().get_parent().visible = strip_on
	_rail.get_parent().visible = strip_on
	_undo_btn.visible = mode == "selected"
	if editor:
		if mode != "home" and _grid == null:
			_grid = editor.make_grid()
			editor.room.add_child(_grid)
		if _grid:
			_grid.visible = mode != "home"   # grid only while editing


func _on_ghost(valid: bool, reason: String) -> void:
	_ghost_bar.visible = true
	_place_btn.disabled = not valid
	_ghost_bar.get_node("Cancel").visible = not valid
	_bubble.visible = not valid
	_bubble_text.text = reason


func _on_selection(it: Dictionary) -> void:
	_ghost_bar.visible = editor.has_ghost()
	_bubble.visible = false
	_show("selected" if not it.is_empty() else "decorate")


func _on_saved(ok: bool) -> void:
	_toast.show()
	_toast_text.text = "Saved!" if ok else "Save failed - Retry"
	var tw := create_tween()
	tw.tween_interval(2.4 if ok else 6.0)
	tw.tween_callback(_toast.hide)


func _process(_delta: float) -> void:
	if editor == null:
		return
	if _ghost_bar.visible and editor.has_ghost():
		var p := editor.ghost_screen_pos()
		_ghost_bar.reset_size()
		_ghost_bar.position = p + Vector2(-_ghost_bar.size.x * 0.5, 40)
		_bubble.reset_size()
		_bubble.position = p + Vector2(-_bubble.size.x * 0.5, -170)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "home" or editor == null:
		if event.is_action_pressed("ui_cancel") and _mode == "home":
			_close()
		return
	if event is InputEventMouseMotion:
		editor.hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if editor.has_ghost():
			editor.place_ghost()
		else:
			editor.select(editor.item_at(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		editor.rotate_ghost()
	elif event.is_action_pressed("ui_cancel"):
		if editor.has_ghost():
			_cancel_ghost()
		elif not editor.selected.is_empty():
			editor.select({})
		else:
			_done()
		get_viewport().set_input_as_handled()


func _done() -> void:
	if editor:
		editor.cancel_ghost()
		editor.select({})
		_toast.show()
		_toast_text.text = "Saving..."
		editor.save_layout()
	_show("home")
	_toast.reparent(_hud)


func _close() -> void:
	if editor and _mode != "home":
		_done()
	closed.emit()
	queue_free()


func close() -> void:   # UIRouter calls close() on Escape
	_close()


# ---------------------------------------------------------------- preview --
## Builds a lit dome interior with furniture and a penguin so the boards can be captured.
func preview(state: String) -> void:
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2C2018")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.86, 0.68)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	world.add_child(sun)
	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 2.0, 0.5)
	warm.light_color = Color(1.0, 0.78, 0.5)
	warm.light_energy = 1.4
	warm.omni_range = 6.0
	world.add_child(warm)
	var room := (load("res://Models/homes/snow_dome_interior.glb") as PackedScene).instantiate() as Node3D
	world.add_child(room)
	Tints.prepare(room)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0.6, 3.7, 3.6)
	cam.look_at(Vector3(0.2, 0.35, -0.4))
	cam.fov = 44
	cam.current = true
	start(room, "homes/snow_dome_interior", cam, [
		{"id": "room_kit/sofa_2seat", "cell": [6, 7], "rot": 0},
		{"id": "room_kit/rug_patchwork", "cell": [5, 5], "rot": 0},
		{"id": "room_kit/low_table_round", "cell": [5, 5], "rot": 0},
		{"id": "room_kit/floor_lamp", "cell": [8, 6], "rot": 0},
		{"id": "room_kit/plant_large", "cell": [3, 7], "rot": 0},
		{"id": "home_themes/wood_stove", "cell": [4, 8], "rot": 0},
		{"id": "room_kit/cube_shelf", "cell": [8, 4], "rot": 270},
	])
	var bird := AssetPack.spawn("anim_locomotion", "avatar_base")
	if bird:
		room.add_child(bird)
		bird.position = editor.cell_center(Vector2i(3, 5)) + Vector3(0, 0, 0)
		bird.rotation.y = 0.6
		var ap := bird.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("emote_wave"):
			ap.play("emote_wave")
	await get_tree().process_frame
	match state:
		"home":
			_show("home")
		"decorate":
			_show("decorate")
			_pick = "room_kit/armchair"
			_refresh_rail()
			editor.begin_place("room_kit/armchair")
			editor._update_ghost(Vector2i(4, 3), "")
		"blocked":
			_show("decorate")
			_pick = "room_kit/armchair"
			_refresh_rail()
			editor.begin_place("room_kit/armchair")
			editor._update_ghost(Vector2i(1, 5), "")
		"selected":
			_show("decorate")
			editor.select(editor.items[3])
			_undo_btn.disabled = false
			_on_saved(true)
