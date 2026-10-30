extends Control
## Choose Home and Home Visitors (Images/UI - Houses Visitors and Player Actions.png).
## mode "choose" lists the six house types, each shown at the tier you own; moving in rebuilds the
## room around the new house (HomeUpgrades keeps your upgrades); "visitors" edits access.
## Visitor access and decorate permission are saved locally; "Who can decorate?" is locked to
## Only me (owner-only edits are the proposed first policy; no server enforces sharing yet).

signal chosen(shell: String)
signal closed

const A := preload("res://ui/activities/act_style.gd")
const HOMES := [
	["snow_dome", "Snow Dome", "A round igloo, snug and bright."],
	["aframe_cabin", "A-frame", "A tall cabin with a cozy loft."],
	["round_cottage", "Cottage", "A cozy cabin with space to relax and welcome friends."],
	["treehouse", "Treehouse", "Up in the pines, with a view."],
	["lighthouse_loft", "Lighthouse", "A bright loft by the sea."],
	["houseboat", "Houseboat", "Bob gently by the docks."],
]
const PATH := "user://home_choice.cfg"

var mode := "choose"
var _sel := "round_cottage"
var _visit := "friends"
var _body: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cfg := ConfigFile.new()
	_sel = HomeUpgrades.house()
	if cfg.load(PATH) == OK:
		_visit = cfg.get_value("home", "visitors", _visit)
	_build()


func _build() -> void:
	if _body:
		_body.queue_free()
	_body = A.screen_root()
	add_child(_body)
	if mode == "visitors":
		_build_visitors()
	else:
		_build_choose()


func _build_choose() -> void:
	var p := A.panel(30)
	A.pin(_body, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-560, -300, 560, 300))
	var row := A.hbox(30)
	p.add_child(row)
	var left := A.vbox(8)
	row.add_child(left)
	left.add_child(A.title("Choose Home", 44))
	left.add_child(A.label("Pick a home to make your own.", 21, A.SUB))
	left.add_child(A.spacer(0, 10))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	left.add_child(grid)
	for h in HOMES:
		var on: bool = h[0] == _sel
		var b := Button.new()
		b.custom_minimum_size = Vector2(156, 176)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = h[1]
		b.add_theme_stylebox_override("normal", A.box(Color.TRANSPARENT, 16, 3 if on else 0, A.TEAL, 4))
		b.add_theme_stylebox_override("hover", A.box(A.CARD_HOVER, 16, 3 if on else 0, A.TEAL, 4))
		b.add_theme_stylebox_override("pressed", A.box(A.CARD, 16, 3, A.TEAL, 4))
		b.add_theme_stylebox_override("focus", A.box(Color.TRANSPARENT, 16, 3, A.NAVY, 0))
		b.pressed.connect(func() -> void: _sel = h[0]; _build())
		grid.add_child(b)
		var v := A.vbox(4)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 6; v.offset_right = -6; v.offset_top = 6; v.offset_bottom = -4
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", A.box(Color("#DCEBF1"), 12))
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tile)
		tile.add_child(ModelThumb.new(HomeUpgrades.exterior_id(0, h[0])))
		v.add_child(A.label(h[1], 19, A.NAVY, true, HORIZONTAL_ALIGNMENT_CENTER))
	var right := A.vbox(12)
	right.custom_minimum_size.x = 400
	row.add_child(right)
	var big := PanelContainer.new()
	big.add_theme_stylebox_override("panel", A.box(Color("#D8EAF1"), 18))
	big.custom_minimum_size = Vector2(400, 300)
	right.add_child(big)
	big.add_child(ModelThumb.new(HomeUpgrades.exterior_id(0, _sel)))
	var info := _info(_sel)
	right.add_child(A.title(str(HomeUpgrades.info(0, _sel)["name"]), 30, HORIZONTAL_ALIGNMENT_CENTER))
	var d := A.label(info[2], 18, A.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(d)
	right.add_child(A.expander())
	var use := A.button("Use Home", "primary", "", 26, Vector2(0, 68))
	use.pressed.connect(_use)
	right.add_child(use)
	_close_at(Vector2(560, -300))


## Close X at the panel's top-right corner (panel is centred, corner given relative to screen centre).
func _close_at(corner: Vector2) -> void:
	var x := A.close_button(44)
	x.pressed.connect(close)
	A.pin(_body, x, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(corner.x - 60, corner.y + 14, corner.x - 16, corner.y + 58))


func _info(id: String) -> Array:
	for h in HOMES:
		if h[0] == id:
			return h
	return HOMES[0]


func _build_visitors() -> void:
	var p := A.panel(32)
	A.pin(_body, p, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-300, -290, 300, 290))
	var v := A.vbox(10)
	p.add_child(v)
	v.add_child(A.title("Home Visitors", 44))
	v.add_child(A.label("Choose who can visit your home.", 21, A.SUB))
	v.add_child(A.spacer(0, 10))
	var box := PanelContainer.new()
	box.theme_type_variation = "Inset"
	v.add_child(box)
	var bv := A.vbox(12)
	box.add_child(bv)
	bv.add_child(A.label("Who can visit?", 22, A.NAVY, true))
	var group := ButtonGroup.new()
	for opt in [["only_me", "Only me"], ["friends", "Friends"], ["anyone", "Anyone"]]:
		var r := CheckBox.new()
		r.text = opt[1]
		r.button_group = group
		r.button_pressed = opt[0] == _visit
		r.add_theme_font_size_override("font_size", 21)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			r.add_theme_stylebox_override(st, A.box(Color.TRANSPARENT, 8, 0, Color.TRANSPARENT, 4))
		r.add_theme_icon_override("radio_checked", load("res://ui/activities/icons/radio_on.svg"))
		r.add_theme_icon_override("radio_unchecked", load("res://ui/activities/icons/radio_off.svg"))
		r.toggled.connect(func(on: bool) -> void: if on: _visit = opt[0])
		bv.add_child(r)
	bv.add_child(HSeparator.new())
	bv.add_child(A.label("Who can decorate?", 22, A.NAVY, true))
	var lock_row := A.hbox(12)
	bv.add_child(lock_row)
	lock_row.add_child(A.icon("lock", 26, A.MUTED))
	var locked := A.button("Only me", "secondary", "", 19, Vector2(260, 48))
	locked.disabled = true
	locked.alignment = HORIZONTAL_ALIGNMENT_LEFT
	locked.tooltip_text = "Only the owner can decorate for now"
	lock_row.add_child(locked)
	v.add_child(A.expander())
	var save := A.button("Save", "primary", "", 26, Vector2(0, 66))
	save.pressed.connect(func() -> void: _save(); UIWidgets.toast(get_tree().root, "Visitor settings saved"); close())
	v.add_child(save)
	_close_at(Vector2(300, -290))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("home", "visitors", _visit)
	cfg.save(PATH)
	Net.set_visitors(_visit)


func _use() -> void:
	var tree := get_tree()
	var moving := _sel != HomeUpgrades.house()
	_save()
	HomeUpgrades.set_house(_sel)
	chosen.emit(HomeUpgrades.interior_id())
	close()
	if moving:
		HomeUpgradeCard.build_moment(tree, 0, "Moving house…")


func close() -> void:
	closed.emit()
	queue_free()


func preview(state: String) -> void:
	mode = "visitors" if state == "visitors" else "choose"
	_sel = "round_cottage"
	_visit = "friends"
	_build()
