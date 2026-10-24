class_name Outfit
extends RefCounted
## The local player's look: coat colour index (Net.COATS) plus one avatar asset per slot.
## shortcut: saved locally in user://outfit.cfg and applied to the local penguin only; other
## players still see the default outfit until the profile service/network carries appearance.

const PATH := "user://outfit.cfg"
const SLOTS := ["head", "torso", "face", "neck", "back", "hand"]
const DEFAULT := {"color": 0, "head": "red_beanie", "torso": "hoodie", "face": "", "neck": "", "back": "", "hand": ""}


static func load_look() -> Dictionary:
	var look := DEFAULT.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in look:
			look[k] = cfg.get_value("look", k, look[k])
	return look


static func save_look(look: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	for k in DEFAULT:
		cfg.set_value("look", k, look.get(k, DEFAULT[k]))
	return cfg.save(PATH) == OK


static func coat(look: Dictionary) -> Color:
	return Net.coat_color(int(look.get("color", 0)))


static func pieces(look: Dictionary) -> Dictionary:
	var out := {}
	for s in SLOTS:
		out[s] = str(look.get(s, ""))
	return out


## Re-dresses a mounted PackAvatar (from AssetPack.mount_bird) to `look`. Idempotent.
static func dress(bird: Node3D, look: Dictionary) -> void:
	if bird == null:
		return
	Tints.apply(bird, {"body": coat(look)})
	for n in bird.get_tree().get_nodes_in_group("outfit_piece") if bird.is_inside_tree() else []:
		if bird.is_ancestor_of(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	var skeleton := bird.find_child("Skeleton3D", true, false) as Skeleton3D
	for slot in SLOTS:
		var asset := str(look.get(slot, ""))
		if asset == "":
			continue
		var parent: Node = skeleton if slot == "torso" else Sockets.find(bird, PenguinView.SOCKET.get(slot, slot))
		if parent == null:
			continue
		var before := parent.get_children()
		if slot == "torso":
			AssetPack._wear_cloth(bird, asset, Color(1, 1, 1, 0))
		else:
			AssetPack._wear_item(bird, asset, PenguinView.SOCKET[slot], Color(1, 1, 1, 0))
		for c in parent.get_children():
			if not before.has(c):
				c.add_to_group("outfit_piece")


## Applies the saved look to the local player's penguin, if one is in the scene.
static func apply_to_local_player(tree: SceneTree, look: Dictionary) -> void:
	var player := tree.get_first_node_in_group("local_player")
	if player == null:
		return
	var bird := player.find_child("PackAvatar", true, false) as Node3D
	dress(bird, look)


static func pretty(asset: String) -> String:
	return asset.replace("_", " ").capitalize()
