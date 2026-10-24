class_name EmotePicker
extends UIModal
## Eight emotes (board panel 4, right). Picking one plays the anim_emotes clip on your penguin and
## closes the picker; moving cancels the emote.

const EMOTES := [["Wave", "emote_wave"], ["Cheer", "emote_cheer"], ["Laugh", "emote_laugh"], ["Dance", "emote_dance"],
	["Shy", "emote_shy"], ["Sleepy", "emote_sleepy"], ["Surprise", "emote_surprised"], ["Happy", "emote_happy_bounce"]]


func _init() -> void:
	setup("Emotes", "", 680, true, false)
	title_label.theme_type_variation = "Heading"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dim.color = Color(0, 0, 0, 0.0)
	var cc: Control = card.get_parent()
	cc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cc.offset_left = -720
	cc.offset_top = -560
	cc.offset_right = -24
	cc.offset_bottom = -140
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for e in EMOTES:
		var path := "res://ui/emotes/%s.png" % e[1]
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else UIKit.icon("smile")
		var b := UIWidgets.item_card(tex, e[0], _play.bind(e[1]), Vector2(145, 168))
		grid.add_child(b)


func _play(clip: String) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	var ok: bool = player != null and player.has_method("play_emote") and bool(player.call("play_emote", clip))
	close()
	if not ok:
		UIWidgets.toast(self, "Stand somewhere open to emote.", "smile")
