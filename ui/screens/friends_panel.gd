class_name FriendsPanel
## Friends side panel (board panel 3). There is no accounts/friends service yet, so the list is the
## players in this world (Net.roster), labelled honestly; selecting one shows their mini profile.

const T := preload("res://ui/theme/ui_tokens.gd")


static func status_of(entry: Dictionary) -> Array:
	var loc := str(entry.get("location", ""))
	if loc == "":
		return ["Arriving", T.GREY_DOT, ""]
	if str(entry.get("fisher", "")) != "":
		return ["Fishing", T.BLUE_DOT, "Fishing off the docks!"]
	var title := LocationCatalog.title_of(loc) if LocationCatalog.has_location(loc) else loc
	if loc == LocationCatalog.MAIN:
		return ["In town", T.GREEN, "Exploring the plaza!"]
	if loc == "home":
		return ["At home", T.GREEN, "Decorating their igloo."]
	return ["At %s" % title, T.BLUE_DOT, ""]


static func make() -> UIModal:
	var sp := UIWidgets.side_panel("Friends", "friends", 720)
	var root: UIModal = sp["root"]
	var body: VBoxContainer = sp["body"]
	var row := UIKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var list := UIKit.vbox(10)
	list.custom_minimum_size.x = 380
	row.add_child(list)
	var detail := UIKit.card("Inset")
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var others: Array = Net.roster().filter(func(e): return int(e.get("id", 0)) != Net.local_id())
	if others.is_empty():
		list.add_child(UIWidgets.state_panel("empty", "No one else here yet",
			"Host a world and invite friends on your network to see them here."))
		detail.visible = false
		return root
	var rows: Array[PanelContainer] = []
	var show_detail := func(e: Dictionary) -> void:
		for c in detail.get_children():
			c.queue_free()
		var col := UIKit.vbox(8)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var pc := CenterContainer.new()
		pc.add_child(Portrait.make(PenguinPreview.portrait(Net.coat_color(int(e.get("color", 0)))), T.TEAL_SOFT, 210))
		col.add_child(pc)
		col.add_child(UIKit.label(str(e.get("name", "Penguin")), "TitleSmall", HORIZONTAL_ALIGNMENT_CENTER))
		var st: Array = FriendsPanel.status_of(e)
		var sc := CenterContainer.new()
		sc.add_child(UIKit.status(st[0], st[1]))
		col.add_child(sc)
		if st[2] != "":
			col.add_child(UIKit.label(st[2], "Muted", HORIZONTAL_ALIGNMENT_CENTER))
		var view := UIKit.button("View", "primary", "", Vector2(0, 80))
		view.pressed.connect(func() -> void: UIRouter.push(PlayerCard.make(e)))
		col.add_child(view)
		detail.add_child(col)
	for i in others.size():
		var e: Dictionary = others[i]
		var r := UIKit.card("Row")
		var h := UIKit.hbox(12)
		h.add_child(Portrait.make(PenguinPreview.portrait(Net.coat_color(int(e.get("color", 0)))), Color("#DCEFEA"), 96))
		var t := UIKit.vbox(0)
		t.add_child(UIKit.label(str(e.get("name", "Penguin")), "Strong"))
		var st: Array = status_of(e)
		t.add_child(UIKit.status(st[0], st[1]))
		h.add_child(t)
		r.add_child(h)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		for c in r.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				for k in rows.size():
					rows[k].theme_type_variation = "RowSelected" if k == i else "Row"
				show_detail.call(e))
		rows.append(r)
		list.add_child(r)
	rows[0].theme_type_variation = "RowSelected"
	show_detail.call(others[0])
	return root
