class_name HomeUpgrades
extends RefCounted
## The house you live in and its upgrade tiers (docs/Housing - House Upgrades Plan.md).
## Six house types; each tier is the same house built bigger: homes/<shell>_exterior and
## homes/<shell>_interior. user://home_choice.cfg keeps the type in [home] shell and the owned
## tier of each type in [tiers], so switching houses never loses an upgrade. Each shell keeps its
## own layout file; furniture follows into a new shell (DecorEditor.migrate_from).

const PATH := "user://home_choice.cfg"
const DEFAULT_HOUSE := "snow_dome"
const HOUSES := {
	"snow_dome": [
		{"tier": 1, "name": "Snow Dome", "shell": "snow_dome", "price": 0},
		{"tier": 2, "name": "Big Dome", "shell": "snow_dome_t2", "price": 120},
	],
	"aframe_cabin": [
		{"tier": 1, "name": "A-frame", "shell": "aframe_cabin", "price": 0},
		{"tier": 2, "name": "Long A-frame", "shell": "aframe_cabin_t2", "price": 110},
	],
	"round_cottage": [
		{"tier": 1, "name": "Cottage", "shell": "round_cottage", "price": 0},
		{"tier": 2, "name": "Big Cottage", "shell": "round_cottage_t2", "price": 120},
	],
	"treehouse": [
		{"tier": 1, "name": "Treehouse", "shell": "treehouse", "price": 0},
		{"tier": 2, "name": "Big Treehouse", "shell": "treehouse_t2", "price": 80},
	],
	"lighthouse_loft": [
		{"tier": 1, "name": "Lighthouse", "shell": "lighthouse_loft", "price": 0},
		{"tier": 2, "name": "Keeper's Lighthouse", "shell": "lighthouse_loft_t2", "price": 120},
	],
	"houseboat": [
		{"tier": 1, "name": "Houseboat", "shell": "houseboat", "price": 0},
		{"tier": 2, "name": "Big Houseboat", "shell": "houseboat_t2", "price": 80},
	],
}


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg


## The house type you live in.
static func house() -> String:
	var h := str(_cfg().get_value("home", "shell", DEFAULT_HOUSE))
	return h if HOUSES.has(h) else DEFAULT_HOUSE


## Moves you into another house type. The one you leave is remembered so your furniture can follow.
static func set_house(h: String) -> void:
	if not HOUSES.has(h) or h == house():
		return
	var cfg := _cfg()
	cfg.set_value("home", "last_shell", interior_id())
	cfg.set_value("home", "shell", h)
	cfg.save(PATH)


## Tier you own of a house type ("" = the one you live in). Saves from before [tiers] kept the
## dome's tier in [home] tier.
static func tier(h: String = "") -> int:
	h = h if h != "" else house()
	var cfg := _cfg()
	var t := int(cfg.get_value("tiers", h, cfg.get_value("home", "tier", 1) if h == DEFAULT_HOUSE else 1))
	return clampi(t, 1, HOUSES[h].size())


## t 0 = the tier you own.
static func info(t: int = 0, h: String = "") -> Dictionary:
	h = h if h != "" else house()
	var list: Array = HOUSES[h]
	return list[clampi(t if t > 0 else tier(h), 1, list.size()) - 1]


## The next tier to buy, or {} when the house is fully upgraded.
static func next_tier(h: String = "") -> Dictionary:
	h = h if h != "" else house()
	var t := tier(h)
	return HOUSES[h][t] if t < HOUSES[h].size() else {}


static func interior_id(t: int = 0, h: String = "") -> String:
	return "homes/%s_interior" % info(t, h)["shell"]


static func exterior_id(t: int = 0, h: String = "") -> String:
	return "homes/%s_exterior" % info(t, h)["shell"]


## House type of an interior id ("homes/treehouse_t2_interior" -> "treehouse"), "" if unknown.
static func house_of(shell_id: String) -> String:
	for h in HOUSES:
		if tier_of(shell_id, h) > 0:
			return h
	return ""


## Tier of an interior id within a house type, 0 if it is not one of its shells.
static func tier_of(shell_id: String, h: String) -> int:
	for e in HOUSES.get(h, []):
		if shell_id == "homes/%s_interior" % e["shell"]:
			return int(e["tier"])
	return 0


## Whose saved furniture a shell with no layout yet starts from: the tier below it, otherwise
## the house you just left. "" when there is none.
static func move_source(shell_id: String) -> String:
	var h := house_of(shell_id)
	var t := tier_of(shell_id, h)
	var below := interior_id(t - 1, h) if t > 1 else ""
	if below != "" and FileAccess.file_exists(DecorEditor.path_for(below)):
		return below
	var last := str(_cfg().get_value("home", "last_shell", ""))
	return last if last != shell_id and house_of(last) != "" and FileAccess.file_exists(DecorEditor.path_for(last)) else ""


## Half size of an interior's floor in metres, x and y as authored (round rooms: the radius).
static func extents(shell_id: String) -> Vector2:
	var e := AssetRegistry.entry(shell_id)
	if e.has("radius_m"):
		return Vector2.ONE * float(e["radius_m"])
	var m := float(e.get("cell_m", 0.5))
	var o: Array = e.get("cell_origin", [0, 0])
	var half := Vector2.ZERO
	for c in e.get("cells", []):
		var at := Vector2(float(o[0]) + float(c[0]) * m, float(o[1]) + float(c[1]) * m)
		half.x = maxf(half.x, maxf(absf(at.x), absf(at.x + m)))
		half.y = maxf(half.y, maxf(absf(at.y), absf(at.y + m)))
	return half


## Floor cells you can furnish (cells minus the doorway) and wall spots of a tier's interior.
static func space(t: int = 0, h: String = "") -> Dictionary:
	var e := AssetRegistry.entry(interior_id(t, h))
	var cells: Array = e.get("cells", [])
	var blocked: Array = e.get("blocked_cells", [])
	var slots = e.get("wall_slots", {})
	return {"floor": cells.size() - blocked.size(), "wall": (slots as Dictionary).size() if slots is Dictionary else 0}


## Spends the next tier's price and saves it. False when maxed out or short on coins.
static func buy_next(tree: SceneTree) -> bool:
	var n := next_tier()
	if n.is_empty() or not Coins.spend(tree, int(n["price"])):
		return false
	var cfg := _cfg()
	cfg.set_value("tiers", house(), int(n["tier"]))
	cfg.save(PATH)
	return true
