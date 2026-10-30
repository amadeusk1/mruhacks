extends RefCounted
## Coin prices for wardrobe colors and clothes. The starting coat, beanie and hoodie are
## already owned, and so is whatever you are wearing, so a saved look is not locked away.

const PATH := "user://wardrobe.cfg"
const PRICE := {
	"red_beanie": 10, "frog_hood": 25, "explorer_hat": 18, "wizard_hat": 30, "bucket_hat": 14, "headphones": 22,
	"hoodie": 15, "varsity_jacket": 28, "raincoat": 20, "overalls": 18, "striped_tee": 12, "puffer_vest": 24,
	"cafe_apron": 16, "wizard_robe": 32,
	"backpack": 20, "rolltop_backpack": 26, "crossbody_bag": 16,
	"glasses": 12, "scarf": 10, "mug": 8, "fishing_rod": 22, "watering_can": 14, "wand": 28,
}
const COLOR := [8, 12, 12, 16, 18, 14]
const FALLBACK := 15


static func item_price(asset: String) -> int:
	return int(PRICE.get(asset, FALLBACK))


static func color_price(index: int) -> int:
	return COLOR[index] if index >= 0 and index < COLOR.size() else FALLBACK


static func owns_item(asset: String) -> bool:
	return asset in _owned("items")


static func owns_color(index: int) -> bool:
	return str(index) in _owned("colors")


## Grants the starter look and anything already worn.
static func claim_worn(look: Dictionary) -> void:
	var items := _owned("items")
	var colors := _owned("colors")
	var changed := false
	for asset in ["red_beanie", "hoodie"]:
		if not asset in items:
			items.append(asset)
			changed = true
	for slot in ["head", "torso", "face", "neck", "back", "hand"]:
		var asset := str(look.get(slot, ""))
		if asset != "" and not asset in items:
			items.append(asset)
			changed = true
	for key in ["0", str(int(look.get("color", 0)))]:
		if not key in colors:
			colors.append(key)
			changed = true
	if changed:
		_save("items", items)
		_save("colors", colors)


static func buy_item(tree: SceneTree, asset: String) -> bool:
	if owns_item(asset):
		return true
	if not _pay(tree, item_price(asset)):
		return false
	var items := _owned("items")
	items.append(asset)
	_save("items", items)
	return true


static func buy_color(tree: SceneTree, index: int) -> bool:
	if owns_color(index):
		return true
	if not _pay(tree, color_price(index)):
		return false
	var colors := _owned("colors")
	colors.append(str(index))
	_save("colors", colors)
	return true


static func _pay(tree: SceneTree, price: int) -> bool:
	if price < 1:
		return true
	var have := Pets.coins(tree)
	if have < price:
		return false
	var hud := tree.get_first_node_in_group("play_hud")
	if hud:
		hud.set_coins(have - price)
	else:
		Pets.save_coins(have - price)
	return true


static func _owned(section: String) -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return PackedStringArray()
	return PackedStringArray(cfg.get_value(section, "owned", PackedStringArray()))


static func _save(section: String, owned: PackedStringArray) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, "owned", owned)
	cfg.save(PATH)
