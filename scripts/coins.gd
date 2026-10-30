class_name Coins
extends RefCounted
## The player's coins: the HUD shows the live count and the wallet file keeps it between
## sessions. Every shop (pets, wardrobe, house upgrades) spends through spend().

const WALLET := "user://wallet.cfg"


static func have(tree: SceneTree) -> int:
	var hud := tree.get_first_node_in_group("play_hud") if tree else null
	return int(hud.coins) if hud else load_saved()


static func load_saved() -> int:
	var cfg := ConfigFile.new()
	return int(cfg.get_value("wallet", "coins", 0)) if cfg.load(WALLET) == OK else 0


static func save(amount: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wallet", "coins", maxi(0, amount))
	cfg.save(WALLET)


## Takes `price` coins. False (and nothing spent) when there aren't enough.
static func spend(tree: SceneTree, price: int) -> bool:
	if price < 1:
		return true
	var n := have(tree)
	if n < price:
		return false
	var hud := tree.get_first_node_in_group("play_hud") if tree else null
	if hud:
		hud.set_coins(n - price)
	else:
		save(n - price)
	return true
