class_name PlayerCard
## Player card (board panel 4, left). Visit home takes you to the homes on the island.
## Voice, block and report have no service yet, so they are shown disabled with the reason as a tooltip.

const T := preload("res://ui/theme/ui_tokens.gd")


static func make(e: Dictionary) -> UIModal:
	var m := UIModal.new()
	m.setup("Player Card", "", 640, true, false)
	m.title_label.theme_type_variation = "Heading"
	m.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := UIKit.hbox(22)
	m.body.add_child(row)
	row.add_child(Portrait.make(PenguinPreview.portrait(Net.coat_color(int(e.get("color", 0)))), T.TEAL_SOFT, 220))
	var col := UIKit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nm := UIKit.label(str(e.get("name", "Penguin")), "Title")
	col.add_child(nm)
	var st: Array = FriendsPanel.status_of(e)
	col.add_child(UIKit.status(st[0], st[1]))
	if st[2] != "":
		col.add_child(UIKit.label(st[2], "Muted"))
	var id := int(e.get("id", 0))
	var visit := UIKit.button("Visit home", "primary", "home", Vector2(0, 66))
	visit.pressed.connect(func() -> void:
		var w := m.get_tree().get_first_node_in_group("world")
		UIRouter.close_all()
		if w and w.has_method("go_to_homes"):
			w.call("go_to_homes"))
	col.add_child(visit)
	var invite := UIKit.button("Invite to my igloo", "outline", "door", Vector2(0, 60))
	invite.pressed.connect(func() -> void:
		Net.invite_home(id)
		UIWidgets.toast(m, "Invite sent to %s." % str(e.get("name", "them")), "check"))
	invite.disabled = not Net.is_online()
	col.add_child(invite)
	for it in [["Mute voice", "mic_off", "Voice chat isn't available yet."], ["Block", "block", "Blocking needs accounts, coming later."],
			["Report", "flag", "Reporting needs a moderation service, coming later."]]:
		var b := UIKit.button(it[0], "outline", it[1], Vector2(0, 60))
		b.disabled = true
		b.tooltip_text = it[2]
		col.add_child(b)
	return m
