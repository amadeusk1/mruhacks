class_name CinemaAmbience
extends Node
## Movie-night mood in the auditorium (cinema port 5/5, flag pengloo/cinema/ambience): while the shared
## film plays, the hall's own lights dim, a spill light in front of the screen takes the picture's
## average colour, and a seated local player's camera eases toward the screen. All undone on pause.

const DIM := 0.3
const SAMPLE_S := 0.5

var hall: Node3D
var screen_at := Vector3.ZERO     ## world position of the screen centre
var player: CinemaScreenPlayer
var _spill: OmniLight3D
var _lights := {}                 ## OmniLight3D -> base energy
var _pinned: Node = null
var _sample_in := 0.0


static func attach(hall_node: Node3D, screen: CinemaScreen) -> CinemaAmbience:
	var a := CinemaAmbience.new()
	a.name = "CinemaAmbience"
	a.hall = hall_node
	a.player = screen.player
	a.screen_at = screen.global_position
	hall_node.add_child(a)
	return a


func _ready() -> void:
	# the dressing's glow lights hang off the spawned auditorium root, one level above the mesh node
	var lit := hall.get_parent() if hall.get_parent() and String(hall.get_parent().name).begins_with("cinema_auditorium") else hall
	for l in lit.find_children("*", "OmniLight3D", true, false):
		_lights[l] = (l as OmniLight3D).light_energy
	_spill = OmniLight3D.new()
	_spill.name = "ScreenSpill"
	_spill.omni_range = 9.0
	_spill.light_energy = 0.0
	_spill.shadow_enabled = false
	hall.add_child(_spill)
	_spill.global_position = screen_at + (hall.global_position - screen_at).normalized() * 2.5
	player.playing_changed.connect(_on_playing)
	_on_playing(player.playing)


func _on_playing(on: bool) -> void:
	for l in _lights:
		if is_instance_valid(l):
			l.create_tween().tween_property(l, "light_energy", _lights[l] * (DIM if on else 1.0), 1.5)
	_spill.create_tween().tween_property(_spill, "light_energy", 1.2 if on else 0.0, 1.5)
	if not on:
		_unpin()


func _process(delta: float) -> void:
	if not player.playing:
		return
	_sample_in -= delta
	if _sample_in <= 0.0 and player.texture:
		_sample_in = SAMPLE_S
		var img := player.texture.get_image()  # 640x360: shrinking to 1 px averages the frame
		img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		_spill.light_color = img.get_pixel(0, 0).lightened(0.15)
	_follow_camera()


## Seated in this hall: ease the follow camera toward the screen; standing up releases it.
func _follow_camera() -> void:
	var me := get_tree().get_first_node_in_group("local_player")
	var seat: Node = me.call("current_bench") if me and me.has_method("current_bench") else null
	var seated_here: bool = seat is SeatSpot and (seat as SeatSpot).kit == "cinema"
	var cam: Node = get_viewport().get_camera_3d()
	if cam and not cam.has_method("pin_focus"):
		cam = cam.get_parent()  # the follow rig owns the Camera3D
	if seated_here and cam and cam.has_method("pin_focus") and _pinned == null:
		# the rig sits at focus + (0, height, distance) looking at focus + look_y: put the focus under the
		# screen so the camera ends up just behind the seated player, aimed at the picture
		var seat_z := (me as Node3D).global_position.z
		cam.call("pin_focus", Vector3(screen_at.x, 0.0, screen_at.z), 4.2, absf(seat_z - screen_at.z) + 7.0, screen_at.y - 0.6)
		_pinned = cam
	elif not seated_here:
		_unpin()


func _unpin() -> void:
	if is_instance_valid(_pinned) and _pinned.has_method("unpin_focus"):
		_pinned.call("unpin_focus")
	_pinned = null


func _exit_tree() -> void:
	_unpin()
