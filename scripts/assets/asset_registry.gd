extends Node

## Catalog of the art pack: every entry of every res://Models/*/manifest.json, keyed by id
## ("cafe/cafe_exterior"). Manifest fields are documented in docs/Art Pipeline.md.
## Sizes in manifests are Blender [x, y, z]; size() returns them as a Godot Vector3 (x, z, y).

const ROOT := "res://Models"

var _entries := {}


func _ready() -> void:
	for kit in DirAccess.get_directories_at(ROOT):
		var path := "%s/%s/manifest.json" % [ROOT, kit]
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Array:
			push_error("AssetRegistry: unreadable manifest %s" % path)
			continue
		for entry in data:
			_entries[str(entry["id"])] = entry


func has(id: String) -> bool:
	return _entries.has(id)


func entry(id: String) -> Dictionary:
	return _entries.get(id, {})


func ids() -> Array:
	return _entries.keys()


func scene(id: String) -> PackedScene:
	if not _entries.has(id):
		push_error("AssetRegistry: unknown asset %s" % id)
		return null
	return load("%s/%s" % [ROOT, _entries[id]["file"]]) as PackedScene


func instantiate(id: String) -> Node3D:
	var packed := scene(id)
	return packed.instantiate() as Node3D if packed else null


func size(id: String) -> Vector3:
	var s: Array = entry(id).get("size_m", [1, 1, 1])
	return Vector3(s[0], s[2], s[1])


func icon(id: String) -> Texture2D:
	var p := str(entry(id).get("icon", ""))
	return load("%s/%s" % [ROOT, p]) as Texture2D if p != "" else null


func sockets(id: String) -> Dictionary:
	return entry(id).get("sockets", {})


func parts(id: String) -> Dictionary:
	return entry(id).get("parts", {})
