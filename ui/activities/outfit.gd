class_name Outfit
extends RefCounted

const WornLook := preload("res://scripts/worn_look.gd")
## The player's look: coat colour index (Net.COATS) plus one avatar asset per slot.
## Saved in user://outfit.cfg. Net publishes the same look so other players dress their copy of you.

const PATH := WornLook.PATH
const SLOTS := WornLook.SLOTS
const DEFAULT := WornLook.DEFAULT


static func load_look() -> Dictionary:
	return WornLook.load_look()


static func save_look(look: Dictionary) -> bool:
	return WornLook.save_look(look)


static func coat(look: Dictionary) -> Color:
	return Net.coat_color(int(look.get("color", 0)))


static func pieces(look: Dictionary) -> Dictionary:
	return WornLook.pieces(look)


static func sanitize(raw: Dictionary) -> Dictionary:
	return WornLook.sanitize(raw, Net.COATS.size())


static func signature(look: Dictionary) -> String:
	return WornLook.signature(look, Net.COATS.size())


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
	Pets.attach(player as Node3D, str(look.get("pet", "")), coat(look))


static func pretty(asset: String) -> String:
	return asset.replace("_", " ").capitalize()
