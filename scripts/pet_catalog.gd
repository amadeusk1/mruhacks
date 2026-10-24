class_name PetCatalog
extends RefCounted

## Two pets. Pengi walks free. The fish floats beside you on a leash.
## Prices are coins. Models live in Models/pets/.

const ORDER := ["pengi", "fish"]

const PETS := {
	"pengi": {
		"name": "Pengi",
		"price": 10,
		"family": "penguin",
		"model": "pet_pebble",
		"line": "A baby penguin. Walks behind you.",
		"swatch": Color(0.24, 0.48, 0.85),
	},
	"fish": {
		"name": "Fish",
		"price": 25,
		"family": "fish",
		"model": "pet_minnow",
		"line": "Floats beside you on a leash.",
		"swatch": Color(0.94, 0.54, 0.18),
	},
}


static func find(id: String) -> Dictionary:
	return PETS.get(id, {})
