extends Node
## Screenshot harness for UI screens.
##   Godot --path . res://tools/ui_preview.tscn -- --screen=res://ui/activities/x.tscn --state=name --bg=/abs.png --out=/abs.png
## The screen's root script may implement preview(state: String) to load mock data.
## Several shots: --shots=screen|state|bg|out;screen|state|bg|out


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var shots: Array = []
	if args.has("shots"):
		for s in str(args["shots"]).split(";"):
			var p := s.split("|")
			if p.size() == 4:
				shots.append(p)
	else:
		shots.append([args.get("screen", ""), args.get("state", ""), args.get("bg", ""), args.get("out", "user://ui.png")])
	get_window().size = Vector2i(1280, 720)
	for s in shots:
		await _shot(str(s[0]), str(s[1]), str(s[2]), str(s[3]))
	get_tree().quit()


func _shot(screen: String, state: String, bg: String, out: String) -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = load("res://fonts/game_theme.tres")
	add_child(holder)
	if bg != "" and FileAccess.file_exists(bg):
		var img := Image.load_from_file(bg)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(tr)
	var node: Node
	if screen.ends_with(".tscn"):
		node = (load(screen) as PackedScene).instantiate()
	else:
		node = (load(screen) as GDScript).new()
	holder.add_child(node)
	if node is CanvasLayer:
		(node as CanvasLayer).layer = 10
	await get_tree().process_frame
	if node.has_method("preview"):
		node.call("preview", state)
	for i in 12:
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--debug"):
		for c in node.find_children("*", "Control", true, false).slice(0, 12):
			print("DBG ", c.name, " ", c.get_class(), " pos=", (c as Control).position, " size=", (c as Control).size)
		print("DBG root size=", (node as Control).size if node is Control else Vector2.ZERO, " holder=", holder.size)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SAVED ", out)
	holder.queue_free()
	await get_tree().process_frame
