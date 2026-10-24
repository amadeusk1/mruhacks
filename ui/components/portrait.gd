class_name Portrait
## Round penguin portrait. Uses a live render if one is provided, otherwise a drawn penguin face
## in the player's colour so lists never show an empty circle.

const T := preload("res://ui/theme/ui_tokens.gd")


static func make(texture: Texture2D, ring: Color, px := 64.0, body := Color("#2B4C8C")) -> Control:
	var holder := PanelContainer.new()
	var b := StyleBoxFlat.new()
	b.bg_color = ring
	b.set_corner_radius_all(99)
	b.content_margin_left = 3
	b.content_margin_right = 3
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	holder.add_theme_stylebox_override("panel", b)
	holder.custom_minimum_size = Vector2(px, px)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if texture != null:
		var r := TextureRect.new()
		r.texture = texture
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		holder.add_child(r)
	else:
		var face := PenguinFace.new()
		face.body = body
		holder.add_child(face)
	return holder
