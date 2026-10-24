class_name Spinner
extends Control
## Small dotted loading ring (Connecting… state).

const T := preload("res://ui/theme/ui_tokens.gd")
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(40, 40)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	for i in 8:
		var a := TAU * i / 8.0 + _t * 3.0
		var fade := 0.25 + 0.75 * float((i + int(_t * 8.0)) % 8) / 8.0
		draw_circle(c + Vector2(cos(a), sin(a)) * 14.0, 3.0, Color(T.NAVY, fade))
