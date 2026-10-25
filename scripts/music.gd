extends Node

## Ambient music from audio/music, quiet under voices (BASE_DB on the Music bus).
##
## SETS maps a place to filenames in that folder. The first name is the default. Two or more
## names are picked at random when you arrive, then that one loops until you leave. ".ogg"
## tracks (title and town) play through and crossfade into another song from the same place.
## ".mp3" tracks loop in place: the importer sets loop, and prepare() sets it again so a web
## download loops too. The Suno masters sit with the ogg bed (about -14.5 LUFS, mean near -17 dB),
## so they share BASE_DB. Leaving a place crossfades back over FADE_S; the outgoing player is
## stopped at the end of the fade so two songs never keep playing together.
##
## Where you are:
##   title        menu, and again after play_title()
##   town         town, plaza, and your igloo (an igloo track is not in yet)
##   cafe         the café
##   cinema       the cinema building; a film still pauses this bed
##   casino       the casino
##   arcade       the arcade
##   sled         Sled Hill
##   basketball   on the town court
##   fishing      at the fishing rails (or while the cast is active)
##   sketch       inside the Sketch Club pavilion, or seated at its table
##   games        the snowball arena, and any other minigame place without its own set
##                (minigame.mp3 / minigame_2.mp3, replacing minigame.ogg)
##
## Add a place: drop the file in audio/music (mp3 loops, ogg joins the crossfade playlist),
## add a SETS row, and match the location id in PLACE_AREAS ahead of MINIGAME_PLACES.
## A town spot that is not its own location needs a check in _town_zone(), the way the court,
## the pavilion and the fishing rails do. Home stays on the town bed until an igloo track exists:
## do not add a "home" row before that.
## The web export omits audio/music and streams these filenames from music/ next to index.html.
## Spec: vault "Engine Specs/Voice Codec and Music.md".

const BASE_DB := -20.0      # ambient level under voices (voice plays at 0 dB before its own setting)
const DUCK_DB := -6.0       # extra while someone audible is talking
const ATTACK_DB_S := 40.0   # duck in fast (~0.15 s)...
const RELEASE_DB_S := 6.0   # ...and come back slowly (~1 s)
const FADE_S := 4.0         # crossfade between songs / places
const ZONE_EXIT_S := 0.6    # stay on a town spot briefly so the edge doesn't stutter the fade
const FISH_PAD := 4.0       # metres around the fishing rails that still count as the dock
const SKETCH_PAD := 2.0     # metres outside the pavilion mesh (the door apron)
const DIR := "res://audio/music/"
const SETS := {
	"title": ["Pengloo Party.ogg"],
	"town": ["Penguin Chat.ogg", "Penguin Chat2.ogg", "titlescreen music.ogg", "titlescreen music 2.ogg"],
	"games": ["minigame.mp3", "minigame_2.mp3"],
	"sled": ["sled_race.mp3", "sled_race_2.mp3"],
	"arcade": ["arcade.mp3", "arcade_2.mp3"],
	"basketball": ["basketball.mp3", "basketball_2.mp3"],
	"casino": ["casino.mp3", "casino_2.mp3"],
	"cinema": ["cinema.mp3", "cinema_2.mp3"],
	"cafe": ["cafe.mp3", "cafe_2.mp3"],
	"fishing": ["fishing.mp3", "fishing_2.mp3"],
	"sketch": ["sketch_club.mp3", "sketch_club_2.mp3"],
}
## Location-id substrings, first match wins. Home is absent on purpose (see the header).
const PLACE_AREAS := [
	["sled", "sled"],
	["arcade", "arcade"],
	["casino", "casino"],
	["cinema", "cinema"],
	["cafe", "cafe"],
	["court", "basketball"],
	["basketball", "basketball"],
	["fishing", "fishing"],
	["sketch", "sketch"],
]
## Places that still use the general minigame bed. Matched after PLACE_AREAS.
const MINIGAME_PLACES := ["arena", "snowball"]

var area := ""
var _activity := ""         # fishing, sketch, a cabinet, or the snowball screen, until that session ends
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
var _zone := ""             # town spot we're lingering in
var _zone_left := 0.0
var _pavilion: Node3D
var _pavilion_miss := 0.0
var _fish_bounds := Rect2()
var _fish_anchor: Node


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
	_zone = ""
	_zone_left = 0.0


## The token lets an older session leave without cutting off a newer one.
## Snowballs share the minigame bed.
func play_activity(kind: String) -> int:
	var which := "games" if kind == "snow" else kind
	if not SETS.has(which):
		return 0
	_token += 1
	_activity = which
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
	var want := _resolve_area(delta)
	if want != area:
		area = want
		_next_song()
	elif _wanted == "" and not _stream_loops(_a.stream) and _a.playing and _a.stream and _a.get_playback_position() > _a.stream.get_length() - FADE_S:
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
	# A looping bed that hit the end anyway (loop flag missed) restarts instead of going silent.
	if _wanted == "" and _stream_loops(_a.stream) and not hold and not _a.playing and _fade >= 1.0:
		_a.play()


## in_game false is the menu. zone is a town spot ("basketball", "sketch", "fishing", "games")
## or "" — it only applies while the location id is town, so a door trip always wins.
static func area_for(in_game: bool, location: String, zone: String) -> String:
	if not in_game:
		return "title"
	var loc := location.to_lower()
	for row in PLACE_AREAS:
		if str(row[0]) in loc:
			return str(row[1])
	if zone != "" and loc == "town":
		return zone
	for g in MINIGAME_PLACES:
		if g in loc:
			return "games"
	return "town"


## A song from this place, never the one that just played. roll 0 is the first remaining name.
static func pick_song(songs: Array, current: String, roll: int) -> String:
	var pool: Array = []
	for song in songs:
		if str(song) != current:
			pool.append(str(song))
	if pool.is_empty():
		for song in songs:
			pool.append(str(song))
	if pool.is_empty():
		return ""
	return str(pool[posmod(roll, pool.size())])


static func prepare(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


func _resolve_area(delta: float) -> String:
	if not _on:
		_zone = ""
		_zone_left = 0.0
		return "title"
	if _activity != "":
		return _activity
	var loc := str(Net.get("_place_location"))
	# Door trips hide the penguin before arrive() publishes the next place. Keep the bed
	# through that gap so town music doesn't flash in between two rooms.
	if bool(Net.get("_place_hidden")) and area != "" and area != "title":
		return area
	var zone := ""
	if loc == "town":
		zone = _town_zone(delta)
	else:
		_zone = ""
		_zone_left = 0.0
	return area_for(true, loc, zone)


func _town_zone(delta: float) -> String:
	_pavilion_miss = maxf(0.0, _pavilion_miss - delta)
	var here := ""
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if player != null:
		var at := player.global_position
		if Net.court_here(at):
			here = "basketball"
		elif _at_sketch(player):
			here = "sketch"
		elif _at_fishing(player, at):
			here = "fishing"
		elif Net.snow_here(at):
			here = "games"
	if here != "":
		_zone = here
		_zone_left = 0.0
		return here
	if _zone != "":
		_zone_left += delta
		if _zone_left < ZONE_EXIT_S:
			return _zone
		_zone = ""
	return ""


func _at_fishing(player: Node3D, at: Vector3) -> bool:
	if player.has_method("is_fishing") and bool(player.call("is_fishing")):
		return true
	if not is_instance_valid(_fish_anchor):
		_rebuild_fish()
	return _fish_bounds.size != Vector2.ZERO and _fish_bounds.has_point(Vector2(at.x, at.z))


func _rebuild_fish() -> void:
	_fish_anchor = null
	_fish_bounds = Rect2()
	var any := false
	var rect := Rect2()
	for n in get_tree().get_nodes_in_group("fish_spot"):
		if not (n is Node3D):
			continue
		var p := (n as Node3D).global_position
		var spot := Rect2(Vector2(p.x, p.z), Vector2.ZERO)
		rect = spot if not any else rect.merge(spot)
		any = true
		_fish_anchor = n
	if any:
		_fish_bounds = rect.grow(FISH_PAD)


func _at_sketch(player: Node3D) -> bool:
	if player.has_method("is_sitting") and bool(player.call("is_sitting")):
		var bench := player.call("current_bench") as Node
		if bench != null and str(bench.get("kit")) == "sketch":
			return true
	var pavilion := _find_pavilion()
	if pavilion == null:
		return false
	var local := pavilion.to_local(player.global_position)
	var half := _sketch_half()
	return absf(local.x) <= half.x + SKETCH_PAD and absf(local.z) <= half.y + SKETCH_PAD


func _find_pavilion() -> Node3D:
	if is_instance_valid(_pavilion):
		return _pavilion
	for n in get_tree().get_nodes_in_group("sketch_pavilion"):
		if n is Node3D:
			_pavilion = n
			_pavilion_miss = 0.0
			return _pavilion
	if _pavilion_miss > 0.0:
		return null  # name search walks the whole tree; the group above is checked every time
	var named := get_tree().root.find_child("SketchClub", true, false) as Node3D
	if named != null:
		_pavilion = named
		return _pavilion
	_pavilion_miss = 2.0
	return null


func _sketch_half() -> Vector2:
	var size := Vector3(5.613, 4.64, 6.065)
	if AssetRegistry.has("activities/sketch_pavilion"):
		size = AssetRegistry.size("activities/sketch_pavilion")
	return Vector2(size.x * 0.5, size.z * 0.5)


func _next_song() -> void:
	var songs: Array = SETS.get(area, SETS["town"])
	_play(pick_song(songs, _current, randi()))


func _play(song: String) -> void:
	if song == "":
		return
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


func _load(song: String) -> void:
	var path := DIR + song
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream == null:
			_wanted = ""
			return
		_cache[song] = prepare(stream)
		_play(song)
		return
	if not OS.has_feature("web"):
		push_warning("music: missing %s" % path)
		_wanted = ""
		return  # native export without the music folder: stay silent
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
			push_warning("music: %s failed (%d/%d)" % [song, result, code])
			if _wanted == song:
				_wanted = ""
			return
		var stream := _decode(song, body)
		if stream == null:
			if _wanted == song:
				_wanted = ""
			return
		_cache[song] = prepare(stream)
		if _wanted == song:
			_play(song))
	# HTTPRequest needs an absolute URL ("music/..." fails with Invalid URL scheme).
	var origin := str(JavaScriptBridge.eval("location.origin"))
	if req.request(origin + "/music/" + song.uri_encode()) != OK:
		push_warning("music: couldn't request %s" % song)
		req.queue_free()
		if _wanted == song:
			_wanted = ""


func _decode(song: String, body: PackedByteArray) -> AudioStream:
	if song.get_extension().to_lower() == "mp3":
		return AudioStreamMP3.load_from_buffer(body)
	return AudioStreamOggVorbis.load_from_buffer(body)


func _stream_loops(stream: AudioStream) -> bool:
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


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
