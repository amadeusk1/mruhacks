extends CanvasLayer

## Sled HUD, styled to Images/UI - Sledding Snowballs and Basketball.png (Sled start / Sled run),
## extended for races: a mode card (Time trial / Race) with the hill's best times, the race lobby,
## live place + standings, a finish card and the race podium. sled_run.gd drives it.
## The old scene labels stay as hidden data nodes.

signal retry_pressed
signal town_pressed
signal trial_pressed
signal race_pressed
signal start_now_pressed
signal leave_lobby_pressed

const A := preload("res://ui/activities/act_style.gd")
const BEST_PATH := "user://sled_best.cfg"
const ORDINAL := ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"]

@onready var distance_label: Label = $Distance
@onready var countdown_label: Label = $Countdown
@onready var hint_label: Label = $Hint
@onready var center: CenterContainer = $Center
@onready var panel: PanelContainer = $Center/Result
@onready var retry_button: Button = $Center/Result/Margin/VBox/Retry
@onready var town_button: Button = $Center/Result/Margin/VBox/Town

var _ui: Control
var _time_card: PanelContainer
var _time_value: Label
var _next_card: PanelContainer
var _next_value: Label
var _place_card: PanelContainer
var _place_value: Label
var _place_of: Label
var _standings: PanelContainer
var _standings_rows: VBoxContainer
var _count: Label
var _reset_chip: Button
var _hint_chip: PanelContainer
var _result: PanelContainer
var _result_title: Label
var _result_time: Label
var _result_note: Label
var _result_retry: Button
var _menu: PanelContainer
var _best_value: Label
var _board_rows: VBoxContainer
var _race_button: Button
var _lobby: PanelContainer
var _lobby_rows: VBoxContainer
var _lobby_note: Label
var _start_now: Button
var _podium: Control
var _flash: Label
var _clock := 0.0
var _running := false
var _locked := false


func _ready() -> void:
	for n in [distance_label, countdown_label, hint_label, center, get_node_or_null("Place")]:
		if n:
			n.visible = false
	panel.hide()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_ui = A.screen_root()
	add_child(_ui)
	_time_card = A.stat_card("Time", "00:00.0", 40)
	_time_value = _time_card.find_child("Value", true, false)
	A.pin(_ui, _time_card, Vector4(0, 0, 0, 0), Vector4(24, 20, 0, 0))
	_place_card = A.stat_card("Place", "1st", 44)
	_place_value = _place_card.find_child("Value", true, false)
	_place_of = A.label("of 1", 16, A.SUB)
	_place_card.get_child(0).add_child(_place_of)
	A.pin(_ui, _place_card, Vector4(0, 0, 0, 0), Vector4(24, 128, 0, 0))
	_next_card = A.stat_card("Next checkpoint", "", 34)
	_next_value = _next_card.find_child("Value", true, false)
	var nrow := A.hbox(10)
	_next_value.get_parent().remove_child(_next_value)
	nrow.add_child(A.icon("turn_right", 34, A.NAVY))
	nrow.add_child(_next_value)
	_next_card.get_child(0).add_child(nrow)
	A.pin(_ui, _next_card, Vector4(1, 0, 1, 0), Vector4(-250, 20, -24, 0))
	_standings = A.panel(14, 18)
	A.pin(_ui, _standings, Vector4(1, 0, 1, 0), Vector4(-250, 128, -24, 0))
	_standings_rows = A.vbox(4)
	_standings.add_child(_standings_rows)
	_count = A.title("", 120, HORIZONTAL_ALIGNMENT_CENTER)
	_count.add_theme_color_override("font_outline_color", A.WHITE)
	_count.add_theme_constant_override("outline_size", 18)
	A.pin(_ui, _count, Vector4(0.5, 0.33, 0.5, 0.33), Vector4(-300, -80, 300, 80))
	_flash = A.title("", 40, HORIZONTAL_ALIGNMENT_CENTER)
	_flash.add_theme_color_override("font_outline_color", A.WHITE)
	_flash.add_theme_constant_override("outline_size", 12)
	A.pin(_ui, _flash, Vector4(0.5, 0.2, 0.5, 0.2), Vector4(-300, -30, 300, 30))
	_reset_chip = A.chip_button("Reset", "reset", "light", 20)
	_reset_chip.pressed.connect(func() -> void: retry_pressed.emit())
	A.pin(_ui, _reset_chip, Vector4(0, 1, 0, 1), Vector4(24, -78, 160, -24))
	var leave := A.chip_button("Leave", "close", "light", 20)
	leave.pressed.connect(func() -> void: town_pressed.emit())
	A.pin(_ui, leave, Vector4(1, 1, 1, 1), Vector4(-160, -78, -24, -24))
	_hint_chip = A.chip("", Color(1, 1, 1, 0.92), A.NAVY, "", 18)
	A.pin(_ui, _hint_chip, Vector4(0.5, 1, 0.5, 1), Vector4(-170, -74, 170, -28))
	_build_result()
	_build_menu()
	_build_lobby()
	_podium = Control.new()
	_podium.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_podium)
	show_run_hud(false, false)
	set_hint("")


func _build_result() -> void:
	_result = A.panel(20, 22)
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	A.pin(_ui, _result, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-210, -190, 210, 190))
	var rv := A.vbox(10)
	_result.add_child(rv)
	_result_title = A.label("Finished!", 26, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER)
	rv.add_child(_result_title)
	_result_time = A.title("00:00.0", 54, HORIZONTAL_ALIGNMENT_CENTER)
	rv.add_child(_result_time)
	_result_note = A.label("", 18, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	_result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_result_note)
	_result_retry = A.button("Retry", "primary", "rotate", 26, Vector2(0, 64))
	_result_retry.pressed.connect(func() -> void: retry_pressed.emit())
	rv.add_child(_result_retry)
	var modes := A.button("Race or trial", "secondary", "sled", 20, Vector2(0, 50))
	modes.pressed.connect(func() -> void: _result.hide(); show_menu())
	rv.add_child(modes)
	var out := A.button("Leave", "secondary", "", 20, Vector2(0, 50))
	out.pressed.connect(func() -> void: town_pressed.emit())
	rv.add_child(out)
	_result.hide()


func _build_menu() -> void:
	_menu = A.panel(22, 24)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	A.pin(_ui, _menu, Vector4(1, 0, 1, 0), Vector4(-440, 24, -28, 0))
	var sv := A.vbox(10)
	_menu.add_child(sv)
	sv.add_child(A.title("Sled Hill", 40))
	sv.add_child(A.label("Bends, boost pads and two big jumps.\nA and D to steer.", 18, A.SUB))
	var best := PanelContainer.new()
	best.add_theme_stylebox_override("panel", A.box(A.CARD, 14, 0, Color.TRANSPARENT, 12))
	sv.add_child(best)
	var bv := A.vbox(0)
	best.add_child(bv)
	bv.add_child(A.label("Your best time", 17, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	_best_value = A.title(_best_text(), 34, HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(_best_value)
	var trial := A.button("Time trial", "primary", "stopwatch", 26, Vector2(0, 62))
	trial.pressed.connect(func() -> void: trial_pressed.emit())
	sv.add_child(trial)
	_race_button = A.button("Race", "primary", "flag", 26, Vector2(0, 62))
	_race_button.pressed.connect(func() -> void: race_pressed.emit())
	sv.add_child(_race_button)
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", A.box(A.CARD, 14, 0, Color.TRANSPARENT, 12))
	sv.add_child(board)
	var brow := A.vbox(4)
	board.add_child(brow)
	var head := A.hbox(8)
	head.add_child(A.icon("trophy", 22, A.CORAL))
	head.add_child(A.label("Hill records", 18, A.NAVY, true))
	brow.add_child(head)
	_board_rows = A.vbox(2)
	brow.add_child(_board_rows)
	set_board([])
	var leave := A.button("Leave", "secondary", "", 20, Vector2(0, 48))
	leave.pressed.connect(func() -> void: town_pressed.emit())
	sv.add_child(leave)
	_menu.hide()


func _build_lobby() -> void:
	_lobby = A.panel(22, 24)
	_lobby.mouse_filter = Control.MOUSE_FILTER_STOP
	A.pin(_ui, _lobby, Vector4(1, 0, 1, 0), Vector4(-440, 24, -28, 0))
	var lv := A.vbox(10)
	_lobby.add_child(lv)
	var head := A.hbox(10)
	head.add_child(A.icon("flag", 34, A.CORAL))
	head.add_child(A.title("Race lobby", 36))
	lv.add_child(head)
	_lobby_note = A.label("", 19, A.SUB)
	_lobby_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_lobby_note)
	_lobby_rows = A.vbox(6)
	lv.add_child(_lobby_rows)
	_start_now = A.button("Start now", "primary", "play", 26, Vector2(0, 62))
	_start_now.pressed.connect(func() -> void: start_now_pressed.emit())
	lv.add_child(_start_now)
	var out := A.button("Leave lobby", "secondary", "", 20, Vector2(0, 48))
	out.pressed.connect(func() -> void: leave_lobby_pressed.emit())
	lv.add_child(out)
	_lobby.hide()


func _process(delta: float) -> void:
	if _running:
		_clock += delta
		_time_value.text = _fmt(_clock)
	if _flash.modulate.a > 0.0:
		_flash.modulate.a = maxf(0.0, _flash.modulate.a - delta * 0.8)


# ---------------------------------------------------------------- run HUD --
func show_run_hud(on: bool, race: bool) -> void:
	_time_card.visible = on
	_next_card.visible = on
	_place_card.visible = on and race
	_standings.visible = on and race
	_reset_chip.visible = on and not race


func set_distance(meters: int) -> void:
	distance_label.text = "%d m" % meters


## Metres to the next checkpoint (or the finish).
func set_next(meters: float, is_finish: bool) -> void:
	_next_card.get_child(0).get_child(0).text = "Finish" if is_finish else "Next checkpoint"
	_next_value.text = "%d m" % maxi(0, int(meters))


func set_hint(text: String) -> void:
	hint_label.text = text
	if _hint_chip:
		(_hint_chip.find_child("Text", true, false) as Label).text = text
		_hint_chip.visible = text != ""


func set_countdown(text: String) -> void:
	countdown_label.text = text
	if _count == null:
		return
	_count.text = text
	_count.visible = text != ""
	_count.add_theme_color_override("font_color", A.CORAL if text == "Go!" else A.NAVY)
	if text != "":
		_count.pivot_offset = Vector2(300, 80)
		_count.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(_count, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func start_clock() -> void:
	_clock = 0.0
	_running = true


func stop_clock(at := -1.0) -> void:
	_running = false
	if at >= 0.0:
		_clock = at
		_time_value.text = _fmt(at)


func reset_clock() -> void:
	_running = false
	_clock = 0.0
	_time_value.text = _fmt(0.0)


func flash(text: String, color := A.NAVY) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash.modulate.a = 1.0


## rows: SledRaceGame.standings() entries; me: local peer id.
func set_standings(rows: Array, me: int) -> void:
	for c in _standings_rows.get_children():
		c.queue_free()
	var mine := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		var is_me := int(r["id"]) == me
		if is_me:
			mine = i
		var row := A.hbox(8)
		row.add_child(A.label(str(i + 1), 18, A.CORAL if i == 0 else A.NAVY, true))
		var n := A.label(str(r["name"]) + (" (you)" if is_me else ""), 17, A.TEAL_DARK if is_me else A.NAVY, is_me)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		row.add_child(n)
		var tail := "DNF" if bool(r["dnf"]) else (_fmt(float(r["time"])) if bool(r["done"]) else "")
		row.add_child(A.label(tail, 16, A.SUB))
		_standings_rows.add_child(row)
	_place_value.text = ORDINAL[clampi(mine, 0, 7)]
	_place_of.text = "of %d" % rows.size()


# ------------------------------------------------------------------ cards --
func show_menu(race_online := true, waiting := 0) -> void:
	hide_cards()
	_best_value.text = _best_text()
	_race_button.disabled = not race_online
	_race_button.text = "Race" if waiting <= 0 else "Race  ·  %d waiting" % waiting
	_race_button.tooltip_text = "" if race_online else "Races need other penguins online"
	_menu.show()


## board: [{name, time}] fastest first.
func set_board(board: Array) -> void:
	for c in _board_rows.get_children():
		c.queue_free()
	if board.is_empty():
		_board_rows.add_child(A.label("No times yet. Be the first!", 16, A.SUB))
		return
	for i in mini(board.size(), 5):
		var row := A.hbox(8)
		row.add_child(A.label("%d" % (i + 1), 17, A.CORAL if i == 0 else A.NAVY, true))
		var n := A.label(str(board[i]["name"]), 17, A.NAVY)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(A.label(_fmt(float(board[i]["time"])), 17, A.NAVY, true))
		_board_rows.add_child(row)


func show_lobby(names: Array, left: float, queued: bool) -> void:
	hide_cards()
	for c in _lobby_rows.get_children():
		c.queue_free()
	for i in names.size():
		var row := A.hbox(10)
		row.add_child(A.chip(str(i + 1), A.TEAL_SOFT, A.TEAL_DARK, "", 16, Vector2(10, 4)))
		row.add_child(A.label(str(names[i]), 20, A.NAVY, true))
		_lobby_rows.add_child(row)
	if queued:
		_lobby_note.text = "A race is running. You're in the next one!"
	elif names.size() < 2:
		_lobby_note.text = "Waiting for another racer...\nUp to 8 penguins can race."
	else:
		_lobby_note.text = "Starting in %d s" % int(ceil(left))
	_start_now.visible = not queued and names.size() >= 2
	_lobby.show()


func show_finish(title: String, time: float, note: String, retry_text: String) -> void:
	hide_cards()
	_running = false
	_count.hide()
	_result_title.text = title
	_result_time.text = _fmt(time)
	_result_note.text = note
	_result_retry.text = retry_text
	_result_retry.visible = retry_text != ""
	_result.show()


func set_finish_note(note: String) -> void:
	_result_note.text = note


## Race results: podium for the top three, then everyone's time. rows: standings, colours by id.
func show_podium(rows: Array, me: int, colors: Dictionary) -> void:
	hide_cards()
	_running = false
	var root := A.panel(22, 26)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	A.pin(_podium, root, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-420, -230, 420, 220))
	var v := A.vbox(10)
	root.add_child(v)
	var head := A.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	head.add_child(A.icon("trophy", 40, A.CORAL))
	head.add_child(A.title("Race results", 40))
	v.add_child(head)
	var stage := A.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	stage.custom_minimum_size.y = 230
	v.add_child(stage)
	for slot in [1, 0, 2]:  # 2nd, 1st, 3rd
		if slot >= rows.size():
			continue
		var r: Dictionary = rows[slot]
		var col := A.vbox(2)
		col.alignment = BoxContainer.ALIGNMENT_END
		col.custom_minimum_size = Vector2(170, 0)
		var pv := PenguinView.new()
		pv.framing = "portrait"
		pv.custom_minimum_size = Vector2(130, 110)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pv)
		pv.call_deferred("set_look", colors.get(int(r["id"]), Net.coat_color(0)), {})
		col.add_child(A.label(str(r["name"]), 20, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
		var block := PanelContainer.new()
		var tint: Color = [Color("#F2C14E"), Color("#C9D3DD"), Color("#E3A07A")][slot]
		block.add_theme_stylebox_override("panel", A.box(tint, 14, 0, Color.TRANSPARENT, 8))
		block.custom_minimum_size = Vector2(150, [90, 64, 46][slot])
		var bl := A.vbox(0)
		block.add_child(bl)
		bl.add_child(A.title(ORDINAL[slot], 28, HORIZONTAL_ALIGNMENT_CENTER))
		bl.add_child(A.label("DNF" if bool(r["dnf"]) else _fmt(float(r["time"])), 16, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(block)
		stage.add_child(col)
	var rest := A.vbox(2)
	v.add_child(rest)
	for i in range(3, rows.size()):
		var r: Dictionary = rows[i]
		var row := A.hbox(10)
		row.add_child(A.label(ORDINAL[i], 17, A.NAVY, true))
		var n := A.label(str(r["name"]), 17, A.TEAL_DARK if int(r["id"]) == me else A.NAVY)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(A.label("DNF" if bool(r["dnf"]) else _fmt(float(r["time"])), 17, A.NAVY))
		rest.add_child(row)
	var bar := A.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(bar)
	var again := A.button("Rematch", "primary", "rotate", 24, Vector2(220, 64))
	again.pressed.connect(func() -> void: race_pressed.emit())
	bar.add_child(again)
	var trial := A.button("Time trial", "secondary", "stopwatch", 20, Vector2(200, 58))
	trial.pressed.connect(func() -> void: trial_pressed.emit())
	bar.add_child(trial)
	var out := A.button("Leave", "secondary", "", 20, Vector2(140, 58))
	out.pressed.connect(func() -> void: town_pressed.emit())
	bar.add_child(out)


func hide_cards() -> void:
	_menu.hide()
	_lobby.hide()
	_result.hide()
	for c in _podium.get_children():
		c.queue_free()


func hide_result() -> void:
	panel.hide()
	_result.hide()
	retry_button.disabled = false
	town_button.disabled = false


func lock() -> void:
	_locked = true
	retry_button.disabled = true
	town_button.disabled = true


func save_best(t: float) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(BEST_PATH)
	var b := float(cfg.get_value("sled", "best", 0.0))
	if b <= 0.0 or t < b:
		cfg.set_value("sled", "best", t)
		cfg.save(BEST_PATH)
		return true
	return false


func _best_text() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_PATH) == OK:
		return _fmt(float(cfg.get_value("sled", "best", 0.0)))
	return "--:--.-"


static func _fmt(t: float) -> String:
	return "%02d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func preview(state: String) -> void:
	match state:
		"start":
			show_menu(true, 2)
			set_board([{"name": "Milo", "time": 24.6}, {"name": "Snowdrop", "time": 26.1}])
		"finished":
			show_finish("Finished!", 42.6, "New best time!", "Retry")
		"lobby":
			show_lobby(["Snowdrop", "Milo", "Pip"], 7.0, false)
		_:
			show_run_hud(true, true)
			_clock = 18.4
			_time_value.text = _fmt(_clock)
			set_next(120, false)
			set_standings([{"id": 2, "name": "Milo", "done": false, "dnf": false, "time": 0.0},
				{"id": 1, "name": "Snowdrop", "done": false, "dnf": false, "time": 0.0}], 1)
