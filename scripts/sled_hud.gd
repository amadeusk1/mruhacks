extends CanvasLayer

## Sled HUD, styled to Images/UI - Sledding Snowballs and Basketball.png (Sled start / Sled run).
## API used by sled_run.gd is unchanged: set_distance, set_hint, set_countdown, show_result,
## hide_result, lock, retry_pressed, town_pressed. The old scene labels stay as hidden data nodes.

signal retry_pressed
signal town_pressed

const A := preload("res://ui/activities/act_style.gd")
const BEST_PATH := "user://sled_best.cfg"
const COURSE_M := 300   # shortcut: nominal course length for "Next checkpoint"; read real checkpoints once sled_run exposes them

@onready var distance_label: Label = $Distance
@onready var countdown_label: Label = $Countdown
@onready var hint_label: Label = $Hint
@onready var center: CenterContainer = $Center
@onready var panel: PanelContainer = $Center/Result
@onready var title_label: Label = $Center/Result/Margin/VBox/Title
@onready var body_label: Label = $Center/Result/Margin/VBox/Body
@onready var retry_button: Button = $Center/Result/Margin/VBox/Retry
@onready var town_button: Button = $Center/Result/Margin/VBox/Town

var _ui: Control
var _time_card: PanelContainer
var _time_value: Label
var _next_value: Label
var _count: Label
var _result: PanelContainer
var _result_time: Label
var _result_title: Label
var _start: PanelContainer
var _best_value: Label
var _hint_chip: PanelContainer
var _clock := 0.0
var _running := false
var _meters := 0


func _ready() -> void:
	for n in [distance_label, countdown_label, hint_label, center, get_node_or_null("Place")]:
		if n:
			n.visible = false
	panel.hide()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	town_button.pressed.connect(func() -> void: town_pressed.emit())
	_build()
	set_distance(0)


func _build() -> void:
	_ui = A.screen_root()
	add_child(_ui)
	_time_card = A.stat_card("Time", "00:00.0", 40)
	_time_value = _time_card.find_child("Value", true, false)
	A.pin(_ui, _time_card, Vector4(0, 0, 0, 0), Vector4(24, 20, 0, 0))
	var next := A.stat_card("Next checkpoint", "", 34)
	_next_value = next.find_child("Value", true, false)
	var nrow := A.hbox(10)
	_next_value.get_parent().remove_child(_next_value)
	nrow.add_child(A.icon("turn_right", 34, A.NAVY))
	nrow.add_child(_next_value)
	next.get_child(0).add_child(nrow)
	A.pin(_ui, next, Vector4(1, 0, 1, 0), Vector4(-240, 20, -24, 0))
	_count = A.title("", 120, HORIZONTAL_ALIGNMENT_CENTER)
	_count.add_theme_color_override("font_outline_color", A.WHITE)
	_count.add_theme_constant_override("outline_size", 18)
	A.pin(_ui, _count, Vector4(0.5, 0.35, 0.5, 0.35), Vector4(-200, -80, 200, 80))
	var reset := A.chip_button("Reset", "reset", "light", 20)
	reset.pressed.connect(func() -> void: retry_pressed.emit())
	A.pin(_ui, reset, Vector4(0, 1, 0, 1), Vector4(24, -78, 160, -24))
	var leave := A.chip_button("Leave", "close", "light", 20)
	leave.pressed.connect(func() -> void: town_pressed.emit())
	A.pin(_ui, leave, Vector4(1, 1, 1, 1), Vector4(-160, -78, -24, -24))
	_hint_chip = A.chip("", Color(1, 1, 1, 0.92), A.NAVY, "", 18)
	A.pin(_ui, _hint_chip, Vector4(0.5, 1, 0.5, 1), Vector4(-140, -74, 140, -28))
	# finished card (inset style from the board, larger)
	_result = A.panel(20, 22)
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	A.pin(_ui, _result, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-200, -170, 200, 170))
	var rv := A.vbox(10)
	_result.add_child(rv)
	_result_title = A.label("Finished!", 26, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	rv.add_child(_result_title)
	_result_time = A.title("00:00.0", 54, HORIZONTAL_ALIGNMENT_CENTER)
	rv.add_child(_result_time)
	var again := A.button("Retry", "primary", "", 26, Vector2(0, 64))
	again.pressed.connect(func() -> void: retry_pressed.emit())
	rv.add_child(again)
	var out := A.button("Leave", "secondary", "", 22, Vector2(0, 54))
	out.pressed.connect(func() -> void: town_pressed.emit())
	rv.add_child(out)
	_result.hide()
	# time-trial start card
	_start = A.panel(22, 24)
	_start.mouse_filter = Control.MOUSE_FILTER_STOP
	A.pin(_ui, _start, Vector4(1, 0, 1, 0), Vector4(-420, 24, -28, 400))
	var sv := A.vbox(10)
	_start.add_child(sv)
	sv.add_child(A.title("Time trial", 38))
	var sub := A.label("Race to the finish\nas fast as you can!", 19, A.SUB)
	sv.add_child(sub)
	var best := PanelContainer.new()
	best.add_theme_stylebox_override("panel", A.box(A.CARD, 14, 0, Color.TRANSPARENT, 12))
	sv.add_child(best)
	var bv := A.vbox(0)
	best.add_child(bv)
	bv.add_child(A.label("Best time", 18, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	_best_value = A.title(_best_text(), 34, HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(_best_value)
	var go := A.button("Start run", "primary", "", 28, Vector2(0, 66))
	go.pressed.connect(func() -> void: _start.hide(); retry_pressed.emit())
	sv.add_child(go)
	var sleave := A.button("Leave", "secondary", "", 20, Vector2(0, 50))
	sleave.pressed.connect(func() -> void: town_pressed.emit())
	sv.add_child(sleave)
	_start.hide()


func _process(delta: float) -> void:
	if _running:
		_clock += delta
		_time_value.text = _fmt(_clock)


func set_distance(meters: int) -> void:
	distance_label.text = "%d m" % meters
	_meters = meters
	if _next_value:
		_next_value.text = "%d m" % maxi(0, COURSE_M - meters) if meters < COURSE_M else "Finish!"


func set_hint(text: String) -> void:
	hint_label.text = text
	if _hint_chip:
		(_hint_chip.find_child("Text", true, false) as Label).text = text
		_hint_chip.visible = text != ""


func set_countdown(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = false
	if _count == null:
		return
	_count.text = text
	_count.visible = text != ""
	_count.add_theme_color_override("font_color", A.CORAL if text == "Go!" else A.NAVY)
	if text == "Go!":
		_clock = 0.0
		_running = true
	elif text != "" :
		_running = false
		_clock = 0.0
		_time_value.text = _fmt(0)


func hide_result() -> void:
	panel.hide()
	_result.hide()
	retry_button.disabled = false
	town_button.disabled = false
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_result(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	_running = false
	_count.hide()
	_result_title.text = "Finished!" if title.to_lower().contains("finish") else title
	_result_time.text = _fmt(_clock)
	if title.to_lower().contains("finish") and _clock > 0.5:
		_save_best(_clock)
	_result.show()


func lock() -> void:
	retry_button.disabled = true
	town_button.disabled = true


## Optional pre-run card (sled start board). sled_run can call this instead of auto-starting.
func show_start() -> void:
	_best_value.text = _best_text()
	_start.show()


func _best_text() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_PATH) == OK:
		return _fmt(float(cfg.get_value("sled", "best", 0.0)))
	return "--:--.-"


func _save_best(t: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(BEST_PATH)
	var b := float(cfg.get_value("sled", "best", 0.0))
	if b <= 0.0 or t < b:
		cfg.set_value("sled", "best", t)
		cfg.save(BEST_PATH)


static func _fmt(t: float) -> String:
	return "%02d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func preview(state: String) -> void:
	match state:
		"start":
			_time_card.hide()
			for c in _ui.get_children():
				if c is PanelContainer and c != _start:
					c.hide()
			show_start()
		"finished":
			_clock = 42.6
			show_result("Finished!", "")
		_:
			set_countdown("Go!")
			_clock = 18.4
			_time_value.text = _fmt(_clock)
			set_distance(180)
			set_hint("")
