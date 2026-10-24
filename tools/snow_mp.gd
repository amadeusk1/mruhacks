extends Node

## Real localhost snowball match + emote sync over ENet. Start one host and 1-3 clients (windowed):
##   Godot --path . res://tools/snow_mp.tscn -- --net-host --net-name=Pip --team=coral --out=/abs/dir [--emote]
##   Godot --path . res://tools/snow_mp.tscn -- --net-join --net-name=Milo --team=teal --out=/abs/dir
## world.gd starts the session from the --net-* args. Each instance: (with --emote) waves twice
## quickly and once more after a pause, then walks off mid-emote; the others log what they saw.
## Then everyone stands on their team pad, plays the match by throwing at the opponent in their
## lane, screenshots each phase to snowball_<name>_<phase>.png and prints SNOW_MP lines.

var me := "P"
var team := "coral"
var out := "/tmp"
var emoter := false
var _w: Node
var _p: Node3D
var _arena: Node
var _shots := {}
var _emotes: Array = []
var _hits_seen := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-name="): me = a.trim_prefix("--net-name=")
		if a.begins_with("--team="): team = a.trim_prefix("--team=")
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a == "--emote": emoter = true
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	Net.emote_played.connect(func(id: int, clip: String) -> void:
		_emotes.append(clip)
		print("SNOW_MP %s emote from %d: %s" % [me, id, clip]))
	get_tree().create_timer(900.0).timeout.connect(func() -> void:
		print("SNOW_MP %s TIMEOUT shots=%s" % [me, _shots.keys()])
		get_tree().quit(1))
	await Net.session_started
	for i in 400:  # the town takes a while to build when several instances start together
		_arena = get_tree().get_first_node_in_group("snow_arena")
		if _arena != null:
			break
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.0).timeout
	_p = get_tree().get_first_node_in_group("local_player") as Node3D
	if _arena == null:
		print("SNOW_MP %s FAIL no arena" % me)
		get_tree().quit(1)
		return
	var gate: Vector2 = (_arena.get("_pads")["coral"] + _arena.get("_pads")["teal"]) * 0.5
	_p.global_position = Vector3(gate.x + (randf() - 0.5) * 2.0, float(_arena.get("_floor")) + 0.1, gate.y + 2.2)
	if emoter:  # a looping activity clip already running when the others arrive (late-join check)
		_p.call("play_activity", "fish_wait")
	while get_tree().get_nodes_in_group("remote_player").size() < int(_arg("--peers=", "1")):
		await get_tree().create_timer(0.5).timeout
	if not emoter:
		await get_tree().create_timer(1.0).timeout
		var host_puppet := _emoter_puppet()
		var clips: AnimationPlayer = host_puppet.get("_clips") if host_puppet != null else null
		print("SNOW_MP %s late_join_clip=%s" % [me, clips.current_animation if clips != null else "?"])
	# all instances share the wall clock: start the scripted part together on the next 15 s mark
	var mark := (floori(Time.get_unix_time_from_system() / 15.0) + 2) * 15.0
	while Time.get_unix_time_from_system() < mark:
		await get_tree().create_timer(0.1).timeout
	await _emote_test()
	var pad: Vector2 = _arena.get("_pads")[team]
	_p.global_position = Vector3(pad.x + (randf() - 0.5) * 0.4, float(_arena.get("_floor")) + 0.1, pad.y)
	await get_tree().create_timer(1.0).timeout
	await _shot("lobby")
	_play()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _emote_test() -> void:
	await get_tree().create_timer(1.0).timeout
	if emoter:
		_p.call("play_emote", "emote_wave")
		await get_tree().create_timer(0.2).timeout
		_p.call("play_emote", "emote_cheer")  # inside the 0.8 s gap: others must not see it
		await get_tree().create_timer(1.5).timeout
		_p.call("play_emote", "emote_dance")
		await get_tree().create_timer(0.8).timeout
		_p.global_position += Vector3(0, 0, 0.3)
		Input.action_press("move_back")  # walk off mid-dance: the dance stops for everyone
		await get_tree().create_timer(0.6).timeout
		Input.action_release("move_back")
		await get_tree().create_timer(2.0).timeout
	else:
		var puppet := _emoter_puppet()
		var seen: Array = []
		for i in 60:  # sample the emoter's puppet for 6 s
			var now := str(puppet.get("_overlay")) if puppet != null else "?"
			if seen.is_empty() or seen[-1] != now:
				seen.append(now)
			await get_tree().create_timer(0.1).timeout
		print("SNOW_MP %s emotes=%s puppet_overlays=%s" % [me, _emotes, seen])


func _emoter_puppet() -> Node:
	for node in get_tree().get_nodes_in_group("remote_player"):
		var id := int(node.get_meta("remote_peer", 0))
		for entry in Net.roster():
			if int(entry["id"]) == id and str(entry["name"]) == "Pip":
				return node
	return null


func _play() -> void:
	var lane := -1
	var last_phase := ""
	while true:
		await get_tree().create_timer(0.3).timeout
		var state := Net.snow_view()
		var phase := str(state.get("phase", ""))
		if phase != last_phase:
			print("SNOW_MP %s phase=%s coral=%d teal=%d text=%s" % [me, phase, int(state["coral"]), int(state["teal"]), state["text"]])
			last_phase = phase
			if phase == "countdown":
				await _shot("countdown")
		for e in state.get("events", []):
			if str(e["k"]) == "hit" and int(e["n"]) > _hits_seen:
				_hits_seen = int(e["n"])
				if not _shots.has("hit"):
					await get_tree().create_timer(0.05).timeout
					await _shot("hit")
		if phase == "result":
			await get_tree().create_timer(1.0).timeout
			await _shot("result")
			print("SNOW_MP %s FINAL coral=%d teal=%d text=%s rows=%s" % [me, int(state["coral"]), int(state["teal"]), state["text"], state["rows"]])
			await get_tree().create_timer(6.0).timeout
			print("SNOW_MP %s after results phase=%s team='%s'" % [me, Net.snow_view()["phase"], Net.snow_team()])
			get_tree().quit(0)
			return
		if phase != "live" or Net.snow_team() == "":
			continue
		var mine: Array = state["lives"].get(Net.local_id(), [])
		if mine.size() < 6 or float(mine[1]) > 0.0:
			continue
		var field: Rect2 = _arena.get("_field")
		if lane < 0:
			lane = int(mine[5])
		var z := field.end.y - (1.0 if lane == 0 else 7.0)  # brief lanes Z=1 and Z=7
		var x := field.position.x + 3.5 if team == "coral" else field.end.x - 3.5
		if Vector2(_p.global_position.x, _p.global_position.z).distance_to(Vector2(x, z)) > 0.5:
			_p.global_position = Vector3(x, float(_arena.get("_floor")) + 0.05, z)
			await get_tree().create_timer(0.3).timeout
		var target := _opponent(state, z)
		if target != null and float(mine[0]) <= 0.0:
			_p.call("face_point", target.global_position)
			_p.call("play_activity", "snow_throw")
			Net.snow_throw(target.global_position)
			if not _shots.has("throw"):
				await get_tree().create_timer(0.25).timeout
				await _shot("throw")


func _opponent(state: Dictionary, z: float) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var teams: Dictionary = state["teams"]
	for node in get_tree().get_nodes_in_group("remote_player"):
		var id := int(node.get_meta("remote_peer", 0))
		if not teams.has(id) or teams[id] == team:
			continue
		var d := absf((node as Node3D).global_position.z - z)
		if d < best_d:
			best_d = d
			best = node
	return best


func _shot(tag: String) -> void:
	_shots[tag] = true
	await RenderingServer.frame_post_draw
	var path := "%s/snowball_%s_%s.png" % [out, me.to_lower(), tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("SNOW_MP %s shot %s" % [me, path])
