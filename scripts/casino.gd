extends Node3D

## Casino floor. Slots along the back, two color wheels, one poker table.


func _ready() -> void:
	var nav := $NavigationRegion3D
	_add_table(nav, "slot", "SlotA", Vector3(-6.6, 0.0, -4.8))
	_add_table(nav, "slot", "SlotB", Vector3(-4.2, 0.0, -4.8))
	_add_table(nav, "slot", "SlotC", Vector3(-1.8, 0.0, -4.8))
	_add_table(nav, "roulette", "WheelA", Vector3(-5.4, 0.0, 0.8))
	_add_table(nav, "roulette", "WheelB", Vector3(-1.6, 0.0, 0.8))
	_add_table(nav, "poker", "Poker", Vector3(5.6, 0.0, -0.2))
	var sign := Label3D.new()
	sign.text = "Casino"
	sign.font_size = 92
	sign.pixel_size = 0.012
	sign.outline_size = 12
	sign.modulate = Color(0.98, 0.94, 0.86)
	sign.outline_modulate = Color(0.08, 0.2, 0.28)
	sign.position = Vector3(0.0, 2.15, -7.55)
	nav.add_child(sign)
	if nav.has_method("rebake"):
		nav.call("rebake")


func camera_for_spawn(_spawn_name: String) -> Dictionary:
	return {
		"center": Vector3(0.0, 0.0, -0.4),
		"limit_x": 9.2,
		"limit_z": 6.4,
		"height": 11.5,
		"distance": 8.8,
	}


func _add_table(nav: Node, kind: String, node_name: String, at: Vector3) -> void:
	var table := StaticBody3D.new()
	table.name = node_name
	table.set_script(load("res://scripts/casino_table.gd"))
	table.set("kind", kind)
	table.position = at
	nav.add_child(table)
