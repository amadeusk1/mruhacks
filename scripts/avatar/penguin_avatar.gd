extends Node3D

## The "Visual" child of penguin.tscn: swaps the placeholder primitives for the art pack's
## rigged penguin (Models/avatar/avatar_base.glb) and drives the anim kits by bone name.
## penguin_movement.gd calls animate() every frame and set_coat() for the player colour.

const AVATAR := "res://Models/avatar/avatar_base.glb"
const LIBS := {
	"loco": "res://Models/anim_locomotion/avatar_base.glb",
	"emotes": "res://Models/anim_emotes/avatar_base.glb",
	"social": "res://Models/anim_social/avatar_base.glb",
}
const WALK_MPS := 0.3334  # anim_locomotion manifest speed_mps
const RUN_MPS := 1.1
const RUN_ABOVE := 1.4    # m/s: switch from walk to run
const MAX_SCALE := 2.6    # shortcut: the walk motor tops out at 4.5 m/s, faster than the run clip; feet slide past this

var bird: Node3D
var _player: AnimationPlayer
var _emote := ""


func _ready() -> void:
	for child in get_children():  # placeholder capsule penguin
		remove_child(child)
		child.free()
	bird = load(AVATAR).instantiate()
	bird.rotation.y = PI  # art faces +Z, the walk motor's forward is -Z
	add_child(bird)
	Tints.prepare(bird)
	_player = AnimationPlayer.new()
	bird.add_child(_player)
	_player.root_node = NodePath("..")
	for lib in LIBS:
		var src: Node = load(LIBS[lib]).instantiate()
		var ap := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		_player.add_animation_library(lib, ap.get_animation_library(ap.get_animation_library_list()[0]))
		src.free()
	_player.animation_finished.connect(func(_n): _emote = "")
	_player.play("loco/idle")


func set_coat(color: Color) -> void:
	Tints.apply(bird, {"body": color})


## One-shot or looping emote from anim_emotes ("emote_wave", "emote_dance"...). Moving cancels it.
func emote(clip: String) -> void:
	if _player.has_animation("emotes/" + clip):
		_emote = "emotes/" + clip
		_player.play(_emote, 0.15)


func animate(_delta: float, speed: float, sitting: bool) -> void:
	var clip := "loco/idle"
	var rate := 1.0
	if sitting:
		clip = "social/sit_idle"
	elif speed > RUN_ABOVE:
		clip = "loco/run"
		rate = minf(speed / RUN_MPS, MAX_SCALE)
	elif speed > 0.25:
		clip = "loco/walk"
		rate = minf(speed / WALK_MPS, MAX_SCALE)
	if _emote != "" and clip == "loco/idle":
		return
	_emote = ""
	_player.speed_scale = rate
	if _player.current_animation != clip:
		_player.play(clip, 0.15)
