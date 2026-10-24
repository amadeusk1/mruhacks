class_name PlayerCard
## Player card (board panel 4, left). Visit home takes you to the homes on the island.
## Mute voice toggles Voice's per-player mute. Block and report have no service yet, so they are
## shown disabled with the reason as a tooltip.

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
	var mine := id == Net.local_id()
	var visit := UIKit.button("Visit home", "primary", "home", Vector2(0, 66))
	visit.pressed.connect(func() -> void:
		var w := m.get_tree().get_first_node_in_group("world")
		UIRouter.close_all()
		if w == null:
			return
		if mine or not Net.is_online():
			w.call("go_to_homes")
		else:
			w.call("travel_to", "home", "InsideSpawn", id))
	if not mine and str(e.get("visitors", "friends")) == "only_me":
		visit.disabled = true
		visit.tooltip_text = "Their home is invite-only."
	col.add_child(visit)
	var who_name := str(e.get("name", "them"))
	var invite := UIKit.button("Invite to my igloo", "outline", "door", Vector2(0, 60))
	invite.pressed.connect(func() -> void:
		Net.invite(id, "home")
		UIWidgets.toast(m, "Invite sent to %s." % who_name, "check"))
	invite.disabled = not Net.is_online() or mine
	col.add_child(invite)
	var w0 := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("world")
	if w0 and str(w0.call("current_location_id")) == "cinema" and not mine and Net.is_online():
		var movie := UIKit.button("Invite to the movie", "outline", "film", Vector2(0, 60))
		movie.pressed.connect(func() -> void:
			UIWidgets.toast(m, "Invite sent to %s." % who_name, "check")
			if not CinemaService.client.signed_in:
				Net.invite(id, "cinema")
				return
			CinemaService.client.view_ticket(func(ticket: String) -> void: Net.invite(id, "cinema", ticket)))
		col.add_child(movie)
	var who := str(e.get("name", ""))
	var mute := UIKit.button("Unmute voice" if Voice.is_muted(who) else "Mute voice", "outline", "mic_off", Vector2(0, 60))
	mute.pressed.connect(func() -> void:
		Voice.set_muted(who, not Voice.is_muted(who))
		mute.text = "Unmute voice" if Voice.is_muted(who) else "Mute voice")
	mute.disabled = id == Net.local_id()
	col.add_child(mute)
	for it in [["Block", "block", "Blocking needs accounts, coming later."],
			["Report", "flag", "Reporting needs a moderation service, coming later."]]:
		var b := UIKit.button(it[0], "outline", it[1], Vector2(0, 60))
		b.disabled = true
		b.tooltip_text = it[2]
		col.add_child(b)
	return m
