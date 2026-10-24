extends CanvasLayer

## Pet shop panel. Cream card, one selected pet, one button.
## The pen stays in the world behind it. Esc or the corner mark closes it.

const _NAVY := Color(0.10, 0.18, 0.28)
const _TEAL := Color(0.15, 0.62, 0.64)
const _TEAL_HOVER := Color(0.20, 0.70, 0.70)
const _TEAL_PRESS := Color(0.11, 0.48, 0.52)
const _IVORY := Color(0.98, 0.96, 0.91)
const _CARD := Color(0.965, 0.945, 0.90)
const _GREY := Color(0.78, 0.80, 0.82)
const _GOLD := Color(1.0, 0.78, 0.42)
const _GOLD_EDGE := Color(0.74, 0.53, 0.31)

var _open := false
var _selected := "pebble"
var _preview_id := ""
var _sig := ""
var _prompt_counter: Node = null

var _dimmer: ColorRect
var _panel: PanelContainer
var _pill: Button
var _coin_amount: Label
var _detail_name: Label
var _detail_line: Label
var _action: Button
var _viewport: SubViewport
var _cards: Dictionary = {}


func _ready() -> void:
	layer = 8
	_build()
	_set_open(false)


func is_open() -> bool:
	return _open


func open(shop_id: String) -> bool:
	if shop_id != "pets":
		return false
	if _selected == "":
		_selected = "pebble"
	_set_open(true)
	_sig = ""
	_apply()
	return true


func close() -> void:
	_set_open(false)


func _set_open(show_panel: bool) -> void:
	_open = show_panel
	_dimmer.visible = show_panel
	_panel.visible = show_panel
	if not show_panel:
		_pill.visible = false
		if _viewport:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(_delta: float) -> void:
	if _open:
		_pill.visible = false
		var sig := _signature()
		if sig != _sig:
			_sig = sig
			_apply()
		return
	var counter := _nearest_counter()
	_prompt_counter = counter
	_pill.visible = counter != null
	if counter != null:
		_pill.text = str(counter.get("prompt_text"))


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_cycle(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_cycle(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_action_pressed()


func _build() -> void:
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.08, 0.14, 0.22, 0.28)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dimmer)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.offset_left = -524.0
	_panel.offset_top = -300.0
	_panel.offset_right = -24.0
	_panel.offset_bottom = 300.0
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(_header())

	var subtitle := Label.new()
	subtitle.text = "One follows you home."
	subtitle.add_theme_color_override("font_color", Color(_NAVY, 0.72))
	subtitle.add_theme_font_size_override("font_size", 15)
	column.add_child(subtitle)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 8)
	body.add_child(cards)
	for id in PetCatalog.ORDER:
		cards.add_child(_card(id))

	body.add_child(_detail())

	_pill = Button.new()
	_pill.name = "LookPill"
	_pill.text = "Look at pets"
	_pill.focus_mode = Control.FOCUS_NONE
	_pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pill.offset_left = -110.0
	_pill.offset_top = -78.0
	_pill.offset_right = 110.0
	_pill.offset_bottom = -30.0
	_style_pill(_pill)
	_pill.pressed.connect(_on_pill_pressed)
	add_child(_pill)


func _header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "Pets"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", _NAVY)
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)

	var coins := HBoxContainer.new()
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	coins.add_theme_constant_override("separation", 8)
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(22, 22)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _disc_style())
	coins.add_child(disc)
	_coin_amount = Label.new()
	_coin_amount.name = "CoinAmount"
	_coin_amount.text = "0"
	_coin_amount.add_theme_color_override("font_color", _NAVY)
	_coin_amount.add_theme_font_size_override("font_size", 20)
	coins.add_child(_coin_amount)
	header.add_child(coins)

	var close := Button.new()
	close.name = "CloseButton"
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(36, 36)
	_style_close(close)
	close.pressed.connect(_request_close)
	header.add_child(close)
	return header


func _card(id: String) -> Button:
	var info := PetCatalog.find(id)
	var button := Button.new()
	button.name = "Card_%s" % id
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(230, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_card_pressed.bind(id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 10.0
	margin.offset_top = 8.0
	margin.offset_right = -10.0
	margin.offset_bottom = -8.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(36, 36)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_theme_stylebox_override("panel", _swatch_style(info.get("swatch", Color.WHITE)))
	row.add_child(swatch)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_row)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(info.get("name", "Pet"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", _NAVY)
	name_label.add_theme_font_size_override("font_size", 18)
	name_row.add_child(name_label)
	var mark := Panel.new()
	mark.name = "Mark"
	mark.custom_minimum_size = Vector2(14, 14)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_stylebox_override("panel", _swatch_style(_TEAL))
	name_row.add_child(mark)

	var price := Label.new()
	price.name = "Price"
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_size_override("font_size", 14)
	text.add_child(price)

	_cards[id] = {"button": button, "price": price, "mark": mark}
	return button


func _detail() -> VBoxContainer:
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(210, 0)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(210, 168)
	frame.add_theme_stylebox_override("panel", _preview_style())
	detail.add_child(frame)
	frame.add_child(_preview_view())

	_detail_name = Label.new()
	_detail_name.name = "DetailName"
	_detail_name.add_theme_color_override("font_color", _NAVY)
	_detail_name.add_theme_font_size_override("font_size", 22)
	detail.add_child(_detail_name)

	_detail_line = Label.new()
	_detail_line.name = "DetailBlurb"
	_detail_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_line.add_theme_color_override("font_color", Color(_NAVY, 0.78))
	_detail_line.add_theme_font_size_override("font_size", 15)
	detail.add_child(_detail_line)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(spacer)

	_action = Button.new()
	_action.name = "ActionButton"
	_action.focus_mode = Control.FOCUS_NONE
	_action.custom_minimum_size = Vector2(0, 46)
	_action.pressed.connect(_on_action_pressed)
	detail.add_child(_action)
	return detail


func _preview_view() -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(198, 156)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.size = Vector2i(396, 312)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.gui_disable_input = true
	box.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.93, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.96, 0.98)
	env.ambient_light_energy = 1.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	light.light_energy = 1.1
	_viewport.add_child(light)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.current = true
	camera.look_at_from_position(Vector3(0.0, 0.46, 1.08), Vector3(0.0, 0.18, 0.0))
	_viewport.add_child(camera)
	return box


func _apply() -> void:
	var world := _world()
	var coins := 0
	if world != null:
		coins = int(world.call("coin_balance"))
	_coin_amount.text = str(coins)
	var info := PetCatalog.find(_selected)
	_detail_name.text = str(info.get("name", "Pet"))
	_detail_line.text = str(info.get("line", ""))
	_mount_preview(_selected)
	_fill_action(world, info, coins)
	for id in PetCatalog.ORDER:
		_fill_card(id, world)


func _fill_card(id: String, world: Node) -> void:
	var row: Dictionary = _cards[id]
	var button := row["button"] as Button
	var price: Label = row["price"]
	var mark: Control = row["mark"]
	var info := PetCatalog.find(id)
	var owned := world != null and bool(world.call("owns_pet", id))
	var active := world != null and str(world.call("active_pet_id")) == id
	if active:
		price.text = "With you"
		price.add_theme_color_override("font_color", _TEAL)
	elif owned:
		price.text = "Yours"
		price.add_theme_color_override("font_color", _NAVY)
	else:
		price.text = str(int(info.get("price", 0)))
		price.add_theme_color_override("font_color", Color(_NAVY, 0.7))
	var selected := id == _selected
	mark.visible = selected
	var normal := _card_style(selected)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _card_style(true) if selected else _card_style(false, true))
	button.add_theme_stylebox_override("pressed", _card_style(true))
	button.add_theme_stylebox_override("focus", normal)


func _fill_action(world: Node, info: Dictionary, coins: int) -> void:
	var price := int(info.get("price", 0))
	var owned := world != null and bool(world.call("owns_pet", _selected))
	var active := world != null and str(world.call("active_pet_id")) == _selected
	var enabled := false
	if active:
		_action.text = "With you"
	elif owned:
		_action.text = "Call"
		enabled = true
	elif coins >= price:
		_action.text = "Buy · %d" % price
		enabled = true
	else:
		_action.text = "Need %d" % (price - coins)
	_action.disabled = not enabled
	_style_action(_action, enabled)


func _mount_preview(id: String) -> void:
	if _viewport == null or id == "":
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if _preview_id == id and _viewport.get_node_or_null("PreviewPet") != null:
		return
	var old := _viewport.get_node_or_null("PreviewPet")
	if old:
		old.free()
	var pet := Node3D.new()
	pet.name = "PreviewPet"
	pet.set_script(preload("res://scripts/pet_body.gd"))
	_viewport.add_child(pet)
	pet.call("setup", id, true)
	_preview_id = id


func _cycle(step: int) -> void:
	var index := PetCatalog.ORDER.find(_selected)
	if index < 0:
		index = 0
	var count := PetCatalog.ORDER.size()
	_selected = PetCatalog.ORDER[posmod(index + step, count)]
	_sig = ""
	_apply()


func _on_card_pressed(id: String) -> void:
	_selected = id
	_sig = ""
	_apply()


func _on_action_pressed() -> void:
	if _action.disabled:
		return
	var world := _world()
	if world == null:
		return
	if bool(world.call("owns_pet", _selected)):
		world.call("call_pet", _selected)
	else:
		world.call("buy_pet", _selected)
	_sig = ""
	_apply()


func _on_pill_pressed() -> void:
	if _prompt_counter != null and is_instance_valid(_prompt_counter) and _prompt_counter.has_method("try_open"):
		_prompt_counter.call("try_open")


func _request_close() -> void:
	var world := _world()
	if world != null and world.has_method("close_shop"):
		world.call("close_shop")
	else:
		close()


func _nearest_counter() -> Node:
	var world := _world()
	if world != null and world.has_method("is_traveling") and bool(world.call("is_traveling")):
		return null
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		return null
	var best: Node = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("shop_counter"):
		if not node.has_method("can_interact") or not bool(node.call("can_interact")):
			continue
		var at: Vector3 = node.call("approach_point")
		var dist := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _signature() -> String:
	var world := _world()
	var parts: PackedStringArray = [_selected]
	if world == null:
		return "|".join(parts)
	parts.append(str(int(world.call("coin_balance"))))
	parts.append(str(world.call("active_pet_id")))
	for id in PetCatalog.ORDER:
		parts.append("1" if bool(world.call("owns_pet", id)) else "0")
	return "|".join(parts)


func _world() -> Node:
	return get_tree().get_first_node_in_group("world")


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _IVORY
	box.set_corner_radius_all(18)
	box.shadow_color = Color(0.08, 0.14, 0.2, 0.16)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 8)
	return box


func _card_style(selected: bool, hover := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 0.99, 0.97) if selected or hover else _CARD
	box.border_color = _TEAL if selected else Color(_NAVY, 0.08)
	box.set_border_width_all(3 if selected else 1)
	box.set_corner_radius_all(14)
	return box


func _preview_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.96, 0.93, 0.86)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(6)
	return box


func _swatch_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(18)
	return box


func _disc_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _GOLD
	box.border_color = _GOLD_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(11)
	return box


func _style_action(button: Button, enabled: bool) -> void:
	var fill := _TEAL if enabled else _GREY
	var hover := _TEAL_HOVER if enabled else _GREY
	var pressed := _TEAL_PRESS if enabled else _GREY
	var font := Color(1, 1, 1) if enabled else Color(0.35, 0.40, 0.46)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_disabled_color", Color(0.35, 0.40, 0.46))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _button_style(fill))
	button.add_theme_stylebox_override("hover", _button_style(hover))
	button.add_theme_stylebox_override("pressed", _button_style(pressed))
	button.add_theme_stylebox_override("disabled", _button_style(_GREY))
	button.add_theme_stylebox_override("focus", _button_style(fill))


func _style_pill(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _button_style(_TEAL, 20))
	button.add_theme_stylebox_override("hover", _button_style(_TEAL_HOVER, 20))
	button.add_theme_stylebox_override("pressed", _button_style(_TEAL_PRESS, 20))
	button.add_theme_stylebox_override("focus", _button_style(_TEAL, 20))


func _style_close(button: Button) -> void:
	button.add_theme_color_override("font_color", _NAVY)
	button.add_theme_color_override("font_hover_color", _NAVY)
	button.add_theme_color_override("font_pressed_color", _NAVY)
	button.add_theme_font_size_override("font_size", 20)
	var rest := _button_style(Color(0.94, 0.91, 0.86), 10)
	var hover := _button_style(Color(0.90, 0.86, 0.80), 10)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", rest)


func _button_style(fill: Color, radius := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
