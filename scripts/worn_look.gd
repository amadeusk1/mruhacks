class_name WornLook
extends RefCounted
## Catalog-safe outfit data shared by the wardrobe and the net roster.
## This script does not reference Net, so the two can load without a cycle.

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


static func pieces(look: Dictionary) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		out[slot] = str(look.get(slot, ""))
	return out


## Known coat index, and only catalog assets that belong in that slot.
static func sanitize(raw: Dictionary, coat_count: int = 6) -> Dictionary:
	var look := DEFAULT.duplicate()
	look["color"] = posmod(int(raw.get("color", look["color"])), maxi(coat_count, 1))
	for slot in SLOTS:
		look[slot] = _known_piece(slot, str(raw.get(slot, "")))
	return look


static func signature(look: Dictionary, coat_count: int = 6) -> String:
	var clean := sanitize(look, coat_count)
	var parts: PackedStringArray = [str(clean["color"])]
	for slot in SLOTS:
		parts.append(str(clean[slot]))
	return "|".join(parts)


static func _known_piece(slot: String, asset: String) -> String:
	if asset == "":
		return ""
	if asset.length() > 32 or not asset.is_valid_identifier():
		return ""
	var id := "avatar/" + asset
	if not AssetRegistry.has(id):
		return ""
	if str(AssetRegistry.entry(id).get("slot", "")) != slot:
		return ""
	return asset
