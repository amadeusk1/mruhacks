class_name PenguinFace
extends Control
## Vector penguin face for portraits and avatars in lists (body colour, cream mask, beak, eyes).

var body := Color("#2B4C8C")


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	draw_circle(c + Vector2(0, s * 0.06), s * 0.46, body)
	draw_circle(c + Vector2(-s * 0.14, s * 0.12), s * 0.22, Color("#FAF1DD"))
	draw_circle(c + Vector2(s * 0.14, s * 0.12), s * 0.22, Color("#FAF1DD"))
	draw_circle(c + Vector2(0, s * 0.24), s * 0.2, Color("#FAF1DD"))
	draw_circle(c + Vector2(-s * 0.12, s * 0.06), s * 0.055, Color("#1A1A1F"))
	draw_circle(c + Vector2(s * 0.12, s * 0.06), s * 0.055, Color("#1A1A1F"))
	draw_circle(c + Vector2(-s * 0.105, s * 0.045), s * 0.018, Color.WHITE)
	draw_circle(c + Vector2(s * 0.135, s * 0.045), s * 0.018, Color.WHITE)
	var beak := PackedVector2Array([c + Vector2(-s * 0.08, s * 0.15), c + Vector2(s * 0.08, s * 0.15), c + Vector2(0, s * 0.25)])
	draw_colored_polygon(beak, Color("#F2A23A"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
