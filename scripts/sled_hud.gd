extends CanvasLayer

signal retry_pressed
signal town_pressed

@onready var distance_label: Label = $Distance
@onready var countdown_label: Label = $Countdown
@onready var hint_label: Label = $Hint
@onready var center: CenterContainer = $Center
@onready var panel: PanelContainer = $Center/Result
@onready var title_label: Label = $Center/Result/Margin/VBox/Title
@onready var body_label: Label = $Center/Result/Margin/VBox/Body
@onready var retry_button: Button = $Center/Result/Margin/VBox/Retry
@onready var town_button: Button = $Center/Result/Margin/VBox/Town


func _ready() -> void:
	panel.hide()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	town_button.pressed.connect(func() -> void: town_pressed.emit())
	set_distance(0)


func set_distance(meters: int) -> void:
	distance_label.text = "%d m" % meters


func set_hint(text: String) -> void:
	hint_label.text = text


func set_countdown(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = text != ""
	var color := UiKit.CORAL if text == "Go!" else UiKit.NAVY
	countdown_label.add_theme_color_override("font_color", color)


func hide_result() -> void:
	panel.hide()
	hint_label.show()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retry_button.disabled = false
	town_button.disabled = false


func show_result(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	countdown_label.hide()
	hint_label.hide()
	panel.show()
	center.mouse_filter = Control.MOUSE_FILTER_STOP


func lock() -> void:
	retry_button.disabled = true
	town_button.disabled = true
