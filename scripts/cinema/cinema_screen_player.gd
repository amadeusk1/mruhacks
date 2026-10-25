class_name CinemaScreenPlayer
extends Node
## Plays the current film with no video decoder in Godot (proven in the cinema sandbox): the gateway sends
## 10 s chunks of JPEG frames (15 fps) and MP3 audio; we show the frame for the shared clock and
## play the matching audio. The clock comes from the server's state (authoritative, polled every
## second here); we only extrapolate between polls and re-seek audio when it drifts.
## Output: `texture` (for a 3D screen material or a 2D overlay) and `texture_changed`.

signal texture_changed(tex: Texture2D)
signal playing_changed(on: bool)
signal state_changed(state: Dictionary)   ## every gateway state poll (GatewaySource builds its snapshot from it)

const SEG := 10.0
const FPS := 15.0
const AHEAD := 1            ## segments fetched ahead of the playhead (2 transcodes each: video + audio)

var client: CinemaServiceClient
var texture: ImageTexture
var playing := false
var frames_shown := 0
var _base_pos := 0.0        ## server position at _base_ms
var _base_ms := 0
var _segs := {}             ## index -> {"frames": Array[PackedByteArray], "audio": AudioStreamMP3} (partial while loading)
var _loading := {}          ## "v:3" / "a:3" -> true while in flight
var _retry_at := {}         ## same keys -> ticks before which a failed fetch is not retried
var _has_film := false
var _shown := Vector2i(-1, -1)
var _audio: AudioStreamPlayer
var _audio_seg := -1
var _film := ""
var _generation := -1
var _revision := -1
var _views := {}            ## nodes currently showing this player (screen, overlay, watch UI)


## A view (3D screen, overlay, watch UI) starts showing the film: chunks download only while at least
## one view is open, and stop when the last one closes or is freed.
func watch(view: Node) -> void:
	_views[view] = true


func unwatch(view: Node) -> void:
	_views.erase(view)


func has_film() -> bool:
	return _has_film


func has_views() -> bool:
	for v in _views.keys():
		if not is_instance_valid(v):
			_views.erase(v)
	return not _views.is_empty()


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Movie" if AudioServer.get_bus_index("Movie") >= 0 else "Master"
	_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # runtime MP3 chunks + seeks need Stream; web Sample mode stays silent
	add_child(_audio)
	var poll := Timer.new()
	poll.wait_time = 1.0
	poll.autostart = true
	poll.timeout.connect(func() -> void:
		if client and client.signed_in:
			client.state(_on_state))
	add_child(poll)
	poll.timeout.emit.call_deferred()  # first state now, not a second from now


## Feed the gateway state (from /api/state polls).
func apply_state(st: Dictionary) -> void:
	var rev := int(st.get("revision", 0))
	var film := str(st.get("media", {}).get("id", ""))
	var gen := int(st.get("generation", 0))
	# A slow poll of the previous movie or episode can arrive after the new one. Generation only
	# moves forward for a running server, so an older generation is a leftover and is ignored.
	if _generation >= 0 and gen < _generation:
		return
	if gen == _generation and rev < _revision:
		return
	_revision = rev
	if film != _film or gen != _generation:
		# A new screening must not keep the previous film's frames, picture, or audio.
		_film = film
		_generation = gen
		_segs.clear()
		_loading.clear()
		_retry_at.clear()
		_blank()
	var on := bool(st.get("playing", false))
	var pos := float(st.get("position", 0.0))
	if on:
		pos += maxf(0.0, float(st.get("serverNow", 0)) - float(st.get("updatedAt", 0))) / 1000.0
	_has_film = str(st.get("media", {}).get("id", "")) != ""
	if not _has_film:
		on = false
	# Only re-anchor on real changes, so poll jitter doesn't make the picture stutter.
	if on != playing or absf(pos - position()) > 0.35:
		_base_pos = pos
		_base_ms = Time.get_ticks_msec()
	if on != playing:
		playing = on
		playing_changed.emit(on)
		var music := get_node_or_null("/root/Music")
		if music and music.has_method("set_ducked"):
			music.set_ducked(on)


func position() -> float:
	return _base_pos + ((Time.get_ticks_msec() - _base_ms) / 1000.0 if playing else 0.0)


func stop() -> void:
	playing = false
	_has_film = false
	_film = ""
	_generation = -1
	_revision = -1
	_segs.clear()
	_loading.clear()
	_retry_at.clear()
	_blank()
	var music := get_node_or_null("/root/Music")
	if music and music.has_method("set_ducked"):
		music.set_ducked(false)


func _blank() -> void:
	_shown = Vector2i(-1, -1)
	_audio_seg = -1
	if _audio:
		_audio.stop()
		_audio.stream = null
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(img)
	texture_changed.emit(texture)


func _process(_d: float) -> void:
	if not _has_film or client == null or not client.signed_in or not has_views():
		if _audio.playing and not has_views():
			_audio.stop()  # nobody watching: silence too
		return
	var pos := position()
	var k := int(pos / SEG)
	for i in range(k, k + AHEAD + 1):
		_fetch(i)
	for old in _segs.keys():
		if old < k - 1:
			_segs.erase(old)
	_show_frame(k, pos)
	_sync_audio(k, pos)


func _fetch(i: int) -> void:
	for kind in ["video", "audio"]:
		var key := "%s:%d" % [kind[0], i]
		if _loading.has(key) or Time.get_ticks_msec() < int(_retry_at.get(key, 0)) \
				or (_segs.has(i) and _segs[i].has("frames" if kind == "video" else "audio")):
			continue
		_loading[key] = true
		var gen := _generation
		# bound methods, not lambdas: the client drops the callback if this player is freed meanwhile
		client.segment(kind, i * SEG, SEG, _on_segment.bind(i, kind, key, gen))


func _on_state(st: Variant) -> void:
	if st is Dictionary:
		apply_state(st)
		state_changed.emit(st)


func _on_segment(b: PackedByteArray, i: int, kind: String, key: String, gen: int) -> void:
	if gen != _generation:
		return
	_loading.erase(key)
	if b.is_empty():
		_retry_at[key] = Time.get_ticks_msec() + 2000  # busy/failed: back off, don't hammer
		return
	var seg: Dictionary = _segs.get(i, {})
	if kind == "video":
		seg["frames"] = split_jpegs(b)
	else:
		var mp3 := AudioStreamMP3.new()
		mp3.data = b
		seg["audio"] = mp3
	_segs[i] = seg


func _show_frame(k: int, pos: float) -> void:
	var frames: Array = _segs.get(k, {}).get("frames", [])
	if frames.is_empty():
		return
	var f := clampi(int((pos - k * SEG) * FPS), 0, frames.size() - 1)
	if Vector2i(k, f) == _shown:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(frames[f]) != OK:
		return
	if texture == null or texture.get_size() != Vector2(img.get_size()):
		texture = ImageTexture.create_from_image(img)
		texture_changed.emit(texture)
	else:
		texture.update(img)
	_shown = Vector2i(k, f)
	frames_shown += 1


func _sync_audio(k: int, pos: float) -> void:
	var a: AudioStreamMP3 = _segs.get(k, {}).get("audio")
	if not playing or a == null:
		if _audio.playing and not playing:
			_audio.stop()
		return
	var want := pos - k * SEG
	if _audio_seg != k or not _audio.playing:
		_audio.stream = a
		_audio.play(want)
		_audio_seg = k
	elif absf(_audio.get_playback_position() - want) > 0.25:
		_audio.seek(want)


## Splits the gateway's [u32 LE length][jpeg]... frame stream.
static func split_jpegs(b: PackedByteArray) -> Array:
	var out: Array = []
	var i := 0
	while i + 4 <= b.size():
		var n := b.decode_u32(i)
		if n == 0 or i + 4 + n > b.size():
			break
		out.append(b.slice(i + 4, i + 4 + n))
		i += 4 + n
	return out
