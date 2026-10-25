extends Node
## Dedicated exports bypass the decorative title scene and its asynchronous town build.
func _ready() -> void:
	var scene := "res://scenes/world.tscn" if (OS.get_cmdline_user_args().has("--dedicated") or OS.get_cmdline_user_args().has("--net-join")) else "res://ui/screens/main_menu.tscn"
	get_tree().call_deferred("change_scene_to_file", scene)
