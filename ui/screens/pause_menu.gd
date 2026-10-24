class_name PauseMenu
extends UIModal
## Escape menu. Online worlds keep running, so it says "Menu", not "Game Paused".

func _init() -> void:
	setup("Menu", "", 520, true, false)
	title_label.theme_type_variation = "Title"
	body.add_theme_constant_override("separation", 18)
	card.custom_minimum_size.y = 0
	var resume := UIKit.button("Resume", "primary", "play")
	resume.pressed.connect(close)
	body.add_child(resume)
	var settings := UIKit.button("Settings", "secondary", "gear")
	settings.pressed.connect(func() -> void: UIRouter.push(SettingsScreen.new()))
	body.add_child(settings)
	var leave := UIKit.button("Leave world", "secondary", "leave")
	leave.pressed.connect(_leave)
	body.add_child(leave)
	var quit := UIKit.button("Quit game", "secondary", "quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	body.add_child(quit)


func _leave() -> void:
	var c := ConfirmDialog.ask("Leave this world?", "You'll go back to the title screen.", "Stay", "Leave", "leave")
	c.confirmed.connect(func() -> void:
		UIRouter.close_all()
		Net.shutdown()
		get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn"))
