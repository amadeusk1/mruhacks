extends Node

## Title screen plays Pengloo Party.mp3. In a game, the other tracks in
## audio/music each play through, then another one is chosen at random.

const TITLE := "res://audio/music/Pengloo Party.mp3"
const TITLE_FILE := "Pengloo Party.mp3"

var _player: AudioStreamPlayer
var _songs: PackedStringArray = PackedStringArray()
var _current := ""
var _on := false
var _title := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.finished.connect(_on_finished)
	add_child(_player)
	_ensure_bus()
	Net.session_started.connect(start)
	play_title()


func play_title() -> void:
	_on = false
	_title = true
	_play(TITLE, true)


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
	_player.stop()


func _on_finished() -> void:
	if _title:
		_play(TITLE, true)
		return
	if not _on:
		return
	_play(_pick(_current), false)


func _play(path: String, looped: bool) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = looped
	_current = path
	_player.stream = stream
	_player.play()


func _pick(except: String) -> String:
	var pool: Array[String] = []
	for path in _songs:
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
	var names: Array[String] = []
	for file in dir.get_files():
		if file == TITLE_FILE:
			continue
		if file.ends_with(".mp3") or file.ends_with(".ogg") or file.ends_with(".wav"):
			names.append(file)
	names.sort()
	for file in names:
		_songs.append("res://audio/music/%s" % file)


func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
	var lin := float(UIRouter.settings.get("music", 70.0)) / 100.0
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
