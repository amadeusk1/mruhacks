class_name PetCatalog
extends RefCounted

## Pets sold in the pet shop. Models live in Models/pets/.
## Penguins walk. Fish hover beside you. Prices are coins.

const ORDER := ["pebble", "puff", "tuxedo", "minnow", "ribbon", "puffer"]

const PETS := {
	"pebble": {
		"name": "Pebble",
		"price": 10,
		"family": "penguin",
		"model": "pet_pebble",
		"line": "A small penguin. Walks behind you.",
		"swatch": Color(0.24, 0.48, 0.85),
	},
	"puff": {
		"name": "Puff",
		"price": 25,
		"family": "penguin",
		"model": "pet_puff",
		"line": "Fluffy and wider. Waddles behind you.",
		"swatch": Color(0.95, 0.76, 0.19),
	},
	"tuxedo": {
		"name": "Tuxedo",
		"price": 40,
		"family": "penguin",
		"model": "pet_tuxedo",
		"line": "Taller, with yellow cheeks. Walks just ahead.",
		"swatch": Color(0.23, 0.24, 0.27),
	},
	"minnow": {
		"name": "Minnow",
		"price": 15,
		"family": "fish",
		"model": "pet_minnow",
		"line": "A round fish. Floats beside you.",
		"swatch": Color(0.94, 0.54, 0.18),
	},
	"ribbon": {
		"name": "Ribbon",
		"price": 30,
		"family": "fish",
		"model": "pet_ribbon",
		"line": "Long and teal. Glides at your side.",
		"swatch": Color(0.25, 0.70, 0.71),
	},
	"puffer": {
		"name": "Puffer",
		"price": 45,
		"family": "fish",
		"model": "pet_puffer",
		"line": "Small, with a tall fin. Hovers a little higher.",
		"swatch": Color(0.65, 0.52, 0.85),
	},
}


static func find(id: String) -> Dictionary:
	return PETS.get(id, {})
