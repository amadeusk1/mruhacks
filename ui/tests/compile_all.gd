extends Node
## Loads every script under res://ui so parse/type errors surface in CI-style runs.
func _ready() -> void:
	var bad := 0
	for f in _walk("res://ui") + _walk("res://tools") + _walk("res://scripts"):
		if f.ends_with(".gd") and not (load(f) as GDScript).can_instantiate():
			bad += 1
			print("FAILED ", f)
	print("UI_COMPILE ", "PASS" if bad == 0 else "FAIL %d" % bad)
	get_tree().quit()
func _walk(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out += _walk(dir + "/" + d)
	return out
