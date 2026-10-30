extends Control
## Wardrobe (Color / Hats / Clothes / Accessories / Pets) and Outfit Slots, per Images/UI - Wardrobe and Inventory.png.
## Changes preview live and reversibly; Done saves (Outfit) and re-dresses the local penguin; X cancels.

signal closed(saved: bool)

const A := preload("res://ui/activities/act_style.gd")
const Shop := preload("res://scripts/wardrobe_shop.gd")
const TABS := [["Color", "palette"], ["Hats", "hat"], ["Clothes", "shirt"], ["Accessories", "glasses"], ["Pets", "paw"]]
const TAB_SLOTS := {"Hats": ["head"], "Clothes": ["torso"], "Accessories": ["face", "neck", "back", "hand"]}
const COLOR_NAMES := ["Blue", "Green", "Yellow", "Pink", "Purple", "Orange"]
const SLOT_CARDS := [["Hat", "head"], ["Clothes", "torso"], ["Face", "face"], ["Back", "back"], ["Hand", "hand"]]

var mode := "wardrobe"          ## "wardrobe" or "slots"
var _look: Dictionary
var _saved: Dictionary
var _tab := "Hats"
var _slot_selected := "head"
var _preview: PenguinView
var _body: VBoxContainer
var _catalog := {}               # slot -> [asset names]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	_saved = Outfit.load_look()
	_look = _saved.duplicate()
	Shop.claim_worn(_saved)
	_load_catalog()
	_preview = PenguinView.new()
	_preview.turntable = true
	A.pin(self, _preview, Vector4(0.0, 0.0, 0.38, 1.0), Vector4(20, 0, 0, 0))
	var p := A.panel(30, 30)
	A.pin(self, p, Vector4(0.37, 0.035, 0.985, 0.965))
	var stack := Control.new()
	p.add_child(stack)
	_body = A.vbox(22)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_body)
	var x := A.close_button(48)
	A.pin(stack, x, Vector4(1, 0, 1, 0), Vector4(-40, -14, 8, 34))
	x.pressed.connect(_cancel)
	_rebuild()


func _load_catalog() -> void:
	var f := FileAccess.open("res://Models/avatar/manifest.json", FileAccess.READ)
	if f == null:
		return
	for a in JSON.parse_string(f.get_as_text()):
		var slot := str(a.get("slot", ""))
		if slot in Outfit.SLOTS:
			if not _catalog.has(slot):
				_catalog[slot] = []
			_catalog[slot].append(str(a["id"]).get_slice("/", 1))


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	_preview.set_look(Outfit.coat(_look), Outfit.pieces(_look))
	_preview.set_pet(str(_look.get("pet", "")), Outfit.coat(_look))
	if mode == "slots":
		_build_slots()
	else:
		_build_wardrobe()


# ------------------------------------------------------------- wardrobe tabs --
func _build_wardrobe() -> void:
	var tabs := A.hbox(8)
	tabs.custom_minimum_size.y = 62
	_body.add_child(tabs)
	for t in TABS:
		var b := A.tab(t[0], t[1], t[0] == _tab)
		b.add_theme_font_size_override("font_size", 17)  # five tabs fit beside the close button
		b.add_theme_constant_override("icon_max_width", 20)
		b.add_theme_constant_override("h_separation", 6)
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			if b.has_theme_stylebox_override(s):
				var box := b.get_theme_stylebox(s).duplicate()
				box.content_margin_left = 8
				box.content_margin_right = 8
				b.add_theme_stylebox_override(s, box)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _tab = t[0]; _rebuild())
		tabs.add_child(b)
	tabs.add_child(A.spacer(46))
	var wallet := A.label("Your coins: %d" % Pets.coins(get_tree()), 20, A.SUB)
	_body.add_child(wallet)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	scroll.add_child(grid)
	if _tab == "Color":
		for i in COLOR_NAMES.size():
			var view := PenguinView.new()
			view.framing = "full"
			view.custom_minimum_size = Vector2(150, 132)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var card := _card(COLOR_NAMES[i], null, int(_look["color"]) == i, _pick_color.bind(i), view)
			if not Shop.owns_color(i):
				card.add_child(_price_tag(Shop.color_price(i)))
			grid.add_child(card)
			view.call_deferred("set_look", Net.coat_color(i), {})
	elif _tab == "Pets":
		for p in Pets.catalog():
			var pet: String = p["id"]
			var card := _card(str(p["name"]), A.asset_icon("pets/" + pet), str(_look.get("pet", "")) == pet,
					func() -> void: _pick_pet(pet))
			card.tooltip_text = str(p["blurb"])
			if not Pets.owns(pet):
				card.add_child(_price_tag(int(p["price"])))
			grid.add_child(card)
	else:
		for slot in TAB_SLOTS[_tab]:
			for asset in _catalog.get(slot, []):
				var on: bool = str(_look.get(slot, "")) == asset
				var card := _card(Outfit.pretty(asset), A.asset_icon("avatar/" + asset), on, _pick_item.bind(slot, asset))
				if not Shop.owns_item(asset):
					card.add_child(_price_tag(Shop.item_price(asset)))
				grid.add_child(card)
	var foot := Control.new()
	foot.custom_minimum_size.y = 78
	_body.add_child(foot)
	var done := A.button("Done", "primary", "", 31, Vector2(412, 78))
	A.pin(foot, done, Vector4(0.5, 0, 0.5, 1), Vector4(-206, 0, 206, 0))
	done.pressed.connect(_done)
	var slots_link := A.chip_button("Slots", "shirt", "ghost", 15)
	slots_link.custom_minimum_size = Vector2(0, 40)
	slots_link.tooltip_text = "Outfit slots"
	A.pin(foot, slots_link, Vector4(1, 0.5, 1, 0.5), Vector4(-104, -20, 0, 20))
	slots_link.pressed.connect(func() -> void: mode = "slots"; _rebuild())


func _card(text: String, tex: Texture2D, selected: bool, on_press: Callable, art: Control = null) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 166)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", A.card_box(selected, 18))
	var hover := A.card_box(selected, 18)
	hover.bg_color = A.CARD_HOVER
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var focus := A.box(Color.TRANSPARENT, 20, 3, A.NAVY, 0)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(on_press)
	b.tooltip_text = text
	var v := A.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 10
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if art:
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(art)
	else:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
	var l := A.label(text, 20, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	if selected:
		var badge := A.check_badge(34)
		A.pin(b, badge, Vector4(1, 0, 1, 0), Vector4(-30, -10, 6, 26))
	return b


func _price_tag(price: int) -> Control:
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", A.box(Color("#F2C230"), 12, 0, Color.TRANSPARENT, 6))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := A.label("%d coins" % price, 16, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(l)
	tag.position = Vector2(10, 10)
	return tag


## Owned pets toggle on and off like clothes. Others ask to adopt first, then equip.
func _pick_pet(pet: String) -> void:
	if Pets.owns(pet):
		_look["pet"] = "" if str(_look.get("pet", "")) == pet else pet
		_rebuild()
		return
	var p := Pets.info(pet)
	var price := int(p.get("price", 0))
	var have := Pets.coins(get_tree())
	if have < price:
		UIWidgets.toast(self, "%s costs %d coins. You need %d more." % [p["name"], price, price - have], "alert")
		return
	var d := ConfirmDialog.ask("Adopt %s?" % p["name"], "%s\nSpend %d of your %d coins." % [p["blurb"], price, have],
			"Not now", "Adopt", "check")
	d.confirmed.connect(func() -> void:
		if Pets.buy(get_tree(), pet):
			_look["pet"] = pet
			UIWidgets.toast(self, "%s joined you!" % p["name"], "paw")
		_rebuild())


func _pick_color(index: int) -> void:
	if Shop.owns_color(index):
		_look["color"] = index
		_rebuild()
		return
	_ask_buy(COLOR_NAMES[index], Shop.color_price(index), func() -> void:
		if Shop.buy_color(get_tree(), index):
			_look["color"] = index
			UIWidgets.toast(self, "%s is yours." % COLOR_NAMES[index], "check")
		_rebuild())


func _pick_item(slot: String, asset: String) -> void:
	if Shop.owns_item(asset):
		_toggle(slot, asset)
		return
	var name := Outfit.pretty(asset)
	_ask_buy(name, Shop.item_price(asset), func() -> void:
		if Shop.buy_item(get_tree(), asset):
			_look[slot] = asset
			UIWidgets.toast(self, "%s is yours." % name, "check")
		_rebuild())


func _ask_buy(item_name: String, price: int, on_yes: Callable) -> void:
	var have := Pets.coins(get_tree())
	if have < price:
		UIWidgets.toast(self, "%s costs %d coins. You need %d more." % [item_name, price, price - have], "alert")
		return
	var d := ConfirmDialog.ask("Buy %s?" % item_name, "Spend %d of your %d coins." % [price, have],
			"Not now", "Buy", "check")
	d.confirmed.connect(on_yes)


func _toggle(slot: String, asset: String) -> void:
	_look[slot] = "" if str(_look.get(slot, "")) == asset else asset
	if slot == "head" and asset == "frog_hood":
		pass  # frog_hood covers the head; it simply replaces the hat in the single head slot
	_rebuild()


# ------------------------------------------------------------- outfit slots --
func _build_slots() -> void:
	_body.add_child(A.spacer(0, 6))
	_body.add_child(A.title("Outfit Slots", 44))
	_body.add_child(A.label("Equip and customize your look.", 22, A.SUB))
	_body.add_child(A.spacer(0, 26))
	var row := A.hbox(14)
	_body.add_child(row)
	var actions := A.hbox(14)
	for sc in SLOT_CARDS:
		var slot: String = sc[1]
		var asset := str(_look.get(slot, ""))
		var col := A.vbox(18)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 214)
		card.add_theme_stylebox_override("normal", A.card_box(slot == _slot_selected, 18))
		card.add_theme_stylebox_override("hover", A.card_box(slot == _slot_selected, 18))
		card.add_theme_stylebox_override("pressed", A.card_box(true, 18))
		card.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 20, 3, A.NAVY, 0))
		card.pressed.connect(func() -> void: _slot_selected = slot; _rebuild())
		col.add_child(card)
		var v := A.vbox(6)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_top = 12
		v.offset_bottom = -12
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var cap := A.label(sc[0], 21, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(cap)
		var t := TextureRect.new()
		t.texture = A.asset_icon("avatar/" + asset) if asset != "" else null
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if asset == "":
			var empty := PanelContainer.new()
			empty.add_theme_stylebox_override("panel", A.box(Color("#E9E1CF"), 14))
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ghost_icon := A.icon({"head": "hat", "torso": "shirt", "face": "glasses", "back": "lock", "hand": "plus"}[slot], 54, Color("#C9C0AE"))
			empty.add_child(ghost_icon)
			v.add_child(empty)
		else:
			v.add_child(t)
		var act: Button
		if asset != "" and slot == _slot_selected:
			act = A.button("Remove", "danger", "", 20, Vector2(0, 60))
			act.pressed.connect(func() -> void: _look[slot] = ""; _rebuild())
		else:
			act = A.button("", "secondary", "plus", 22, Vector2(0, 60))
			act.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			act.tooltip_text = "Choose " + sc[0]
			act.pressed.connect(func() -> void: _tab = _tab_for(slot); mode = "wardrobe"; _rebuild())
		col.add_child(act)
	_body.add_child(A.expander())
	var foot := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	_body.add_child(foot)
	var back := A.chip_button("Back to wardrobe", "arrow_left", "ghost", 18)
	back.pressed.connect(func() -> void: mode = "wardrobe"; _rebuild())
	foot.add_child(back)
	var done := A.button("Done", "primary", "", 26, Vector2(240, 62))
	done.pressed.connect(_done)
	foot.add_child(done)


func _tab_for(slot: String) -> String:
	for t in TAB_SLOTS:
		if slot in TAB_SLOTS[t]:
			return t
	return "Hats"


# ------------------------------------------------------------- save / cancel --
func _done() -> void:
	Outfit.save_look(_look)
	Outfit.apply_to_local_player(get_tree(), _look)
	Net.preferred_color = int(_look.get("color", 0))
	Net.publish_outfit(_look)
	closed.emit(true)
	queue_free()


func _cancel() -> void:
	closed.emit(false)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func preview(state: String) -> void:
	_look = Outfit.DEFAULT.duplicate()
	match state:
		"color":
			_tab = "Color"
		"slots":
			_look["hand"] = "mug"
			mode = "slots"
		_:
			_tab = "Hats"
	_rebuild()
