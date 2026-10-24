extends Node

## Shuffled playlist of every track in audio/music, including the title themes.
## Stays silent until a session starts, then plays the next song when one ends.

const TRACKS: Array[AudioStream] = [
	preload("res://audio/music/Penguin Chat.mp3"),
	preload("res://audio/music/Penguin Chat2.mp3"),
	preload("res://audio/music/minigame.mp3"),
	preload("res://audio/music/minigame song 2.mp3"),
	preload("res://audio/music/titlescreen music.mp3"),
	preload("res://audio/music/titlescreen music 2.mp3"),
]

var _player: AudioStreamPlayer
var _queue: Array[AudioStream] = []
var _last: AudioStream
var _active := false


func _init() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -6.0
	_player.finished.connect(_play_next)
	add_child(_player)


func start() -> void:
	if _active:
		return
	_active = true
	_queue.clear()
	_play_next()


func stop() -> void:
	_active = false
	_queue.clear()
	_last = null
	_player.stop()


func _play_next() -> void:
	if not _active:
		return
	if _queue.is_empty():
		_refill()
	if _queue.is_empty():
		return
	var stream: AudioStream = _queue.pop_front()
	_last = stream
	_player.stream = stream
	_player.play()


func _refill() -> void:
	_queue = TRACKS.duplicate()
	_queue.shuffle()
	if _queue.size() > 1 and _queue[0] == _last:
		var swap := randi_range(1, _queue.size() - 1)
		var first: AudioStream = _queue[0]
		_queue[0] = _queue[swap]
		_queue[swap] = first
