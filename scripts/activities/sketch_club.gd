extends Node
## SketchClub autoload: the Sketch Club table session over the teammate's Net (ENet) layer.
## The host (or the solo player) owns a SketchGame; everyone else sends intents and receives
## ONLY their own view via targeted RPCs (rpc_id), never a broadcast of chains. Drawings travel
## as SketchStrokes bytes. Transport-agnostic in spirit: all host logic sits behind _host_* and
## _send(), so a dedicated server can take the host role later.
##
## UI: connect `view_changed(view)`; call join()/leave()/ready()/submit_text()/submit_drawing()/
## next_entry()/play_again(). World: seats at the communal table call join() via Activities.

signal view_changed(view: Dictionary)

## Debug: allow a 2-player game (the spec minimum is 3). Also settable with --sketch-min=2.
var min_players := 3
var game := SketchGame.new()       # host only
var view: Dictionary = {}          # latest view for the local player
var _sent := {}                    # host: peer -> last version sent
var _last_phase := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sketch-min="):
			min_players = int(a.trim_prefix("--sketch-min="))
	Net.roster_changed.connect(_on_roster_changed)


func is_host() -> bool:
	return not Net.is_online() or multiplayer.is_server()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func in_game() -> bool:
	return str(view.get("phase", "")) in ["prompt", "draw", "guess", "wait"]


# ------------------------------------------------------------ intents --
func join() -> void:
	_intent("join", Net.local_profile()["name"])


func leave() -> void:
	_intent("leave", null)
	view = {}
	view_changed.emit(view)


func ready() -> void:
	_intent("ready", true)


func submit_text(text: String) -> void:
	_intent("submit", text)


func submit_drawing(strokes: Array) -> void:
	_intent("submit", SketchStrokes.encode(strokes))


func next_entry() -> void:
	_intent("next", null)


func play_again() -> void:
	_intent("again", null)


func _intent(action: String, value: Variant) -> void:
	if is_host():
		_host_intent(Net.local_id(), action, value)
	else:
		request_intent.rpc_id(1, action, value)


@rpc("any_peer", "call_remote", "reliable")
func request_intent(action: String, value: Variant) -> void:
	if multiplayer.is_server():
		_host_intent(multiplayer.get_remote_sender_id(), action, value)


# --------------------------------------------------------------- host --
func _host_intent(peer: int, action: String, value: Variant) -> void:
	var t := now()
	game.min_players = min_players
	match action:
		"join":
			game.join(peer, _name_of(peer, str(value)))
		"leave":
			game.leave(peer)
			_send(peer, {})
			_sent.erase(peer)
		"ready":
			game.set_ready(peer, bool(value), t)
		"submit":
			game.submit(peer, value, t)
		"next":
			if peer == game.host_peer():   # host controls the reveal
				game.next_entry()
		"again":
			if peer == game.host_peer() and game.is_reveal_done():
				game.play_again()
	_host_sync()


func _process(_delta: float) -> void:
	if not is_host():
		return
	var v := game.version
	game.tick(now())
	if game.version != v:
		_host_sync()


## Sends each member (and, during the reveal, every spectator nearby) the view they may see.
func _host_sync() -> void:
	var t := now()
	var targets: Array = game.members()
	if game.phase == SketchGame.PHASE_REVEAL:
		for p in Net.roster():  # reveal content is public: spectators can watch on the easel
			if not targets.has(int(p["id"])):
				targets.append(int(p["id"]))
	if not Net.is_online() and not targets.has(Net.local_id()):
		targets.append(Net.local_id())
	for peer in targets:
		_send(peer, game.view_for(peer, t))
		_sent[peer] = game.version


func _send(peer: int, v: Dictionary) -> void:
	if peer == Net.local_id():
		_apply(v)
	elif multiplayer.get_peers().has(peer):
		deliver_view.rpc_id(peer, v)


@rpc("authority", "call_remote", "reliable")
func deliver_view(v: Dictionary) -> void:
	_apply(v)


# -------------------------------------------------------------- local --
func _apply(v: Dictionary) -> void:
	view = _decode(v)
	view["is_host"] = int(v.get("host_peer", 0)) == Net.local_id()
	view["quiet"] = str(v.get("phase", "")) in ["prompt", "draw", "guess", "wait"]
	view_changed.emit(view)
	var phase := str(view.get("phase", ""))
	if phase != _last_phase:
		_last_phase = phase
		_animate(phase)
	if phase == "reveal":
		_show_on_easel(view["reveal"]["entries"])


# ------------------------------------------------------------- easel --
var _easel_vp: SubViewport
var _easel_canvas: SketchCanvas


## The newest revealed drawing goes up on the town easel (easel_display's blank insert) so
## people outside the table can follow the reveal.
func _show_on_easel(entries: Array) -> void:
	var strokes := []
	for e in entries:
		if e.get("strokes") is Array:
			strokes = e["strokes"]
	var easel := get_tree().root.find_child("easel_display", true, false)
	if easel == null:
		return
	if _easel_vp == null or not is_instance_valid(_easel_vp):
		_easel_vp = SubViewport.new()
		_easel_vp.size = Vector2i(512, 384)
		_easel_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := ColorRect.new()
		bg.color = Color.WHITE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_easel_vp.add_child(bg)
		_easel_canvas = SketchCanvas.new()
		_easel_canvas.editable = false
		_easel_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_easel_vp.add_child(_easel_canvas)
		easel.add_child(_easel_vp)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _easel_vp.get_texture()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mi in easel.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m and String(m.resource_name).begins_with("insert"):
					(mi as MeshInstance3D).set_surface_override_material(i, mat)
	_easel_canvas.set_strokes(strokes)


func _decode(v: Dictionary) -> Dictionary:
	var out := v.duplicate(true)
	if out.has("assignment") and out["assignment"].get("strokes") is PackedByteArray:
		out["assignment"]["strokes"] = SketchStrokes.decode(out["assignment"]["strokes"])
	if out.has("reveal"):
		for e in out["reveal"]["entries"]:
			if e.get("strokes") is PackedByteArray:
				e["strokes"] = SketchStrokes.decode(e["strokes"])
	return out


## Seated penguin plays anim_drawing per phase; the seat style replicates (Net.note_act).
const PHASE_CLIPS := {"prompt": "sketch_think", "draw": "sketch_draw", "guess": "sketch_think",
	"wait": "sketch_wait", "reveal": "sketch_reveal", "lobby": "sketch"}


func _animate(phase: String) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player == null or not player.has_method("set_seat_clip") or not bool(player.call("is_sitting")):
		return
	player.call("set_seat_clip", PHASE_CLIPS.get(phase, "sketch"))


func _name_of(peer: int, fallback: String) -> String:
	for p in Net.roster():
		if int(p["id"]) == peer:
			return str(p["name"])
	return fallback


## A peer that drops out keeps its slot (no reindexing); its turns time out as skipped.
func _on_roster_changed() -> void:
	if not is_host() or not Net.is_online():
		return
	var present := Net.roster().map(func(p): return int(p["id"]))
	for peer in game.members():
		if not present.has(peer):
			game.leave(peer)
	_host_sync()
