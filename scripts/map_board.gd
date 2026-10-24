extends Control

## Snowy travel map. Pins come from LocationCatalog.

signal place_chosen(location_id: String)

const _PIN := preload("res://scripts/map_pin.gd")
const _FONT := preload("res://fonts/Fredoka-Bold.ttf")

var _current_id := ""
var _pins: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_place_pins)


func refresh(current_id: String) -> void:
	_current_id = current_id
	for pin in _pins:
		pin.free()
	_pins.clear()
	for location_id in LocationCatalog.ordered_ids():
		var pin = _PIN.new()
		add_child(pin)
		pin.setup(location_id, LocationCatalog.title_of(location_id), location_id == current_id)
		if location_id != current_id:
			pin.chosen.connect(_on_pin_chosen)
		_pins.append(pin)
	_place_pins()
	queue_redraw()


func destination_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for pin in _pins:
		if not pin.here:
			titles.append(pin.place_title)
	return titles


func _place_pins() -> void:
	if size.x < 20.0:
		return
	for pin in _pins:
		var spot := _pixel(pin.location_id)
		pin.position = spot - Vector2(pin.size.x * 0.5, 18.0)


func _pixel(location_id: String) -> Vector2:
	return LocationCatalog.map_point(location_id) * size


func _draw() -> void:
	if size.x < 20.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.38, 0.66, 0.9))
	_draw_water()
	_draw_island()
	_draw_igloo()
	_draw_town_blocks()
	_draw_hill()
	_draw_route()
	var font := _FONT
	draw_string(font, Vector2(size.x * 0.5 - 6.0, 22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.25, 0.4))


func _draw_water() -> void:
	var specks := [
		Vector2(0.08, 0.18), Vector2(0.9, 0.16), Vector2(0.12, 0.84),
		Vector2(0.88, 0.78), Vector2(0.5, 0.08),
	]
	for speck in specks:
		draw_circle(speck * size, 7.0, Color(0.55, 0.8, 0.95, 0.7))


func _draw_island() -> void:
	var center := size * 0.5
	var reach := Vector2(size.x * 0.38, size.y * 0.36)
	var radii := [1.05, 0.92, 1.12, 0.86, 1.0, 0.9, 1.08, 0.94, 1.02, 0.88]
	var shore := PackedVector2Array()
	for i in radii.size():
		var angle := TAU * float(i) / float(radii.size()) - 0.5
		shore.append(center + Vector2(cos(angle) * reach.x * radii[i], sin(angle) * reach.y * radii[i]))
	draw_colored_polygon(shore, Color(0.93, 0.96, 0.98))
	var outline := shore.duplicate()
	outline.append(shore[0])
	draw_polyline(outline, Color(0.62, 0.78, 0.88), 5.0, true)


func _draw_town_blocks() -> void:
	var origin := _pixel("plaza")
	var clothes := Rect2(origin + Vector2(-40, -32), Vector2(26, 16))
	var pets := Rect2(origin + Vector2(14, -32), Vector2(26, 16))
	var furniture := Rect2(origin + Vector2(-40, 14), Vector2(26, 16))
	draw_rect(clothes, Color(0.94, 0.95, 0.97))
	draw_rect(pets, Color(0.94, 0.95, 0.97))
	draw_rect(furniture, Color(0.94, 0.95, 0.97))
	draw_rect(Rect2(clothes.position + Vector2(0, clothes.size.y - 4), Vector2(clothes.size.x, 4)), Color(0.9, 0.42, 0.4))
	draw_rect(Rect2(pets.position + Vector2(0, pets.size.y - 4), Vector2(pets.size.x, 4)), Color(0.4, 0.74, 0.48))
	draw_rect(Rect2(furniture.position, Vector2(furniture.size.x, 4)), Color(0.62, 0.42, 0.24))
	draw_circle(origin + Vector2(0, -2), 6.5, Color(0.7, 0.86, 0.95))
	draw_circle(origin + Vector2(0, -2), 2.4, Color(0.93, 0.97, 1))


func _draw_hill() -> void:
	var peak := _pixel("sled_hill") + Vector2(0, -28)
	draw_colored_polygon(PackedVector2Array([
		peak + Vector2(-42, 34),
		peak,
		peak + Vector2(42, 34),
	]), Color(0.75, 0.86, 0.94))
	draw_colored_polygon(PackedVector2Array([
		peak + Vector2(-22, 34),
		peak + Vector2(0, 12),
		peak + Vector2(24, 34),
	]), Color(0.9, 0.95, 0.98))


func _draw_igloo() -> void:
	var dome := _pixel("home") + Vector2(-30, -2)
	draw_circle(dome, 13.0, Color(0.8, 0.91, 0.97))
	draw_arc(dome, 13.0, PI, TAU, 16, Color(0.5, 0.68, 0.8), 2.0, true)
	draw_rect(Rect2(dome + Vector2(-4.5, -2.0), Vector2(9, 8)), Color(0.15, 0.22, 0.3))


func _draw_route() -> void:
	_draw_dashed("home", "plaza")
	_draw_dashed("plaza", "sled_hill")


func _draw_dashed(from_id: String, to_id: String) -> void:
	var from := _pixel(from_id)
	var to := _pixel(to_id)
	var steps := 12
	for i in steps:
		if i % 2 == 1:
			continue
		var start := from.lerp(to, float(i) / float(steps))
		var finish := from.lerp(to, float(i + 1) / float(steps))
		draw_line(start, finish, Color(0.72, 0.5, 0.28, 0.85), 3.0, true)


func _on_pin_chosen(location_id: String) -> void:
	place_chosen.emit(location_id)
