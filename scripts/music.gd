extends Node

## The title screen plays one of the normal game tracks, looping until you join.
## In a game, those tracks each play through, then another one is chosen at random.
## Each activity has its own pair and is left out of the town shuffle.

const TITLE_FILE := "Pengloo Party.mp3"
const POOLS := {
	"snow": ["res://audio/music/snowball fight.mp3", "res://audio/music/snowball fught 2.mp3"],
	"arcade": ["res://audio/music/arcade.mp3", "res://audio/music/arcade 2.mp3"],
	"fishing": ["res://audio/music/fishing.wav", "res://audio/music/fishing 2.wav"],
	"sled": ["res://audio/music/sled.wav", "res://audio/music/sled 2.wav"],
	"basketball": ["res://audio/music/basketball.wav", "res://audio/music/basketball 2.wav"],
	"sketch": ["res://audio/music/sketch.wav", "res://audio/music/sketch 2.wav"],
	"cinema": ["res://audio/music/cinema.wav", "res://audio/music/cinema 2.wav"],
	"casino": ["res://audio/music/casino.wav", "res://audio/music/casino 2.wav"],
	"cafe": ["res://audio/music/cafe.wav", "res://audio/music/cafe 2.wav"],
	"home": ["res://audio/music/home.wav", "res://audio/music/home 2.wav"],
}
const PLACES := {
	"sled_hill": "sled",
	"cinema": "cinema",
	"casino": "casino",
	"cafe": "cafe",
	"home": "home",
}

var _player: AudioStreamPlayer
var _songs: PackedStringArray = PackedStringArray()
var _current := ""
var _on := false
var _title := false
var _override := ""
var _token := 0
var _ducked := false
var _saved := ""
var _saved_pos := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.finished.connect(_on_finished)
	add_child(_player)
	apply_volume()
	Net.session_started.connect(start)
	play_title()


func play_title() -> void:
	_on = false
	_title = true
	_override = ""
	_collect()
	if _songs.is_empty():
		return
	_play(_pick(""), true)


func start() -> void:
	_title = false
	if _on and _player.playing:
		return
	_on = true
	_collect()
	if _songs.is_empty():
		return
	_play(_pick(""), false)


func stop() -> void:
	_on = false
	_title = false
	_override = ""
	_player.stop()


## Activity music. Returns a token so leaving an older activity does not cut off a new one.
func play_activity(kind: String) -> int:
	return _begin(kind, POOLS.get(kind, []))


func play_snow() -> int:
	return play_activity("snow")


func resume(token: int) -> void:
	_end(_override, token)


func resume_town(token: int) -> void:
	resume(token)


func play_arcade() -> int:
	return play_activity("arcade")


func leave_arcade(token: int) -> void:
	resume(token)


## Sled Hill, the cinema, the casino, the café, and your house each bring their own pair.
## Arcade music still starts at a machine. A fishing, snowball, court, or sketch session
## keeps its song until that session ends.
func note_place(location: String) -> void:
	if location != "arcade" and _override == "arcade":
		_end("arcade", _token)
	if _override != "" and not PLACES.values().has(_override):
		return
	var kind := str(PLACES.get(location, ""))
	if kind == _override:
		return
	if _override != "":
		_end(_override, _token)
	if kind != "":
		_begin(kind, POOLS[kind])


## Films use the Movie bus. Drop the lobby song under them, then bring it back.
func set_ducked(on: bool) -> void:
	_ducked = on
	apply_volume()


func apply_volume() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
	var lin := float(UIRouter.settings.get("music", 70.0)) / 100.0
	if _ducked:
		lin *= 0.22
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))


func _begin(kind: String, tracks: Array) -> int:
	var ready: Array[String] = []
	for path in tracks:
		if ResourceLoader.exists(str(path)):
			ready.append(str(path))
	if ready.is_empty():
		return 0
	if _override == "":
		_saved = _current
		_saved_pos = _player.get_playback_position()
	_title = false
	_override = kind
	_token += 1
	_play(_pick_from(ready, ""), false)
	return _token


func _end(kind: String, token: int) -> void:
	if token <= 0 or token != _token or _override != kind:
		return
	_override = ""
	if not _on:
		return
	if _saved != "":
		_play(_saved, false)
		_player.seek(_saved_pos)
		return
	_collect()
	if not _songs.is_empty():
		_play(_pick(""), false)


func _on_finished() -> void:
	if _title:
		_play(_current if _current != "" else _pick(""), true)
		return
	if POOLS.has(_override):
		_play(_pick_from(POOLS[_override], _current), false)
		return
	if not _on:
		return
	_play(_pick(_current), false)


func _play(path: String, looped: bool) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
	elif "loop" in stream:
		stream.loop = looped
	_current = path
	_player.stream = stream
	_player.play()


func _pick(except: String) -> String:
	return _pick_from(_songs, except)


func _pick_from(songs, except: String) -> String:
	var pool: Array[String] = []
	for path in songs:
		if path != except:
			pool.append(path)
	if pool.is_empty():
		return except
	return pool[randi() % pool.size()]


func _collect() -> void:
	if not _songs.is_empty():
		return
	var dir := DirAccess.open("res://audio/music")
	if dir == null:
		return
	var skip := {TITLE_FILE: true}
	for kind in POOLS:
		for path in POOLS[kind]:
			skip[str(path).get_file()] = true
	var names: Array[String] = []
	for file in dir.get_files():
		if skip.has(file):
			continue
		if file.ends_with(".mp3") or file.ends_with(".ogg") or file.ends_with(".wav"):
			names.append(file)
	names.sort()
	for file in names:
		_songs.append("res://audio/music/%s" % file)
