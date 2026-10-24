extends MeshInstance3D

## Orange ring on the snow at the current click target.

var _pulse := 0.0


func _ready() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func show_at(point: Vector3) -> void:
	global_position = Vector3(point.x, 0.045, point.z)
	visible = true
	_pulse = 0.0
	scale = Vector3.ONE


func hide_marker() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta * 3.0
	var pulse := 1.0 + sin(_pulse) * 0.08
	scale = Vector3(pulse, 1.0, pulse)
