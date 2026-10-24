class_name PenguinAnims
extends RefCounted

## Adds every art-pack animation kit to a penguin's AnimationPlayer as named libraries:
## emotes/emote_wave, social/sit_idle, fishing/fish_cast, sledding/sled_ride, ...
## The base clips (idle, walk, run, hop...) stay in the default library from anim_locomotion.
## Clip lengths, loop flags and events are in Models/anim_<kit>/manifest.json.

const KITS := ["emotes", "social", "casino", "fishing", "sledding", "snowballs", "basketball",
	"arcade", "drawing", "cinema", "home", "everyday"]
const WALK_MPS := 0.3334  # anim_locomotion walk/run speed_mps
const RUN_MPS := 1.1

## Seat/station styles: [enter, loop, leave] (library/clip). Empty entries are skipped.
const SEATS := {
	"casino": ["casino/hop_onto_seat", "casino/casino_seated_idle", "casino/leave_seat"],
	"cinema": ["cinema/cinema_sit", "cinema/cinema_watch", "cinema/cinema_stand"],
	"arcade": ["arcade/arcade_enter", "arcade/arcade_play", "arcade/arcade_exit"],
	"sketch": ["drawing/sketch_sit", "drawing/sketch_think", "drawing/sketch_stand"],
	"armchair": ["home/armchair_sit", "home/armchair_idle", "home/armchair_stand"],
	"stool": ["everyday/stool_back_up_sit", "social/sit_idle", "social/sit_exit"],
}

## Teammate fishing phases (fishing_hud.gd) -> anim_fishing clips.
const FISHING := {"cast": "fishing/fish_cast", "wait": "fishing/fish_wait", "bite": "fishing/fish_hook",
	"reel": "fishing/fish_reel", "catch": "fishing/fish_catch", "miss": "fishing/fish_escape"}

static var _libs := {}


static func attach(player: AnimationPlayer) -> void:
	if player == null:
		return
	for kit in KITS:
		if player.has_animation_library(kit):
			continue
		var lib := _library(kit)
		if lib:
			player.add_animation_library(kit, lib)


## "wave" / "emote_wave" / "emotes/emote_wave" -> the clip name in the player, or "".
static func resolve(player: AnimationPlayer, name: String, default_kit: String) -> String:
	for candidate in [name, "%s/%s" % [default_kit, name], "%s/emote_%s" % [default_kit, name]]:
		if player.has_animation(candidate):
			return candidate
	for kit in KITS:
		if player.has_animation("%s/%s" % [kit, name]):
			return "%s/%s" % [kit, name]
	return ""


static func fishing_clip(phase: String) -> String:
	return FISHING.get(phase.get_slice(":", 0), "")


## Locomotion clip and playback rate for a ground speed in m/s.
## shortcut: the walk motor tops out at 4.5 m/s, faster than the run clip; rate is capped so
## feet slide a little at full speed instead of the bird flailing.
static func locomotion(speed: float) -> Array:
	if speed > 1.4:
		return ["run", minf(speed / RUN_MPS, 2.6)]
	if speed > 0.25:
		return ["walk", minf(speed / WALK_MPS, 2.6)]
	return ["idle", 1.0]


static func _library(kit: String) -> AnimationLibrary:
	if _libs.has(kit):
		return _libs[kit]
	var path := "res://Models/anim_%s/avatar_base.glb" % kit
	var lib: AnimationLibrary = null
	if ResourceLoader.exists(path):
		var src: Node = (load(path) as PackedScene).instantiate()
		var aps := src.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			var ap := aps[0] as AnimationPlayer
			lib = ap.get_animation_library(ap.get_animation_library_list()[0])
		src.free()
	_libs[kit] = lib
	return lib
