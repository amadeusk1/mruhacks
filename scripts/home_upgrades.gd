class_name HomeUpgrades
extends RefCounted
## House upgrade tiers for the player's snow dome (docs/Housing - House Upgrades Plan.md).
## Each tier is the same igloo built bigger: homes/<shell>_exterior and homes/<shell>_interior.
## The owned tier is saved in user://home_choice.cfg [home] tier; furniture follows on upgrade
## (DecorEditor.migrate_from), so the old layout file is kept as a backup.

const PATH := "user://home_choice.cfg"
const TIERS := [
	{"tier": 1, "name": "Snow Dome", "shell": "snow_dome", "price": 0},
	{"tier": 2, "name": "Big Dome", "shell": "snow_dome_t2", "price": 120},
]


static func tier() -> int:
	var cfg := ConfigFile.new()
	var t := int(cfg.get_value("home", "tier", 1)) if cfg.load(PATH) == OK else 1
	return clampi(t, 1, TIERS.size())


static func info(t: int) -> Dictionary:
	return TIERS[clampi(t, 1, TIERS.size()) - 1]


## The next tier to buy, or {} when the house is fully upgraded.
static func next_tier() -> Dictionary:
	var t := tier()
	return TIERS[t] if t < TIERS.size() else {}


static func interior_id(t: int = 0) -> String:
	return "homes/%s_interior" % info(t if t > 0 else tier())["shell"]


static func exterior_id(t: int = 0) -> String:
	return "homes/%s_exterior" % info(t if t > 0 else tier())["shell"]


## Tier of a shell id ("homes/snow_dome_t2_interior" -> 2), 0 if it is not a dome tier.
static func tier_of(shell_id: String) -> int:
	for e in TIERS:
		if shell_id == "homes/%s_interior" % e["shell"]:
			return int(e["tier"])
	return 0


## Floor cells you can furnish (cells minus the doorway) and wall spots of a tier's interior.
static func space(t: int) -> Dictionary:
	var e := AssetRegistry.entry(interior_id(t))
	var cells: Array = e.get("cells", [])
	var blocked: Array = e.get("blocked_cells", [])
	var slots = e.get("wall_slots", {})
	return {"floor": cells.size() - blocked.size(), "wall": (slots as Dictionary).size() if slots is Dictionary else 0}


## Spends the next tier's price and saves it. False when maxed out or short on coins.
static func buy_next(tree: SceneTree) -> bool:
	var n := next_tier()
	if n.is_empty() or not Coins.spend(tree, int(n["price"])):
		return false
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("home", "tier", int(n["tier"]))
	cfg.save(PATH)
	return true
