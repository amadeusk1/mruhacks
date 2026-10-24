extends Control

## A place marker on the bus map. The current place does not travel.

signal chosen(location_id: String)

var location_id := ""
var place_title := ""
var here := false
var _hot := false


func setup(id: String, title: String, is_here: bool) -> void:
	location_id = id
	place_title = title
	here = is_here
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW if here else Control.CURSOR_POINTING_HAND
	tooltip_text = "You are here" if here else "Go to %s" % title
	custom_minimum_size = Vector2(140, 78)
	size = custom_minimum_size
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


func _draw() -> void:
	var dot := Vector2(size.x * 0.5, 18.0)
	var radius := 18.0 if _hot and not here else 15.0
	draw_circle(dot + Vector2(1.5, 3.0), radius, Color(0.05, 0.12, 0.2, 0.28))
	var fill := Color(0.98, 0.8, 0.22) if here else Color(0.95, 0.4, 0.16)
	draw_circle(dot, radius, fill)
	draw_arc(dot, radius, 0.0, TAU, 28, Color(1, 1, 1), 2.5, true)
	if here:
		draw_circle(dot, 5.0, Color(0.12, 0.18, 0.28))
	var font := ThemeDB.fallback_font
	var title_size := font.get_string_size(place_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(
		font,
		Vector2((size.x - title_size.x) * 0.5, 52),
		place_title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color(0.1, 0.18, 0.3)
	)
	if here:
		var note := "You are here"
		var note_size := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(
			font,
			Vector2((size.x - note_size.x) * 0.5, 70),
			note,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color(0.28, 0.4, 0.55)
		)


func _gui_input(event: InputEvent) -> void:
	if here:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			chosen.emit(location_id)


func _on_mouse_entered() -> void:
	_hot = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hot = false
	queue_redraw()
