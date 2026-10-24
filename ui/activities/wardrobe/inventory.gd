extends Control
## Inventory (search, category chips, item grid, detail + action), per Images/UI - Wardrobe and Inventory.png.
## Wearables Equip into their outfit slot; furniture and decor say "Place in home" (Remove returns them here).
## shortcut: owns every catalogue item (no unlock/economy system exists); swap ITEMS for the player's
## real inventory once a profile service stores owned items.

signal closed
signal place_requested(asset_id: String)

const A := preload("res://ui/activities/act_style.gd")
const CATS := ["All", "Clothing", "Props"]
const PROPS := ["room_kit/mug", "room_kit/small_lantern", "room_kit/book_single", "room_kit/plush_penguin",
		"room_kit/cushion_round", "room_kit/tabletop_plant", "room_kit/candle", "room_kit/trophy", "room_kit/framed_photo"]
const BLURB := {
	"mug": "A cozy mug for cold days.", "scarf": "Snug and warm for windy walks.", "glasses": "See the island in style.",
	"backpack": "Room for snacks and treasures.", "fishing_rod": "For a quiet afternoon on the dock.",
	"small_lantern": "A warm glow for your shelf.", "book_single": "A good story for a snowy night.",
	"plush_penguin": "A tiny friend who looks familiar.", "wand": "Sparkles not included.",
}

var _look: Dictionary
var _cat := "All"
var _query := ""
var _selected := "avatar/mug"
var _grid: GridContainer
var _detail: VBoxContainer
var _preview: PenguinView
var _items: Array = []   # [{"id", "slot"}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	_look = Outfit.load_look()
	_collect()
	_preview = PenguinView.new()
	A.pin(self, _preview, Vector4(0.0, 0.0, 0.34, 1.0), Vector4(10, 0, 0, 0))
	var p := A.panel(28, 28)
	A.pin(self, p, Vector4(0.31, 0.03, 0.985, 0.97))
	var stack := Control.new()
	p.add_child(stack)
	var col := A.vbox(16)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(col)
	var x := A.close_button(48)
	A.pin(stack, x, Vector4(1, 0, 1, 0), Vector4(-40, -14, 8, 34))
	x.pressed.connect(func() -> void: closed.emit(); queue_free())
	col.add_child(A.title("Inventory", 40))
	var pill := PanelContainer.new()
	var sb := A.box(A.WHITE, 24, 2, A.IVORY_EDGE, 0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	pill.add_theme_stylebox_override("panel", sb)
	col.add_child(pill)
	var srow := A.hbox(10)
	pill.add_child(srow)
	srow.add_child(A.icon("search", 22, A.SUB))
	var search := LineEdit.new()
	search.placeholder_text = "Search items..."
	search.custom_minimum_size = Vector2(0, 46)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.flat = true
	search.add_theme_font_override("font", A.body_font())
	search.add_theme_font_size_override("font_size", 19)
	search.add_theme_color_override("font_color", A.NAVY)
	search.add_theme_color_override("font_placeholder_color", A.MUTED)
	search.text_changed.connect(func(t: String) -> void: _query = t.to_lower(); _fill())
	search.focus_entered.connect(func() -> void: sb.border_color = A.TEAL)
	search.focus_exited.connect(func() -> void: sb.border_color = A.IVORY_EDGE)
	srow.add_child(search)
	var chips := A.hbox(12)
	col.add_child(chips)
	for c in CATS:
		var b := A.tab(c, "", c == _cat)
		b.custom_minimum_size = Vector2(120, 44)
		b.pressed.connect(func() -> void: _cat = c; _rebuild_chips(chips); _fill())
		chips.add_child(b)
	var row := A.hbox(22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 2.15
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", A.box(A.CARD, 20, 0, Color.TRANSPARENT, 18))
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dp)
	_detail = A.vbox(10)
	dp.add_child(_detail)
	_fill()


func _rebuild_chips(chips: HBoxContainer) -> void:
	for i in chips.get_child_count():
		var b := chips.get_child(i) as Button
		var on: bool = CATS[i] == _cat
		b.add_theme_stylebox_override("normal", A.box(A.TEAL if on else A.GREY, 16, 0, Color.TRANSPARENT, 14))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, A.WHITE if on else A.NAVY)


func _collect() -> void:
	var f := FileAccess.open("res://Models/avatar/manifest.json", FileAccess.READ)
	if f:
		for a in JSON.parse_string(f.get_as_text()):
			if str(a.get("slot", "")) in Outfit.SLOTS:
				_items.append({"id": str(a["id"]), "slot": str(a["slot"])})
	for pid in PROPS:
		if ResourceLoader.exists("res://Models/%s.glb" % pid):
			_items.append({"id": pid, "slot": ""})


func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for it in _items:
		var wearable: bool = it["slot"] != ""
		if _cat == "Clothing" and not wearable or _cat == "Props" and wearable:
			continue
		var nm := Outfit.pretty(str(it["id"]).get_slice("/", 1))
		if _query != "" and not nm.to_lower().contains(_query):
			continue
		_grid.add_child(_card(it, nm))
	_show_detail()
	_preview.set_look(Outfit.coat(_look), Outfit.pieces(_look))


func _card(it: Dictionary, nm: String) -> Button:
	var sel: bool = it["id"] == _selected
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 124)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", A.card_box(sel, 16))
	b.add_theme_stylebox_override("hover", A.card_box(sel, 16))
	b.add_theme_stylebox_override("pressed", A.card_box(true, 16))
	b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 18, 3, A.NAVY, 0))
	b.tooltip_text = nm
	b.pressed.connect(func() -> void: _selected = it["id"]; _fill())
	var v := A.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 8
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := TextureRect.new()
	t.texture = A.asset_icon(it["id"])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var l := A.label(nm, 16, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	if sel:
		A.pin(b, A.check_badge(28), Vector4(1, 0, 1, 0), Vector4(-24, -8, 4, 20))
	return b


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var it := {}
	for i in _items:
		if i["id"] == _selected:
			it = i
	if it.is_empty():
		_detail.add_child(A.label("Pick an item to see it here.", 18, A.SUB))
		return
	var short := str(it["id"]).get_slice("/", 1)
	_detail.add_child(A.title(Outfit.pretty(short), 32))
	var blurb := A.label(BLURB.get(short, "Wear it around town." if it["slot"] != "" else "Place it in your home."), 18, A.SUB)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(blurb)
	var t := TextureRect.new()
	t.texture = A.asset_icon(it["id"])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.y = 120
	_detail.add_child(t)
	var act: Button
	if it["slot"] != "":
		var worn: bool = str(_look.get(it["slot"], "")) == short
		act = A.button("Unequip" if worn else "Equip", "secondary" if worn else "primary", "", 26, Vector2(0, 70))
		act.pressed.connect(func() -> void:
			_look[it["slot"]] = "" if worn else short
			Outfit.save_look(_look)
			Outfit.apply_to_local_player(get_tree(), _look)
			_fill())
	else:
		act = A.button("Place in home", "primary", "home", 22, Vector2(0, 70))
		act.pressed.connect(func() -> void: place_requested.emit(it["id"]))
	_detail.add_child(act)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()


func preview(_state: String) -> void:
	_look = Outfit.DEFAULT.duplicate()
	_look["hand"] = "mug"
	_selected = "avatar/mug"
	_fill()
