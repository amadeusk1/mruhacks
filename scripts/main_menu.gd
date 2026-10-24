extends Control

## Title screen. Enter town loads the world; Quit leaves the game.

const TITLE := "Pengloo"
const WORLD_SCENE := "res://scenes/world.tscn"

@onready var _title: Label = $Center/Stack/Title
@onready var _enter: Button = $Center/Stack/Card/Margin/Column/EnterButton


func _ready() -> void:
	_title.text = TITLE
	_enter.pressed.connect(_enter_town)
	$Center/Stack/Card/Margin/Column/QuitButton.pressed.connect(_quit)
	_enter.grab_focus()


func _enter_town() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _quit() -> void:
	get_tree().quit()
