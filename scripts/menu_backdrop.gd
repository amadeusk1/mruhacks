extends Control

## Flat town shapes behind the title. They follow the control's size.

const SKY := Color(0.420, 0.663, 0.839)
const SKY_HAZE := Color(0.655, 0.784, 0.878)
const SUN := Color(1.0, 0.780, 0.420)
const HILL := Color(0.812, 0.878, 0.925)
const WATER := Color(0.412, 0.788, 0.847)
const SNOW := Color(0.933, 0.957, 0.969)
const TREE := Color(0.184, 0.435, 0.329)
const TRUNK := Color(0.549, 0.353, 0.196)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 2.0 or s.y < 2.0:
		return
	draw_rect(Rect2(Vector2.ZERO, s), SKY)
	draw_rect(Rect2(0.0, s.y * 0.36, s.x, s.y * 0.24), SKY_HAZE)

	var sun_at := Vector2(s.x * 0.82, s.y * 0.14)
	var sun_r := minf(s.x, s.y) * 0.052
	draw_circle(sun_at, sun_r * 1.45, Color(1.0, 0.91, 0.62))
	draw_circle(sun_at, sun_r, SUN)

	var ridge := s.y * 0.58
	draw_colored_polygon(_ridge(s, ridge, 0.085), HILL)
	_trees(s, ridge)

	draw_rect(Rect2(0.0, s.y * 0.69, s.x, s.y * 0.07), WATER)
	draw_colored_polygon(_ridge(s, s.y * 0.745, 0.04), SNOW)


func _ridge(s: Vector2, base: float, lift: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-12.0, s.y + 12.0),
		Vector2(-12.0, base),
		Vector2(s.x * 0.1, base - s.y * lift),
		Vector2(s.x * 0.26, base + s.y * lift * 0.18),
		Vector2(s.x * 0.44, base - s.y * lift * 0.72),
		Vector2(s.x * 0.62, base + s.y * lift * 0.22),
		Vector2(s.x * 0.8, base - s.y * lift * 0.55),
		Vector2(s.x + 12.0, base - s.y * lift * 0.12),
		Vector2(s.x + 12.0, s.y + 12.0),
	])


func _trees(s: Vector2, ground: float) -> void:
	var spots: Array[Vector2] = [
		Vector2(0.07, 0.1),
		Vector2(0.13, 0.065),
		Vector2(0.2, 0.085),
		Vector2(0.9, 0.075),
		Vector2(0.955, 0.11),
	]
	for spot in spots:
		_tree(Vector2(s.x * spot.x, ground + s.y * 0.012), s.y * spot.y)


func _tree(origin: Vector2, height: float) -> void:
	var trunk_w := height * 0.16
	draw_rect(
		Rect2(origin.x - trunk_w * 0.5, origin.y - height * 0.2, trunk_w, height * 0.26),
		TRUNK
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(origin.x, origin.y - height),
			Vector2(origin.x - height * 0.36, origin.y - height * 0.16),
			Vector2(origin.x + height * 0.36, origin.y - height * 0.16),
		]),
		TREE
	)
