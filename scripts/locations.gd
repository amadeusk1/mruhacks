extends RefCounted
class_name LocationCatalog

## Places the bus can reach. Sled Hill is the downhill run.

const ORDER: Array[String] = ["town", "plaza", "cinema", "sled_hill", "court"]

## Where new sessions start and activities return to.
const MAIN := "town"

const _PLACES := {
	"home": {
		"title": "Your House",
		"scene": "res://scenes/locations/home.tscn",
		"map": Vector2(0.3, 0.28),
	},
	"town": {
		"title": "Town",
		"scene": "res://scenes/locations/town.tscn",
		"map": Vector2(0.46, 0.55),
	},
	"cafe": {
		"title": "Café",
		"scene": "res://scenes/locations/cafe.tscn",
		"map": Vector2(0.4, 0.5),
	},
	"arcade": {
		"title": "Arcade",
		"scene": "res://scenes/locations/arcade.tscn",
		"map": Vector2(0.52, 0.5),
	},
	"casino": {
		"title": "Casino",
		"scene": "res://scenes/locations/casino.tscn",
		"map": Vector2(0.7, 0.45),
	},
	"plaza": {
		"title": "Shops",
		"scene": "res://scenes/locations/plaza.tscn",
		"map": Vector2(0.34, 0.64),
	},
	"cinema": {
		"title": "Cinema",
		"scene": "res://scenes/locations/cinema.tscn",
		"map": Vector2(0.56, 0.78),
	},
	"sled_hill": {
		"title": "Sled Hill",
		"scene": "res://scenes/sled_run.tscn",
		"map": Vector2(0.63, 0.4),
	},
	"court": {
		"title": "The Court",
		"scene": "res://scenes/locations/court.tscn",
		"map": Vector2(0.78, 0.62),
	},
}


static func ordered_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(ORDER)
	return ids


static func has_location(location_id: String) -> bool:
	return _PLACES.has(location_id)


static func title_of(location_id: String) -> String:
	return str(_PLACES[location_id]["title"])


static func scene_path(location_id: String) -> String:
	return str(_PLACES[location_id]["scene"])


static func map_point(location_id: String) -> Vector2:
	return _PLACES[location_id]["map"]
