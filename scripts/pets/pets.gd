class_name Pets
extends RefCounted
## Pet catalog, ownership and coins. Pets come from Models/pets/manifest.json (slot "pet"),
## adopted pets are saved in user://pets.cfg, and the active pet rides in the worn look
## ("pet" key) so Net syncs it with the outfit. PetFollower walks it after its bird.

const PATH := "user://pets.cfg"
const WALLET := "user://wallet.cfg"


## [{id, name, price, blurb}] in shop order (cheapest first).
static func catalog() -> Array:
	var out := []
	for id in AssetRegistry.ids():
		var e := AssetRegistry.entry(str(id))
		if str(e.get("slot", "")) != "pet":
			continue
		out.append({"id": str(id).get_slice("/", 1), "name": str(e.get("display_name", id)),
				"price": int(e.get("price", 0)), "blurb": str(e.get("blurb", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["price"]) < int(b["price"]))
	return out


static func info(pet: String) -> Dictionary:
	for p in catalog():
		if p["id"] == pet:
			return p
	return {}


## A pet's own emotes from its manifest: [{id, name, owner_clip}]. Played as "pet/<id>".
static func emotes(pet: String) -> Array:
	return AssetRegistry.entry("pets/" + pet).get("emotes", [])


static func owned() -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return PackedStringArray()
	return PackedStringArray(cfg.get_value("pets", "owned", PackedStringArray()))


static func owns(pet: String) -> bool:
	return pet in owned()


static func _add_owned(pet: String) -> void:
	var have := owned()
	if pet in have:
		return
	have.append(pet)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("pets", "owned", have)
	cfg.save(PATH)


# ------------------------------------------------------------------ coins --
## The HUD shows the live count; the wallet file keeps it between sessions.
static func coins(tree: SceneTree) -> int:
	var hud := tree.get_first_node_in_group("play_hud")
	return int(hud.coins) if hud else load_coins()


static func load_coins() -> int:
	var cfg := ConfigFile.new()
	return int(cfg.get_value("wallet", "coins", 0)) if cfg.load(WALLET) == OK else 0


static func save_coins(amount: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wallet", "coins", maxi(0, amount))
	cfg.save(WALLET)


## Spends the pet's price and adopts it. False when it is unknown or unaffordable.
static func buy(tree: SceneTree, pet: String) -> bool:
	var p := info(pet)
	if p.is_empty():
		return false
	if owns(pet):
		return true
	var have := coins(tree)
	if have < int(p["price"]):
		return false
	var hud := tree.get_first_node_in_group("play_hud")
	if hud:
		hud.set_coins(have - int(p["price"]))
	else:
		save_coins(have - int(p["price"]))
	_add_owned(pet)
	return true


# ------------------------------------------------------------------ world --
## Gives `penguin` a PetFollower for `pet` (or removes it for ""). Idempotent.
static func attach(penguin: Node3D, pet: String, coat: Color) -> void:
	if penguin == null:
		return
	var cur := penguin.get_node_or_null("Pet") as PetFollower
	if cur and cur.species == pet:
		cur.set_coat(coat)
		return
	if cur:
		penguin.remove_child(cur)
		cur.queue_free()
	if pet == "" or not AssetRegistry.has("pets/" + pet):
		return
	var f := PetFollower.new()
	f.name = "Pet"
	f.species = pet
	f.coat = coat
	penguin.add_child(f)
