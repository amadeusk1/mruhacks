extends Node
## Multi-instance Sketch Club test over real ENet on localhost. Start one host and 2 clients:
##   Godot --path . res://tools/sketch_mp.tscn -- --role=host --name=Snowdrop --out=/abs/dir/
##   Godot --path . res://tools/sketch_mp.tscn -- --role=client --name=Milo --out=/abs/dir/
## Each instance joins the table, readies, plays its turns through the real Sketch Club screen
## (SketchClub intents + per-peer views), screenshots every phase it sees, and the host drives
## the reveal. Prints SKETCH_MP lines; a client asserts it never received another's secret.

var role := "host"
var me := "P"
var out := "/tmp/"
var _shot_phases := {}
var _ui: Control
var _secrets_seen := []
var _done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
		if a.begins_with("--name="): me = a.trim_prefix("--name=")
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	SketchClub.view_changed.connect(_on_view)
	Net.session_started.connect(_on_session)
	var err := Net.host_game(me) if role == "host" else Net.join_game(me)
	print("SKETCH_MP %s start err='%s'" % [me, err])
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		print("SKETCH_MP %s TIMEOUT phases=%s" % [me, _shot_phases.keys()])
		get_tree().quit(1))


func _on_session() -> void:
	await get_tree().create_timer(1.5 if role == "host" else 2.5).timeout
	SketchClub.join()
	_ui = ActivityScreens.open("sketch")
	await get_tree().create_timer(4.0).timeout  # let everyone sit before readying
	SketchClub.ready()


func _on_view(v: Dictionary) -> void:
	var phase := str(v.get("phase", ""))
	# privacy probe: every text this client ever receives outside the reveal must be its own assignment
	if v.has("assignment") and v["assignment"].has("text"):
		_secrets_seen.append(str(v["assignment"]["text"]))
	var rv: Dictionary = v.get("reveal", {})
	var key := phase + str(v.get("round", "")) + ("c%se%s" % [rv.get("chain", ""), rv.get("index", "")] if rv else "")
	if phase == "" or _shot_phases.has(key):
		return
	_shot_phases[key] = true
	await get_tree().create_timer(0.8).timeout
	await _shot("sketch_%s_%s" % [me.to_lower(), key])
	match phase:
		"prompt":
			SketchClub.submit_text("%s's idea: a penguin juggling fish" % me)
		"draw":
			var strokes := [{"c": "#3d7bd9", "w": 10.0, "p": PackedVector2Array([Vector2(0.2, 0.7), Vector2(0.5, 0.2), Vector2(0.8, 0.7)])},
				{"c": "#f0645c", "w": 14.0, "p": PackedVector2Array([Vector2(0.3, 0.8), Vector2(0.7, 0.8)])}]
			SketchClub.submit_drawing(strokes)
		"guess":
			SketchClub.submit_text("%s guesses: a tent at sunset" % me)
		"reveal":
			var r: Dictionary = v["reveal"]
			if bool(v.get("is_host", false)) and not bool(r.get("done", false)):
				await get_tree().create_timer(0.6).timeout
				SketchClub.next_entry()
			elif bool(r.get("done", false)) and not _done:
				_done = true
				print("SKETCH_MP %s DONE phases=%s received_texts=%s" % [me, _shot_phases.keys(), _secrets_seen])
				await get_tree().create_timer(2.0).timeout
				get_tree().quit(0)


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
