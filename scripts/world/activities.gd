extends Node

## Activities autoload: one place the world asks to start an activity, and the UI listens.
## Connect `requested` (e.g. the snowball lobby UI) to handle an activity; request() returns
## false when nobody is listening, so the anchor can say the activity is not open yet.

signal requested(activity: String, anchor: Node, player: Node)


func request(activity: String, anchor: Node, player: Node) -> bool:
	if activity == "" or requested.get_connections().is_empty():
		return false
	requested.emit(activity, anchor, player)
	return true


## Every activity entrance currently in the world (for the HUD map and contextual prompts).
func anchors() -> Array:
	return get_tree().get_nodes_in_group("interactables")
