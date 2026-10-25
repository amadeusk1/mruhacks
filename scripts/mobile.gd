class_name Mobile
extends RefCounted
## Phone and tablet browsers. Desktop windows stay on the 1280×720 layout.


static func active() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if not OS.has_feature("web"):
		return false
	var size := DisplayServer.window_get_size()
	if size.x > 0 and size.x < 900:
		return true
	return bool(JavaScriptBridge.eval(
		"!!(navigator.maxTouchPoints>0||window.matchMedia('(pointer: coarse)').matches||new URLSearchParams(location.search).has('mobile'))"
	))


## Empty band at the bottom of the HUD so the stick and buttons are not covering chat.
static func pad() -> float:
	return 196.0 if active() else 0.0


static func apply(window: Window, text_scale: float) -> void:
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_factor = text_scale
	if not active():
		window.content_scale_size = Vector2i(1280, 720)
		return
	var size := window.size
	var portrait := size.y > size.x
	window.content_scale_size = Vector2i(800, 1400) if portrait else Vector2i(1280, 760)


## Pull a control back inside its parent when a desktop-sized panel would hang off a phone.
## Design anchors are kept and reapplied on each resize, so a later desktop window restores them.
static func contain(c: Control) -> void:
	if c == null:
		return
	if not active() and not c.has_meta("_fit_anchor"):
		return
	var kick := func() -> void:
		if is_instance_valid(c):
			_contain_now(c)
	if not c.is_inside_tree():
		c.tree_entered.connect(func() -> void:
			if not is_instance_valid(c):
				return
			c.get_tree().process_frame.connect(kick, CONNECT_ONE_SHOT)
			if not c.get_viewport().size_changed.is_connected(kick):
				c.get_viewport().size_changed.connect(kick)
		, CONNECT_ONE_SHOT)
		return
	c.get_tree().process_frame.connect(kick, CONNECT_ONE_SHOT)
	if not c.get_viewport().size_changed.is_connected(kick):
		c.get_viewport().size_changed.connect(kick)


static func _contain_now(c: Control) -> void:
	var parent := c.get_parent() as Control
	if parent == null:
		return
	var ps := parent.size
	if ps.x < 32.0 or ps.y < 32.0:
		return
	if not c.has_meta("_fit_anchor"):
		c.set_meta("_fit_anchor", Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom))
		c.set_meta("_fit_off", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
		c.set_meta("_fit_min", c.custom_minimum_size)
	var a: Vector4 = c.get_meta("_fit_anchor")
	var o: Vector4 = c.get_meta("_fit_off")
	var saved_min: Vector2 = c.get_meta("_fit_min")
	if not active():
		c.anchor_left = a.x
		c.anchor_top = a.y
		c.anchor_right = a.z
		c.anchor_bottom = a.w
		c.offset_left = o.x
		c.offset_top = o.y
		c.offset_right = o.z
		c.offset_bottom = o.w
		c.custom_minimum_size = saved_min
		return
	var left := a.x * ps.x + o.x
	var top := a.y * ps.y + o.y
	var right := a.z * ps.x + o.z
	var bottom := a.w * ps.y + o.w
	var rect := Rect2(left, top, right - left, bottom - top)
	# A panel whose height comes from its children (top and bottom pinned to the same edge).
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var overflow := rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > ps.x + 1.0 or rect.end.y > ps.y + 1.0
	overflow = overflow or saved_min.x > ps.x + 1.0 or saved_min.y > ps.y + 1.0
	if not overflow:
		return
	var size := Vector2(minf(rect.size.x, ps.x), minf(rect.size.y, ps.y))
	var pos := Vector2(
		clampf(rect.position.x, 0.0, maxf(0.0, ps.x - size.x)),
		clampf(rect.position.y, 0.0, maxf(0.0, ps.y - size.y)))
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y
	var min_size := saved_min
	if min_size.x > size.x:
		min_size.x = size.x
	if min_size.y > size.y:
		min_size.y = size.y
	c.custom_minimum_size = min_size
