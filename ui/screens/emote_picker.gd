class_name EmotePicker
extends UIModal
## Eight emotes (board panel 4, right). Picking one plays the anim_emotes clip on your penguin and
## closes the picker; moving cancels the emote. With a pet out, a Pet row adds its emotes ("pet/<id>").

const EMOTES := [["Wave", "emote_wave"], ["Cheer", "emote_cheer"], ["Laugh", "emote_laugh"], ["Dance", "emote_dance"],
	["Shy", "emote_shy"], ["Sleepy", "emote_sleepy"], ["Surprise", "emote_surprised"], ["Happy", "emote_happy_bounce"]]


func _init() -> void:
	setup("Emotes", "", 680, true, false)
	title_label.theme_type_variation = "Heading"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dim.color = Color(0, 0, 0, 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	var player: Node = tree.get_first_node_in_group("local_player") if tree else null
	var pet: PetFollower = player.get_node_or_null("Pet") as PetFollower if player else null
	var pet_emotes: Array = Pets.emotes(pet.species) if pet else []
	if not Mobile.active():
		var cc: Control = card.get_parent()
		cc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		cc.offset_left = -720
		cc.offset_top = -560 - (80 if not pet_emotes.is_empty() else 0)
		cc.offset_right = -24
		cc.offset_bottom = -140
	var grid := GridContainer.new()
	grid.columns = 2 if Mobile.active() else 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for e in EMOTES:
		var path := "res://ui/emotes/%s.png" % e[1]
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else UIKit.icon("smile")
		var b := UIWidgets.item_card(tex, e[0], _play.bind(e[1]), Vector2(280, 120) if Mobile.active() else Vector2(145, 168))
		var fx := EmoteFx.new()
		fx.kind = e[1]
		fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fx)
		grid.add_child(b)
	if pet_emotes.is_empty():
		return
	var row := HBoxContainer.new()  # slim row of pet emotes: pet icon + name
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var pet_icon := AssetRegistry.icon("pets/" + pet.species)
	for e in pet_emotes:
		var b := UIKit.button(str(e["name"]), "secondary", "", Vector2(0, 64))
		b.icon = pet_icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 48)
		for s in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(s, Color.WHITE)  # the pet's own colours, not the theme's navy
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_play.bind("pet/" + str(e["id"])))
		row.add_child(b)


func _play(clip: String) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	var ok: bool = player != null and player.has_method("play_emote") and bool(player.call("play_emote", clip))
	close()
	if not ok:
		UIWidgets.toast(self, "Stand somewhere open to emote.", "smile")


class EmoteFx extends Control:
	## the little cartoon marks the mockup draws around each emote (rays, notes, Zz, !!, hearts)
	var kind := ""
	const CORAL := Color("#F5776C")
	const GOLD := Color("#F2B23A")
	const NAVY := Color("#1E3460")

	func _rays(c: Vector2, n: int, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
		for i in n:
			var a := deg_to_rad(lerpf(a0, a1, float(i) / maxf(n - 1, 1)))
			draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r1, col, 4.0, true)

	func _heart(c: Vector2, r: float) -> void:
		draw_circle(c + Vector2(-r * 0.5, 0), r * 0.55, CORAL)
		draw_circle(c + Vector2(r * 0.5, 0), r * 0.55, CORAL)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, r * 0.15), c + Vector2(r * 1.02, r * 0.15), c + Vector2(0, r * 1.25)]), CORAL)

	func _note(c: Vector2) -> void:
		draw_circle(c, 6, CORAL)
		draw_line(c + Vector2(5, 0), c + Vector2(5, -20), CORAL, 3.0)
		draw_line(c + Vector2(5, -20), c + Vector2(14, -16), CORAL, 3.0)

	func _draw() -> void:
		var top := Vector2(size.x * 0.5, size.y * 0.32)
		var f := get_theme_default_font()
		match kind:
			"emote_wave":
				_rays(Vector2(24, 40), 3, 6, 18, 200, 250, GOLD)
			"emote_cheer", "emote_laugh":
				_rays(top + Vector2(0, -6), 5, 42, 56, 215, 325, CORAL if kind == "emote_cheer" else GOLD)
			"emote_dance":
				_note(Vector2(size.x - 30, 34))
				_note(Vector2(26, 46))
			"emote_sleepy":
				draw_string(f, Vector2(size.x - 44, 34), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NAVY)
				draw_string(f, Vector2(size.x - 30, 22), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NAVY)
			"emote_surprised":
				draw_string(f, Vector2(size.x * 0.5 - 14, 30), "!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#E2534A"))
			"emote_happy_bounce":
				_heart(Vector2(28, 34), 9)
				_heart(Vector2(size.x - 28, 30), 9)
