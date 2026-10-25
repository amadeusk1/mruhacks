extends Node

## Hosts the normal world, but re-dresses penguins by player name on this screen only, to match
## the pitch deck's "Revitalizing" slide. Networked outfits still go out on the roster; this
## override is local to the filming camera. Nothing is saved: user://outfit.cfg is left alone.
##   Godot --path . res://tools/film_host.tscn -- --net-host --net-name=Host
## Then start the followers: tools/follow_bots.sh 4 (Pip, Mochi, Waddles, Biscuit).

const LOOKS := {
	"Host": {"body": Color(0.55, 0.35, 0.80), "head": "frog_hood"},
	"Pip": {"body": Color(0.27, 0.52, 0.85), "head": "red_beanie"},
	"Mochi": {"body": Color(0.93, 0.55, 0.72), "head": "wizard_hat"},
	"Waddles": {"body": Color(0.96, 0.80, 0.30), "head": "explorer_hat"},
	"Biscuit": {"body": Color(0.30, 0.75, 0.80), "head": ""},
}
const SOCKETS := ["head", "face", "neck", "back"]  # not the hand: rods and props live there

var _w: Node
var _keep_ui := false  # --ui: film with the HUD and the walk-path preview showing, as a player sees it


func _ready() -> void:
	_keep_ui = OS.get_cmdline_user_args().has("--ui")
	_w = load("res://scenes/world.tscn").instantiate()  # reads --net-host / --net-name itself
	get_tree().root.add_child.call_deferred(_w)
	var tick := Timer.new()
	tick.wait_time = 0.5
	tick.autostart = true
	tick.timeout.connect(_restyle)
	add_child(tick)


func _restyle() -> void:
	if not _w.is_inside_tree() or not _w.get("_in_game"):
		return
	_style(_w.get_node("Penguin"), str(Net.local_profile()["name"]))
	for e in Net.roster():
		var puppet: Node = (_w.get("_puppets") as Dictionary).get(int(e.get("id", 0)))
		if puppet != null and is_instance_valid(puppet):
			_style(puppet, str(e.get("name", "")))


func _style(penguin: Node, player_name: String) -> void:
	if not LOOKS.has(player_name):
		return
	var bird := penguin.find_child("PackAvatar", true, false) as Node3D
	if bird == null:
		return
	var look: Dictionary = LOOKS[player_name]
	if bird.get_meta("film_look", "") != player_name:
		_strip(bird)
		var head := str(look["head"])
		if head != "":
			AssetPack._wear_item(bird, head, PenguinView.SOCKET["head"], Color(1, 1, 1, 0))
		bird.set_meta("film_look", player_name)
	# every tick: a roster update can re-tint the body from the shared coat palette
	Tints.apply(bird, {"body": look["body"]})


## Removes the default hoodie/beanie (and any wardrobe pieces) so only the base bird is left.
func _strip(bird: Node3D) -> void:
	var skeleton := bird.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for c in skeleton.get_children():
			if c is MeshInstance3D and c.name != "avatar_base_mesh":
				c.queue_free()
	for s in SOCKETS:
		var socket := Sockets.find(bird, PenguinView.SOCKET[s])
		if socket != null:
			for c in socket.get_children():
				c.queue_free()
