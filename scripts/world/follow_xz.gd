extends Node3D

## Keeps this node above `target` on the ground plane (camera-local weather).

var target: Node3D
var height := 9.0


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = Vector3(target.global_position.x, target.global_position.y + height, target.global_position.z)
