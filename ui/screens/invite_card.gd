class_name InviteCard
## Invite popup, laid out like the board's Friend Request card (UI - Houses Visitors and Player
## Actions, panel 4): title, portrait, "<name> invited you ...", Accept / Decline, a footnote.
## Closes itself after EXPIRY seconds (cinema view tickets last 60 s on the gateway).

const T := preload("res://ui/theme/ui_tokens.gd")
const EXPIRY := 55.0
const TEXT := {"home": ["Home Invite", "%s invited you to their igloo!"],
	"cinema": ["Movie Invite", "%s invited you to watch a movie!"]}


static func make(from_name: String, color: Color, kind: String, on_accept: Callable) -> UIModal:
	var m := UIModal.new()
	m.setup(TEXT[kind][0], "", 520, false, false)
	m.title_label.theme_type_variation = "Heading"
	m.dim.color = Color(0, 0, 0, 0)
	var pc := CenterContainer.new()
	pc.add_child(Portrait.make(PenguinPreview.portrait(color), T.CORAL_SOFT, 200))
	m.body.add_child(pc)
	m.body.add_child(UIKit.label(from_name, "TitleSmall", HORIZONTAL_ALIGNMENT_CENTER))
	m.body.add_child(UIKit.label(TEXT[kind][1] % from_name, "Body", HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(14)
	var accept := UIKit.button("Accept", "primary", "", Vector2(200, 66))
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(func() -> void:
		m.close()
		on_accept.call())
	row.add_child(accept)
	var decline := UIKit.button("Decline", "secondary", "", Vector2(200, 66))
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decline.pressed.connect(m.close)
	row.add_child(decline)
	m.body.add_child(row)
	var note := UIKit.hbox(8)
	note.alignment = BoxContainer.ALIGNMENT_CENTER
	note.add_child(UIKit.glyph("info", 20, T.SUBTEXT))
	note.add_child(UIKit.label("You can mute them from their player card.", "Muted"))
	m.body.add_child(note)
	m.ready.connect(func() -> void:
		m.get_tree().create_timer(EXPIRY).timeout.connect(func() -> void:
			if is_instance_valid(m) and m.is_inside_tree():
				m.close()))
	return m
