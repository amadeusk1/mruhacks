extends Node3D

## A pet napping in the plaza pen: a pets-kit model idling in place (PetFollower display mode).
## Without a species it falls back to the old round placeholder that bobs in place.

@export var species := ""
@export var coat_color := Color(0.95, 0.55, 0.42)
@export var bob_speed := 1.5
@export var bob_height := 0.045

var _base_y := 0.0
var _phase := 0.0


func _ready() -> void:
	if species != "" and AssetRegistry.has("pets/" + species):
		for c in get_children():
			c.queue_free()
		var pet := PetFollower.new()
		pet.species = species
		pet.display = true
		pet.coat = coat_color
		add_child(pet)
		set_process(false)
		return
	_base_y = position.y
	_phase = randf() * TAU
	var mesh := $Body as MeshInstance3D
	var mat := mesh.get_surface_override_material(0)
	if mat:
		mat = mat.duplicate()
		mat.albedo_color = coat_color
		mesh.set_surface_override_material(0, mat)


func _process(delta: float) -> void:
	_phase += delta * bob_speed
	position.y = _base_y + sin(_phase) * bob_height
	rotation.y += delta * 0.3
