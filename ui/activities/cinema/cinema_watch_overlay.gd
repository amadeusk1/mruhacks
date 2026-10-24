extends Control
## Full-screen close-up of the shared film (cinema port 2/5, flag pengloo/cinema/watch_overlay).
## Shows the shared CinemaService.player's frames; no webview, no decoder. Esc or "Back to seat" closes it.

signal closed

var player: CinemaScreenPlayer  ## defaults to CinemaService.player
var _picture: TextureRect
var _time: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.THEME
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_picture = TextureRect.new()
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_picture)
	var bar := UIKit.hbox(16)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -64
	bar.offset_bottom = -16
	bar.offset_left = 24
	bar.offset_right = -24
	add_child(bar)
	_time = Label.new()
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_time)
	var back := UIKit.button("Back to seat", "secondary")
	back.pressed.connect(close)
	bar.add_child(back)
	if player == null:
		player = CinemaService.player
	player.texture_changed.connect(_on_texture)  # method: disconnects when the overlay is freed
	_picture.texture = player.texture


func _on_texture(t: Texture2D) -> void:
	_picture.texture = t


func _process(_d: float) -> void:
	var t := int(player.position()) if player else 0
	_time.text = "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60] + ("" if player and player.playing else "  ·  paused")


func close() -> void:
	closed.emit()
	UIRouter.remove(self)
	queue_free()
