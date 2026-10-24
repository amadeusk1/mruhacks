class_name ResultsScreen
## Shared "Round complete" results (board "Activity Play Guess and Results", panel 4).
## rows: [{name, score, team: "coral"|"teal"|"", color: coat index}] (team results use team names).

const T := preload("res://ui/theme/ui_tokens.gd")


static func show_results(title: String, rows: Array, on_again: Callable, on_leave: Callable, footnote := "") -> UIModal:
	var m := UIModal.new()
	m.setup(title, "", 900, false, false)
	m.title_label.theme_type_variation = "Title"
	m.brand.visible = true
	for r in rows:
		var col := T.CORAL if r.get("team", "") == "coral" else (Color("#24AAAB") if r.get("team", "") == "teal" else T.NAVY)
		m.body.add_child(UIWidgets.score_row(str(r["name"]), int(r["score"]), col,
			PenguinPreview.portrait(Net.coat_color(int(r.get("color", 0))))))
	var b := UIKit.hbox(14)
	var again := UIKit.button("Play again", "primary", "", Vector2(0, 84))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_stretch_ratio = 1.6
	again.add_theme_font_size_override("font_size", 38)
	again.pressed.connect(func() -> void:
		m.close()
		on_again.call())
	b.add_child(again)
	var leave := UIKit.button("Leave", "secondary", "", Vector2(0, 84))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void:
		m.close()
		on_leave.call())
	b.add_child(leave)
	m.body.add_child(b)
	if footnote != "":
		m.body.add_child(UIKit.label(footnote, "Muted", HORIZONTAL_ALIGNMENT_CENTER))
	UIRouter.push(m)
	return m
