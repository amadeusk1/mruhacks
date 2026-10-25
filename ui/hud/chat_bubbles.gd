class_name ChatBubbles
extends Control
## Speech bubbles above penguins' heads for chat (and a "• • •" while someone types).
## Screen-space, drawn over the world, so they stay readable behind walls and the occlusion
## silhouette. One bubble per penguin: a new message replaces the old one. A bubble shows for
## 5 s plus a little per character, then fades. It sits above the nameplate, never on it.

const T := preload("res://ui/theme/ui_tokens.gd")
const BASE_S := 5.0
const PER_CHAR_S := 0.06
const FADE_S := 0.4
const TYPING_TIMEOUT_S := 8.0
const MAX_W := 300.0
const FONT_SIZE := 22
const NAME_Y := 1.4     ## penguin nameplate height (penguin_movement.gd NameLabel)
const GAP_PX := 26.0    ## bubble tail tip sits this far above the nameplate's centre

var _bubbles := {}      ## peer id -> Bubble


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Net.chat_from.connect(_on_chat)
	Net.typing_changed.connect(_on_typing)


func _on_chat(peer_id: int, _speaker: String, message: String) -> void:
	_show(peer_id, message, BASE_S + PER_CHAR_S * message.length(), false)


func _on_typing(peer_id: int, typing: bool) -> void:
	var b: Bubble = _bubbles.get(peer_id)
	if typing and (b == null or b.typing or b.age() > 1.0):  # dots win once a message has been read a moment
		_show(peer_id, "• • •", TYPING_TIMEOUT_S, true)
	elif not typing and b and b.typing:
		b.fade()


func _show(peer_id: int, text: String, seconds: float, typing: bool) -> void:
	var b: Bubble = _bubbles.get(peer_id)
	if b == null or not is_instance_valid(b):
		b = Bubble.new()
		add_child(b)
		_bubbles[peer_id] = b
	b.set_message(text, seconds, typing)


## The penguin node for a peer: the local player (no remote_peer meta) or its puppet.
func _penguin(peer_id: int) -> Node3D:
	if peer_id == Net.local_id():
		return get_tree().get_first_node_in_group("local_player") as Node3D
	for p in get_tree().get_nodes_in_group("remote_player"):
		if int(p.get_meta("remote_peer", 0)) == peer_id:
			return p as Node3D
	return null


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for peer_id in _bubbles.keys():
		var b: Bubble = _bubbles[peer_id]
		if not is_instance_valid(b) or b.done():
			if is_instance_valid(b):
				b.queue_free()
			_bubbles.erase(peer_id)
			continue
		var who := _penguin(peer_id)
		var head := who.global_position + Vector3(0, NAME_Y, 0) if who else Vector3.ZERO
		b.visible = who != null and cam != null and who.is_visible_in_tree() and not cam.is_position_behind(head)
		if b.visible:
			var tip := cam.unproject_position(head) - Vector2(0, GAP_PX)
			b.position = (tip - Vector2(b.size.x * 0.5, b.size.y + Bubble.TAIL_H)).round()
	_unstack()


## Penguins standing close: lift later bubbles above earlier ones instead of covering them.
func _unstack() -> void:
	var shown: Array = _bubbles.values().filter(func(x: Bubble) -> bool: return is_instance_valid(x) and x.visible)
	shown.sort_custom(func(a: Bubble, c: Bubble) -> bool: return a.position.y > c.position.y)
	for i in shown.size():
		var r := (shown[i] as Bubble).get_rect().grow(4)
		for j in i:
			var other := (shown[j] as Bubble).get_rect()
			if r.intersects(other):
				shown[i].position.y = other.position.y - r.size.y - Bubble.TAIL_H + 4
				r = (shown[i] as Bubble).get_rect().grow(4)


## Rounded cream bubble with a navy outline and a tail pointing at the speaker.
class Bubble:
	extends Control
	const T := preload("res://ui/theme/ui_tokens.gd")
	const TAIL_H := 12.0
	const TAIL_W := 18.0
	var typing := false
	var _label: Label
	var _until := 0.0
	var _fading := false
	var _shown_at := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = Label.new()
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_color", T.NAVY)
		_label.add_theme_font_size_override("font_size", ChatBubbles.FONT_SIZE)
		_label.add_theme_constant_override("line_spacing", 3)
		_label.position = Vector2(16, 10)
		add_child(_label)

	func set_message(text: String, seconds: float, is_typing: bool) -> void:
		typing = is_typing
		_fading = false
		modulate.a = 1.0
		_until = Time.get_ticks_msec() / 1000.0 + seconds
		_shown_at = Time.get_ticks_msec() / 1000.0
		_label.text = text
		_label.custom_minimum_size = Vector2.ZERO
		_label.size = Vector2.ZERO
		var font := _label.get_theme_font("font")
		var one_line := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ChatBubbles.FONT_SIZE).x
		var wraps := one_line + 4.0 > ChatBubbles.MAX_W
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wraps else HORIZONTAL_ALIGNMENT_CENTER
		var w := clampf(one_line + 4.0, 24.0, ChatBubbles.MAX_W)
		_label.custom_minimum_size.x = w
		_label.size.x = w
		var h := _label.get_minimum_size().y
		size = Vector2(w + 32, h + 20)
		queue_redraw()

	func age() -> float:
		return Time.get_ticks_msec() / 1000.0 - _shown_at

	func expired() -> bool:
		return Time.get_ticks_msec() / 1000.0 > _until

	func fade() -> void:
		if _fading:
			return
		_fading = true
		create_tween().tween_property(self, "modulate:a", 0.0, ChatBubbles.FADE_S)

	func done() -> bool:
		return _fading and modulate.a <= 0.01

	func _process(_d: float) -> void:
		if not _fading and expired():
			fade()

	func _draw() -> void:
		var body := StyleBoxFlat.new()
		body.bg_color = T.PANEL
		body.border_color = T.NAVY
		body.set_border_width_all(3)
		body.set_corner_radius_all(16)
		body.anti_aliasing = true
		body.shadow_color = Color(0.05, 0.1, 0.2, 0.18)
		body.shadow_size = 6
		body.shadow_offset = Vector2(0, 3)
		draw_style_box(body, Rect2(Vector2.ZERO, size))
		var cx := size.x * 0.5
		var y := size.y - 2.0
		var tail := PackedVector2Array([Vector2(cx - TAIL_W * 0.5, y), Vector2(cx + TAIL_W * 0.5, y), Vector2(cx, y + TAIL_H)])
		draw_colored_polygon(tail, T.PANEL)
		draw_polyline(PackedVector2Array([tail[0] + Vector2(0, -0.5), tail[2], tail[1] + Vector2(0, -0.5)]), T.NAVY, 3.0, true)
