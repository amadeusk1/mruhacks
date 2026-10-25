extends Node

## Plays the tracks in audio/music as a quiet ambient bed under voices.
## The title screen loops Pengloo Party (play_title()). In a game (start() on Net.session_started)
## a random town or minigame song plays depending on where you are. Each song runs to
## the end and crossfades into another, changing area crossfades too. Ducks while anyone audible
## talks, pauses during cinema films and while the dance floor's own music plays.
## The "music" setting drives the "Music" bus. The web build leaves the .ogg files out of the .pck
## (deploy/export_presets.cfg) and streams them from music/ next to index.html instead, so they never
## slow the loading screen. Spec: vault "Engine Specs/Voice Codec and Music.md".

const BASE_DB := -20.0      # ambient level under voices (voice plays at 0 dB before its own setting)
const DUCK_DB := -6.0       # extra while someone audible is talking
const ATTACK_DB_S := 40.0   # duck in fast (~0.15 s)...
const RELEASE_DB_S := 6.0   # ...and come back slowly (~1 s)
const FADE_S := 4.0         # crossfade between songs / areas
const DIR := "res://audio/music/"
const SETS := {
	"title": ["Pengloo Party"],
	"town": ["Penguin Chat", "Penguin Chat2", "titlescreen music", "titlescreen music 2"],
	"games": ["minigame", "minigame song 2", "Minigame", "Minigame 2"],
	"sled": ["Sled Race", "Sled Race 2", "sled", "sled 2"],
	"arcade": ["Arcade", "Arcade 2", "arcade", "arcade 2"],
	"basketball": ["Basketball", "basketball", "basketball 2"],
	"snow": ["snowball fight", "snowball fught 2"],
	"fishing": ["fishing", "fishing 2"],
	"sketch": ["sketch", "sketch 2"],
	"cinema": ["cinema", "cinema 2"],
	"casino": ["casino", "casino 2"],
	"cafe": ["cafe", "cafe 2"],
	"home": ["home", "home 2"],
}
const PLACES := {
	"sled_hill": "sled",
	"cinema": "cinema",
	"casino": "casino",
	"cafe": "cafe",
	"home": "home",
}
const GAME_PLACES := ["sled", "arcade", "arena", "court", "snowball", "casino"]
const EXTS := [".ogg", ".mp3", ".wav"]
const FOLDERS := ["res://audio/music/", "res://audio/"]

var area := ""
var _activity := ""         # fishing, sketch, or a cabinet, until that session ends
var _token := 0
var _on := false            # in a game session
var _a: AudioStreamPlayer   # current song
var _b: AudioStreamPlayer   # fading out
var _fade := 1.0            # 0 -> 1 over FADE_S: _a comes in, _b goes out
var _current := ""
var _cache := {}            # song -> AudioStream
var _wanted := ""           # song waiting for its download
var _duck := 0.0
var _hold_nodes: Array = [] # cinema screen players and the dance floor music


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		AudioServer.set_bus_volume_db(0, 0.0)  # before this bus existed the music setting drove Master
	UIRouter.set_setting("music", UIRouter.settings.get("music", 70.0))
	_a = _new_player()
	_b = _new_player()
	get_tree().node_added.connect(_on_node_added)
	Net.session_started.connect(start)


func start() -> void:
	_on = true


func play_title() -> void:
	_on = false
	_activity = ""


## Activity music. The token lets an older session leave without cutting off a newer one.
func play_activity(kind: String) -> int:
	if not SETS.has(kind):
		return 0
	_token += 1
	_activity = kind
	return _token


func resume(token: int) -> void:
	if token == _token:
		_activity = ""


func play_arcade() -> int:
	return play_activity("arcade")


func leave_arcade(token: int) -> void:
	resume(token)


## The music slider. Player volumes stay on top of this for the ambient bed and voice ducking.
func apply_volume() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var lin := float(UIRouter.settings.get("music", 70.0)) / 100.0
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))


func _process(delta: float) -> void:
	var want := _area()
	if want != area:
		area = want
		_next_song()
	elif _wanted == "" and _a.playing and _a.stream and _a.get_playback_position() > _a.stream.get_length() - FADE_S:
		_next_song()  # start the next one under the tail of this one
	_fade = minf(_fade + delta / FADE_S, 1.0)
	var target := DUCK_DB if Voice.anyone_talking() else 0.0
	_duck = move_toward(_duck, target, (ATTACK_DB_S if target < _duck else RELEASE_DB_S) * delta)
	_a.volume_db = BASE_DB + _duck + linear_to_db(maxf(_fade, 0.001))
	_b.volume_db = BASE_DB + _duck + linear_to_db(maxf(1.0 - _fade, 0.001))
	if _fade >= 1.0 and _b.playing:
		_b.stop()
	var hold := _held()
	_a.stream_paused = hold
	_b.stream_paused = hold


func _area() -> String:
	if not _on:
		return "title"
	if _activity != "":
		return _activity
	var loc := str(Net.get("_place_location"))
	var place := str(PLACES.get(loc, ""))
	if place != "":
		return place
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player != null:
		if Net.court_here(player.global_position):
			return "basketball"
		if Net.snow_here(player.global_position):
			return "snow"
	for g in GAME_PLACES:
		if g in loc:
			return "games"
	return "town"


## A random song from this area's set, never the one that just played.
func _next_song() -> void:
	var names := _songs_for(area)
	var pool: Array = names.filter(func(s: String) -> bool: return s != _current)
	if pool.is_empty():
		pool = names
	if pool.is_empty():
		return
	_play(pool[randi() % pool.size()])


func _songs_for(which: String) -> Array:
	var names: Array = []
	for song in SETS.get(which, []):
		if _find(str(song)) != "":
			names.append(song)
	if not names.is_empty() or which == "title" or which == "town":
		return names
	return _songs_for("games" if which in ["sled", "arcade", "basketball", "snow"] else "town")


func _play(song: String) -> void:
	if not _cache.has(song):
		if _wanted != song:  # one download per song, even if asked again while it loads
			_wanted = song
			_load(song)
		return
	_wanted = ""
	_current = song
	var old := _b  # swap: the current player fades out, the free one fades in
	_b = _a
	_a = old
	_a.stream = _cache[song]
	_a.play()
	_fade = 0.0


func _find(song: String) -> String:
	for folder in FOLDERS:
		for ext in EXTS:
			var path := folder + song + ext
			if ResourceLoader.exists(path):
				return path
	return ""


func _load(song: String) -> void:
	var path := _find(song)
	if path == "":
		path = DIR + song + ".ogg"
	if ResourceLoader.exists(path):
		_cache[song] = load(path)
		_play(song)
		return
	if not OS.has_feature("web"):
		return  # native export without the music folder: stay silent
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			push_warning("music: %s failed (%d/%d)" % [song, result, code])
			_wanted = ""
			return
		_cache[song] = AudioStreamOggVorbis.load_from_buffer(body)
		if _wanted == song:
			_play(song))
	# HTTPRequest needs an absolute URL ("music/..." fails with Invalid URL scheme)
	var origin := str(JavaScriptBridge.eval("location.origin"))
	if req.request(origin + "/music/" + song.uri_encode() + ".ogg") != OK:
		push_warning("music: couldn't request %s" % song)
		req.queue_free()
		_wanted = ""


func _held() -> bool:
	_hold_nodes = _hold_nodes.filter(func(n) -> bool: return is_instance_valid(n))
	for n in _hold_nodes:
		if n.playing:
			return true
	return false


func _on_node_added(n: Node) -> void:
	if n is CinemaScreenPlayer or (n is AudioStreamPlayer and n.name == "DanceMusic"):
		_hold_nodes.append(n)


func _new_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -60.0
	add_child(p)
	return p
