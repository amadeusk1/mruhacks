extends SceneTree
## Outfit replication: only catalog pieces survive, and the roster carries the worn look.


func _init() -> void:
	await process_frame
	var look: Script = load("res://scripts/worn_look.gd")
	var bad: Dictionary = look.sanitize({
		"color": 99,
		"head": "../avatar_base",
		"torso": "raincoat",
		"face": "mug",
		"neck": "",
		"back": "backpack",
		"hand": "not_a_real_asset",
	})
	var net: Node = root.get_node("Net")
	var coats: int = net.get_script().COATS.size()
	assert(int(bad["color"]) == posmod(99, coats), "coat wraps the palette")
	assert(str(bad["head"]) == "", "path pieces are dropped")
	assert(str(bad["torso"]) == "raincoat", "torso asset kept")
	assert(str(bad["face"]) == "", "mug is not a face")
	assert(str(bad["back"]) == "backpack", "back asset kept")
	assert(str(bad["hand"]) == "", "unknown asset dropped")
	net._players = {2: net._blank(2, "Pip", 0)}
	assert(net._remember_outfit(2, bad), "first look is stored")
	assert(not net._remember_outfit(2, bad), "identical look does not broadcast again")
	var snap: Array = net._snapshot()
	var row: Dictionary = snap[0]
	assert(int(row["color"]) == int(bad["color"]), "roster coat follows the look")
	assert(str(row["outfit"]["torso"]) == "raincoat", "roster carries the torso")
	assert(str(row["outfit"]["head"]) == "", "roster does not invent a hat")
	assert(look.signature(row["outfit"]) == look.signature(look.pieces(bad)), "pieces round-trip")
	for path in ["res://ui/activities/outfit.gd", "res://scripts/penguin_movement.gd", "res://scripts/sled_controller.gd", "res://scripts/world.gd", "res://scripts/sled_run.gd"]:
		var compiled: Script = load(path)
		assert(compiled != null, "compiled %s" % path)
	print("OUTFIT_SYNC_PASS")
	quit(0)
