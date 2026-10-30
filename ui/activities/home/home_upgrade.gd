class_name HomeUpgradeCard
extends UIModal
## "Upgrade your house" card, opened from the Home HUD inside your own house: the dome now and
## the next tier side by side, the space each gives, the price and your coins. Buying swaps the
## house (HomeUpgrades), then a short build moment reloads the room around the bigger dome.

const A := preload("res://ui/activities/act_style.gd")

var _on_bought: Callable


static func make(on_bought: Callable = Callable()) -> HomeUpgradeCard:
	var c := HomeUpgradeCard.new()
	c._on_bought = on_bought
	c._build()
	return c


func _build() -> void:
	var now := HomeUpgrades.tier()
	var next := HomeUpgrades.next_tier()
	setup("Upgrade your house", "Same cozy dome, more room to decorate.", 860, true, false)
	if next.is_empty():
		body.add_child(A.label("Your house is as big as it gets, for now.", 22, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var have := HomeUpgrades.space(now)
	var more := HomeUpgrades.space(int(next["tier"]))
	var row := A.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	body.add_child(row)
	row.add_child(_tile(now, have, false))
	row.add_child(A.icon("arrow_right", 44, A.TEAL))
	row.add_child(_tile(int(next["tier"]), more, true))
	var gain := A.label("+%d floor spaces   +%d wall spots" % [more["floor"] - have["floor"], more["wall"] - have["wall"]],
			26, A.TEAL_DARK, true, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(gain)
	body.add_child(A.label("Your furniture moves over with you.", 18, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	var price := int(next["price"])
	var coins := Coins.have(get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree)
	body.add_child(A.label("Your coins: %d" % coins, 20, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := A.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	body.add_child(buttons)
	var later := A.button("Not now", "secondary", "", 22, Vector2(200, 64))
	later.pressed.connect(close)
	buttons.add_child(later)
	var buy := A.button("Upgrade for %d coins" % price, "primary", "star", 22, Vector2(340, 64))
	if coins < price:
		buy.text = "You need %d more coins" % (price - coins)
		buy.disabled = true
	buy.pressed.connect(_buy.bind(more["floor"] - have["floor"]))
	buttons.add_child(buy)


func _tile(tier: int, space: Dictionary, highlight: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", A.card_box(highlight, 18))
	var v := A.vbox(6)
	p.add_child(v)
	var thumb := ModelThumb.new(HomeUpgrades.exterior_id(tier))
	thumb.custom_minimum_size = Vector2(300, 200)
	v.add_child(thumb)
	var name_row := A.label(str(HomeUpgrades.info(tier)["name"]) + ("" if highlight else "  (now)"), 24, A.NAVY, true,
			HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(name_row)
	v.add_child(A.label("%d floor spaces  ·  %d wall spots" % [space["floor"], space["wall"]], 18, A.SUB, false,
			HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _buy(gained: int) -> void:
	var tree := get_tree()
	if not HomeUpgrades.buy_next(tree):
		UIWidgets.toast(self, "Not enough coins yet.", "alert")
		return
	close()
	if _on_bought.is_valid():
		_on_bought.call()  # closes the Home HUD
	HomeUpgradeCard.build_moment(tree, gained)


## The house grows: the screen whites out while the room reloads around the new dome, then
## the bird cheers, a toast counts the new space and the decorating grid shows it for a moment.
static func build_moment(tree: SceneTree, gained: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	tree.root.add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.mouse_filter = Control.MOUSE_FILTER_STOP
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	var note := A.label("Raising the dome…", 34, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	note.set_anchors_preset(Control.PRESET_CENTER)
	note.modulate.a = 0.0
	layer.add_child(note)
	note.position = (white.get_viewport_rect().size - note.get_combined_minimum_size()) * 0.5
	var tw := layer.create_tween().set_parallel()
	tw.tween_property(white, "color:a", 1.0, 0.4)
	tw.tween_property(note, "modulate:a", 1.0, 0.4)
	await tw.finished
	var world := tree.get_first_node_in_group("world")
	if world and world.has_method("reload_room"):
		await world.reload_room("InsideSpawn")
	await tree.create_timer(0.3).timeout
	var out := layer.create_tween().set_parallel()
	out.tween_property(white, "color:a", 0.0, 0.7)
	out.tween_property(note, "modulate:a", 0.0, 0.4)
	out.chain().tween_callback(layer.queue_free)
	var player := tree.get_first_node_in_group("local_player")
	if player and player.has_method("play_emote"):
		player.call("play_emote", "emote_cheer")
	UIWidgets.toast(tree.root, "Your home grew! %d new spaces to decorate." % gained, "star", 3.5)
	var editors := tree.root.find_children("HouseLayout", "", true, false)
	if not editors.is_empty():
		var ed := editors[0] as DecorEditor
		var grid := ed.make_grid()
		ed.room.add_child(grid)
		tree.create_timer(3.0).timeout.connect(grid.queue_free)
