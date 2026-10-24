extends CanvasLayer

## Map of places the bus can reach. Click a pin to travel.

signal destination_chosen(location_id: String)
signal dismissed

@onready var _board = $Center/Frame/Margin/Column/MapBoard
@onready var _hint: Label = $Center/Frame/Margin/Column/Hint


func _ready() -> void:
	visible = false
	$Dimmer.gui_input.connect(_on_dimmer_gui_input)
	$Center/Frame/Margin/Column/Header/CloseButton.pressed.connect(dismiss)
	_board.place_chosen.connect(_on_place_chosen)


func open_for(current_id: String, place_title: String = "") -> void:
	var where := place_title
	if where == "" and LocationCatalog.has_location(current_id):
		where = LocationCatalog.title_of(current_id)
	if where == "":
		where = "town"
	_hint.text = "You are in %s. Click another place to go there." % where
	visible = true
	_board.refresh(current_id)


func dismiss() -> void:
	if not visible:
		return
	visible = false
	dismissed.emit()


func destination_titles() -> PackedStringArray:
	return _board.destination_titles()


func _on_place_chosen(location_id: String) -> void:
	destination_chosen.emit(location_id)


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			$Dimmer.accept_event()
			dismiss()
