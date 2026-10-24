extends Node
## Voice autoload: proximity voice chat, server-relayed over the existing Net WebSocket/ENet peer.
## Why relayed (not WebRTC): one code path for native + web, rides the same wss://…/multiplayer
## connection through Cloudflare, no STUN/TURN, and the server can enforce rooms and distance.
##
## Mic: AudioStreamMicrophone -> "VoiceMic" bus (muted) with AudioEffectCapture. Frames are mixed
## to mono, decimated to 16 kHz, mu-law coded (8 bit) and sent in 60 ms packets (~16 kB/s talking).
## Silence under a threshold is not sent. Playback: one AudioStreamGenerator per speaker on the
## "Voice" bus, gain from distance (full <= 3 m, silent >= 18 m). Settings live in UIRouter:
## "mic" (mic on/off), "push_to_talk" (hold the push_to_talk action), "voice" (volume).
## Per-player mutes and deafen persist in user://voice.cfg.

signal speaking_changed(peer_id: int, on: bool)
signal mic_problem(message: String)

const RATE := 16000
const PACKET := 960                 # samples per packet (60 ms)
const NEAR := 3.0
const FAR := 18.0
const SILENCE_RMS := 0.012
const CFG := "user://voice.cfg"

var deafened := false
var muted_peers: Dictionary = {}    # peer name -> true (names survive reconnects; ids don't)
var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _mic_on := false
var _mic_started_at := 0.0
var _got_mic_frames := false
var _pending := PackedFloat32Array()
var _acc := 0.0
var _acc_n := 0
var _step := 3.0
var _phase := 0.0
var _hang := 0.0                    # keep sending briefly after speech ends (no word clipping)
var _speakers: Dictionary = {}      # peer_id -> {player, playback, last}
var _local_speaking := false
var _decode := PackedFloat32Array()
var _tone := false                  # --voice-tone: 440 Hz test signal instead of the mic (headless tests)
var _tone_t := 0.0
var rx_packets := 0                 # accepted incoming packets (tests)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 256:
		_decode.append(_mulaw_decode(i))
	_tone = OS.get_cmdline_user_args().has("--voice-tone")
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('voicetest')")):
		# test hook (headless Chrome with a fake mic): open mic and log receive counts
		UIRouter.settings["mic"] = true
		UIRouter.settings["push_to_talk"] = false
		var t := Timer.new()
		t.wait_time = 2.0
		t.autostart = true
		t.timeout.connect(func() -> void: print("VOICE_RX packets=%d speaking=%s" % [rx_packets, _local_speaking]))
		add_child(t)
	_load()
	_setup_buses()
	ControlsScreen.ensure_actions()


# ---- public API -----------------------------------------------------------------
func is_speaking(peer_id: int) -> bool:
	if peer_id == Net.local_id():
		return _local_speaking
	return _speakers.has(peer_id) and Time.get_ticks_msec() / 1000.0 - float(_speakers[peer_id]["last"]) < 0.3


func set_muted(player_name: String, on: bool) -> void:
	if on:
		muted_peers[player_name] = true
	else:
		muted_peers.erase(player_name)
	_save()


func is_muted(player_name: String) -> bool:
	return muted_peers.has(player_name)


func set_deafened(on: bool) -> void:
	deafened = on
	_save()


## Net calls this with a relayed packet (also on a listen host for its own player).
func receive(from_id: int, data: PackedByteArray) -> void:
	if deafened or _quiet() or data.is_empty() or _muted_id(from_id):
		return
	var s: Dictionary = _speakers.get(from_id, {})
	if s.is_empty():
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.4
		var p := AudioStreamPlayer.new()
		p.stream = gen
		p.bus = "Voice"
		add_child(p)
		p.play()
		s = {"player": p, "playback": p.get_stream_playback(), "last": 0.0}
		_speakers[from_id] = s
	var was := is_speaking(from_id)
	s["last"] = Time.get_ticks_msec() / 1000.0
	var pb: AudioStreamGeneratorPlayback = s["playback"]
	var frames := PackedVector2Array()
	frames.resize(data.size())
	for i in data.size():
		var v := _decode[data[i]]
		frames[i] = Vector2(v, v)
	if pb.get_frames_available() < frames.size():  # running behind: drop this packet, not the stream
		rx_packets += 1
		return
	pb.push_buffer(frames)
	rx_packets += 1
	if not was:
		speaking_changed.emit(from_id, true)


# ---- capture + send ---------------------------------------------------------------
func _process(delta: float) -> void:
	var want := _want_mic()
	if want != _mic_on:
		_set_mic(want)
	if _mic_on:
		_pump_mic(delta)
	_update_speakers()


func _want_mic() -> bool:
	return Net.is_online() and bool(UIRouter.settings.get("mic", false)) and not _quiet()


func _transmitting() -> bool:
	if not bool(UIRouter.settings.get("push_to_talk", false)):
		return true
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:  # typing "v" in chat must not open the mic
		return false
	return InputMap.has_action("push_to_talk") and Input.is_action_pressed("push_to_talk")


func _set_mic(on: bool) -> void:
	_mic_on = on
	if on:
		# Web: this is the first getUserMedia request, so permission is only asked when enabled.
		if not _tone:
			_mic_player.play()
		_mic_started_at = Time.get_ticks_msec() / 1000.0
		_got_mic_frames = false
		_step = AudioServer.get_mix_rate() / RATE
	else:
		_mic_player.stop()
		_capture.clear_buffer()
		_pending.clear()
		_set_local_speaking(false)


func _pump_mic(delta: float) -> void:
	if _tone:
		var want_n := int(delta * RATE)
		for i in want_n:
			_tone_t += 1.0 / RATE
			_pending.append(0.3 * sin(TAU * 440.0 * _tone_t))
		_flush_pending()
		return
	var n := _capture.get_frames_available()
	if n == 0:
		if not _got_mic_frames and Time.get_ticks_msec() / 1000.0 - _mic_started_at > 4.0:
			_got_mic_frames = true  # report once
			mic_problem.emit("No sound from your microphone. Check the browser or system permission.")
		return
	_got_mic_frames = true
	var buf := _capture.get_buffer(n)
	var send := _transmitting()
	for f in buf:
		_acc += (f.x + f.y) * 0.5
		_acc_n += 1
		_phase += 1.0
		if _phase >= _step:  # box-filter decimation to 16 kHz
			_phase -= _step
			if send:
				_pending.append(_acc / _acc_n)
			_acc = 0.0
			_acc_n = 0
	if not send:
		_pending.clear()
		_set_local_speaking(false)
		return
	_flush_pending()


func _flush_pending() -> void:
	while _pending.size() >= PACKET:
		var chunk := _pending.slice(0, PACKET)
		_pending = _pending.slice(PACKET)
		var rms := 0.0
		for v in chunk:
			rms += v * v
		rms = sqrt(rms / PACKET)
		_hang = 0.5 if rms > SILENCE_RMS else maxf(_hang - 0.06, 0.0)
		if _hang <= 0.0:
			_set_local_speaking(false)
			continue
		var out := PackedByteArray()
		out.resize(PACKET)
		for i in PACKET:
			out[i] = _mulaw_encode(chunk[i])
		Net.send_voice(out)
		_set_local_speaking(true)


func _set_local_speaking(on: bool) -> void:
	if on != _local_speaking:
		_local_speaking = on
		speaking_changed.emit(Net.local_id(), on)


# ---- playback gain + indicators ---------------------------------------------------------
func _update_speakers() -> void:
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	var by_peer := {}
	for p in get_tree().get_nodes_in_group("remote_penguins"):
		by_peer[int(p.get_meta("remote_peer", 0))] = p
	for id in _speakers.keys():
		var s: Dictionary = _speakers[id]
		var who := by_peer.get(id) as Node3D
		var g := 1.0
		if me and who:
			g = clampf(1.0 - (me.global_position.distance_to(who.global_position) - NEAR) / (FAR - NEAR), 0.0, 1.0)
		(s["player"] as AudioStreamPlayer).volume_db = linear_to_db(maxf(g, 0.0001))
		if who:
			_indicator(who, is_speaking(int(id)))
	for id in by_peer:
		if not _speakers.has(id):
			_indicator(by_peer[id], false)
	if me:
		_indicator(me, _local_speaking)


func _indicator(penguin: Node3D, on: bool) -> void:
	var icon := penguin.get_node_or_null("SpeakIcon") as Label3D
	if icon == null:
		if not on:
			return
		icon = Label3D.new()
		icon.name = "SpeakIcon"
		icon.text = "((  ))"  # sound waves either side of the name tag's dot
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.font_size = 40
		icon.outline_size = 8
		icon.pixel_size = 0.005
		icon.position = Vector3(0.0, 1.62, 0.0)
		icon.modulate = Color("#3FB3B5")
		icon.outline_modulate = Color(0.08, 0.14, 0.22)
		penguin.add_child(icon)
	icon.visible = on


# ---- helpers ------------------------------------------------------------------------
func _quiet() -> bool:
	return SketchClub.in_game()  # §15.7: private drawing rounds are quiet both ways


func _muted_id(peer_id: int) -> bool:
	for e in Net.roster():
		if int(e.get("id", 0)) == peer_id:
			return muted_peers.has(str(e.get("name", "")))
	return false


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Voice")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var idx := AudioServer.get_bus_index("VoiceMic")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "VoiceMic")
		AudioServer.set_bus_mute(idx, true)  # captured, never played back to yourself
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_capture.buffer_length = 0.5
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "VoiceMic"
	add_child(_mic_player)
	UIRouter.set_setting("voice", UIRouter.settings.get("voice", 60.0))  # bus now exists: apply volume


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG) == OK:
		deafened = bool(cf.get_value("voice", "deafened", false))
		for n in cf.get_value("voice", "muted", []):
			muted_peers[str(n)] = true


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("voice", "deafened", deafened)
	cf.set_value("voice", "muted", muted_peers.keys())
	cf.save(CFG)


static func _mulaw_encode(x: float) -> int:
	var s := 0x80 if x < 0.0 else 0
	var m := minf(absf(x), 1.0)
	var y := log(1.0 + 255.0 * m) / log(256.0)
	return s | int(round(y * 127.0))


static func _mulaw_decode(b: int) -> float:
	var y := float(b & 0x7F) / 127.0
	var m := (pow(256.0, y) - 1.0) / 255.0
	return -m if b & 0x80 else m
