extends Node
## Voice autoload: proximity voice chat, server-relayed over the existing Net WebSocket/ENet peer.
## Why relayed (not WebRTC): one code path for native + web, rides the same wss://…/multiplayer
## connection through Cloudflare, no STUN/TURN, and the server can enforce rooms and distance.
##
## Mic: AudioStreamMicrophone -> "VoiceMic" bus (muted) with AudioEffectCapture. Frames are mixed
## to mono, resampled to 48 kHz and Opus-coded at 24 kbps in 20 ms frames, three frames per 60 ms
## packet (~3.5 kB/s talking; the old mu-law stream was 16 kB/s). Opus comes from WebCodecs on the
## web and the TwoVoIP GDExtension (addons/twovoip) on desktop; with neither we fall back to the old
## 16 kHz mu-law packet, which every client still decodes. Silence under a threshold is not sent
## (that is our DTX). Packets: exactly 960 bytes = legacy mu-law; otherwise byte 0 is the format
## (0xA1 = Opus v1: [0xA1, n, n x u16 length, frames]); unknown formats are dropped.
## Spec: vault "Engine Specs/Voice Codec and Music.md".
## Playback: per speaker on the "Voice" bus, gain from distance (full <= 3 m, eased to silent at
## 14 m so conversations stay local). Settings live in UIRouter:
## "mic" (mic on/off), "push_to_talk" (hold the push_to_talk action), "voice" (volume).
## Per-player mutes and deafen persist in user://voice.cfg.

signal speaking_changed(peer_id: int, on: bool)
signal mic_problem(message: String)

const RATE := 48000
const FRAME := 960                  # 20 ms Opus frame
const FRAMES_PER_PACKET := 3        # 60 ms per network packet: few messages, same latency as before
const LEGACY_PACKET := 960          # 60 ms of 16 kHz mu-law, sent bare (the original format)
const OPUS_V1 := 0xA1
const BITRATE := 24000
const PREBUFFER := 0.12             # jitter cushion at the start of each talk spurt (s)
const NEAR := 3.0
const FAR := 14.0                   # Net.VOICE_RANGE sits just past this
const SILENCE_RMS := 0.012
const CFG := "user://voice.cfg"

var deafened := false
var muted_peers: Dictionary = {}    # peer name -> true (names survive reconnects; ids don't)
var codec := "mulaw"                # what this client sends: "opus-web", "opus-native" or "mulaw"
var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _mic_on := false
var _mic_started_at := 0.0
var _got_mic_frames := false
var _pending := PackedFloat32Array() # mono 48 kHz mic samples waiting to be framed
var _step := 1.0                    # input samples per 48 kHz output sample
var _phase := 0.0
var _prev := 0.0
var _hang := 0.0                    # keep sending briefly after speech ends (no word clipping)
var _frames: Array = []             # encoded Opus frames waiting for a packet
var _legacy := PackedFloat32Array() # 48 kHz samples waiting for a mu-law packet (no Opus encoder)
var _speakers: Dictionary = {}      # peer_id -> {player, playback, last, gain, spurt, opus_player, opus_pb, primed}
var _local_speaking := false
var _decode := PackedFloat32Array()
var _enc: Object                    # native TwovoipOpusEncoder
var _web_opus := false              # WebCodecs AudioEncoder/AudioDecoder available
var _tone := false                  # --voice-tone: 440 Hz test signal instead of the mic (headless tests)
var _tone_t := 0.0
var rx_packets := 0                 # accepted incoming packets (tests)
var rx_bytes := 0
var tx_bytes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 256:
		_decode.append(_mulaw_decode(i))
	_tone = OS.get_cmdline_user_args().has("--voice-tone")
	_setup_codec()
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('voicetest')")):
		# test hook (headless Chrome with a fake mic): open mic and log receive counts
		UIRouter.settings["mic"] = true
		UIRouter.settings["push_to_talk"] = false
		var t := Timer.new()
		t.wait_time = 2.0
		t.autostart = true
		t.timeout.connect(func() -> void: print("VOICE_RX packets=%d bytes=%d tx_bytes=%d codec=%s speaking=%s" % [rx_packets, rx_bytes, tx_bytes, codec, _local_speaking]))
		add_child(t)
	_load()
	_setup_buses()
	ControlsScreen.ensure_actions()


# ---- public API -----------------------------------------------------------------
func is_speaking(peer_id: int) -> bool:
	if peer_id == Net.local_id():
		return _local_speaking
	return _speakers.has(peer_id) and Time.get_ticks_msec() / 1000.0 - float(_speakers[peer_id]["last"]) < 0.3


## Someone audible is talking right now (Music ducks under it).
func anyone_talking() -> bool:
	for id in _speakers:
		if is_speaking(int(id)) and float(_speakers[id]["gain"]) > 0.05:
			return true
	return _local_speaking


## Distance gain: full within NEAR, eased to silent at FAR (squared, so 8 m is already about -10 dB).
static func gain_at(dist: float) -> float:
	var t := clampf((dist - NEAR) / (FAR - NEAR), 0.0, 1.0)
	return (1.0 - t) * (1.0 - t)


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
	var frames: Array = []
	if data.size() != LEGACY_PACKET:
		frames = parse_packet(data)
		if frames.is_empty():
			return  # unknown/newer format or corrupt: drop rather than play noise
		if not _web_opus and not ClassDB.class_exists("AudioStreamOpus"):
			return  # this client can't decode Opus
	var s := _speaker(from_id)
	var was := is_speaking(from_id)
	var now := Time.get_ticks_msec() / 1000.0
	var new_spurt := now - float(s["last"]) > 0.3
	s["last"] = now
	rx_packets += 1
	rx_bytes += data.size()
	if frames.is_empty():
		_push_pcm(s, _mulaw_to_48k(data), new_spurt)
	elif _web_opus:
		if new_spurt:
			s["spurt"] = true
		for f in frames:
			JavaScriptBridge.eval("pv.decode(%d,'%s')" % [from_id, Marshalls.raw_to_base64(f)])
	else:
		_push_opus(s, frames, new_spurt)
	if not was:
		speaking_changed.emit(from_id, true)


## [0xA1, n, n x u16 LE length, frames] -> Array of frame bytes; [] if malformed.
static func parse_packet(data: PackedByteArray) -> Array:
	if data.size() < 2 or data[0] != OPUS_V1:
		return []
	var n := data[1]
	var at := 2 + n * 2
	var out := []
	for i in n:
		if 2 + i * 2 + 2 > data.size():
			return []
		var size := data.decode_u16(2 + i * 2)
		if size == 0 or at + size > data.size():
			return []
		out.append(data.slice(at, at + size))
		at += size
	return out


static func build_packet(frames: Array) -> PackedByteArray:
	var out := PackedByteArray([OPUS_V1, frames.size()])
	out.resize(2 + frames.size() * 2)
	for i in frames.size():
		out.encode_u16(2 + i * 2, (frames[i] as PackedByteArray).size())
	for f in frames:
		out.append_array(f)
	if out.size() == LEGACY_PACKET:
		out.append(0)  # never look like a bare mu-law packet
	return out


# ---- capture + send ---------------------------------------------------------------
func _process(delta: float) -> void:
	var want := _want_mic()
	if want != _mic_on:
		_set_mic(want)
	if _mic_on:
		_pump_mic(delta)
	if _web_opus:
		_poll_web()
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
		_phase = 0.0
	else:
		_mic_player.stop()
		_capture.clear_buffer()
		_pending.clear()
		_end_spurt()


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
	if not _transmitting():
		_pending.clear()
		_end_spurt()
		return
	for f in buf:  # mono, linear-interpolated to 48 kHz (identity when the mix rate is 48 kHz)
		var x := (f.x + f.y) * 0.5
		while _phase < 1.0:
			_pending.append(lerpf(_prev, x, _phase))
			_phase += _step
		_phase -= 1.0
		_prev = x
	_flush_pending()


func _flush_pending() -> void:
	while _pending.size() >= FRAME:
		var chunk := _pending.slice(0, FRAME)
		_pending = _pending.slice(FRAME)
		var rms := 0.0
		for v in chunk:
			rms += v * v
		rms = sqrt(rms / FRAME)
		_hang = 0.5 if rms > SILENCE_RMS else maxf(_hang - 0.02, 0.0)
		if _hang <= 0.0:
			_end_spurt()
			continue
		_set_local_speaking(true)
		if _enc != null:
			var v2 := PackedVector2Array()
			v2.resize(FRAME)
			for i in FRAME:
				v2[i] = Vector2(chunk[i], chunk[i])
			_enc.call("process_chunk", v2)
			_queue_frame(_enc.call("encode_chunk", PackedByteArray(), 0))
		elif _web_opus:
			JavaScriptBridge.eval("pv.encode('%s')" % Marshalls.raw_to_base64(chunk.to_byte_array()))
		else:
			_legacy.append_array(chunk)
			if _legacy.size() >= LEGACY_PACKET * 3:
				_send(_legacy_packet(_legacy))
				_legacy.clear()


func _queue_frame(f: PackedByteArray) -> void:
	if f.is_empty():
		return
	_frames.append(f)
	if _frames.size() >= FRAMES_PER_PACKET:
		_send(build_packet(_frames))
		_frames.clear()


## Talk spurt over: send what is queued (a short last packet) so word endings aren't lost.
func _end_spurt() -> void:
	if not _frames.is_empty():
		_send(build_packet(_frames))
		_frames.clear()
	_legacy.clear()
	_set_local_speaking(false)


func _send(pkt: PackedByteArray) -> void:
	tx_bytes += pkt.size()
	Net.send_voice(pkt)


func _legacy_packet(pcm48: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(LEGACY_PACKET)
	for i in LEGACY_PACKET:  # box filter 48 -> 16 kHz
		out[i] = _mulaw_encode((pcm48[i * 3] + pcm48[i * 3 + 1] + pcm48[i * 3 + 2]) / 3.0)
	return out


## Web: collect the encoder's frames and each speaker's decoded PCM from the JS side.
func _poll_web() -> void:
	if bool(JavaScriptBridge.eval("pv.failed")):
		_web_opus = false  # encoder died (unsupported config): fall back to mu-law, keep talking
		codec = "mulaw"
		return
	var enc := str(JavaScriptBridge.eval("pv.take()"))
	if enc != "":
		for b in enc.split(","):
			_queue_frame(Marshalls.base64_to_raw(b))
	for id in _speakers:
		var pcm := str(JavaScriptBridge.eval("pv.takePcm(%d)" % int(id)))
		if pcm == "":
			continue
		var s: Dictionary = _speakers[id]
		for b in pcm.split(","):
			_push_pcm(s, Marshalls.base64_to_raw(b).to_float32_array(), bool(s["spurt"]))
			s["spurt"] = false


func _set_local_speaking(on: bool) -> void:
	if on != _local_speaking:
		_local_speaking = on
		speaking_changed.emit(Net.local_id(), on)


# ---- playback ------------------------------------------------------------------------
func _speaker(from_id: int) -> Dictionary:
	if _speakers.has(from_id):
		return _speakers[from_id]
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.5
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.bus = "Voice"
	add_child(p)
	p.play()
	var s := {"player": p, "playback": p.get_stream_playback(), "last": 0.0, "gain": 1.0, "spurt": true, "primed": 0}
	if not _web_opus and ClassDB.class_exists("AudioStreamOpus"):
		var st: AudioStream = ClassDB.instantiate("AudioStreamOpus")
		st.set("opus_sample_rate", RATE)
		st.set("opus_channels", 1)
		var op := AudioStreamPlayer.new()
		op.stream = st
		op.bus = "Voice"
		add_child(op)
		op.play()  # starts held on its end mark until PREBUFFER is queued (_push_opus)
		s["opus_player"] = op
		s["opus_pb"] = op.get_stream_playback()
	_speakers[from_id] = s
	return s


func _push_pcm(s: Dictionary, pcm: PackedFloat32Array, new_spurt: bool) -> void:
	var pb: AudioStreamGeneratorPlayback = s["playback"]
	if new_spurt:  # a little silence first so network jitter doesn't stutter the first words
		var lead := PackedVector2Array()
		lead.resize(int(PREBUFFER * RATE))
		if pb.get_frames_available() >= lead.size():
			pb.push_buffer(lead)
	var frames := PackedVector2Array()
	frames.resize(pcm.size())
	for i in pcm.size():
		frames[i] = Vector2(pcm[i], pcm[i])
	if pb.get_frames_available() >= frames.size():  # running behind: drop this packet, not the stream
		pb.push_buffer(frames)


## TwoVoIP playback holds at an end mark: set one at each spurt start, clear it once the cushion is
## queued, so a jittery network stretches the start instead of stuttering mid-word.
func _push_opus(s: Dictionary, frames: Array, new_spurt: bool) -> void:
	var pb: Object = s["opus_pb"]
	if new_spurt:
		pb.call("mark_end_opus_stream", false)
		s["primed"] = 0
	for f in frames:
		if int(pb.call("available_space_frames")) >= FRAME:
			pb.call("push_opus_packet", f, 0, 0)
	var before := int(s["primed"])
	s["primed"] = before + frames.size()
	var need := int(ceil(PREBUFFER * RATE / FRAME))
	if before < need and int(s["primed"]) >= need:
		pb.call("mark_end_opus_stream", true)


func _mulaw_to_48k(data: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(data.size() * 3)
	var prev := _decode[data[0]]
	for i in data.size():
		var v := _decode[data[i]]
		out[i * 3] = lerpf(prev, v, 1.0 / 3.0)
		out[i * 3 + 1] = lerpf(prev, v, 2.0 / 3.0)
		out[i * 3 + 2] = v
		prev = v
	return out


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
			g = gain_at(me.global_position.distance_to(who.global_position))
		s["gain"] = g
		(s["player"] as AudioStreamPlayer).volume_db = linear_to_db(maxf(g, 0.0001))
		if s.has("opus_player"):
			(s["opus_player"] as AudioStreamPlayer).volume_db = linear_to_db(maxf(g, 0.0001))
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


# ---- codec setup -------------------------------------------------------------------
## WebCodecs bridge: GDScript passes 20 ms Float32 frames as base64 and polls encoded frames and
## per-speaker decoded PCM back (comma-joined base64). Raw Opus packets, same as TwoVoIP's.
const WEB_CODEC_JS := """
(function () {
  if (window.pv) return window.pv.ok;
  var ok = typeof AudioEncoder !== 'undefined' && typeof AudioDecoder !== 'undefined';
  var pv = window.pv = { ok: ok, failed: false, out: [], dec: {}, t: 0 };
  if (!ok) return false;
  var b2u = function (s) { return Uint8Array.from(atob(s), function (c) { return c.charCodeAt(0); }); };
  var u2b = function (u) { var s = ''; for (var i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
  var cfg = { codec: 'opus', sampleRate: 48000, numberOfChannels: 1, bitrate: %d,
              opus: { frameDuration: 20000, complexity: 5 } };
  pv.newEnc = function () {
    pv.enc = new AudioEncoder({
      output: function (c) { var u = new Uint8Array(c.byteLength); c.copyTo(u); pv.out.push(u2b(u)); },
      error: function (e) { pv.failed = true; console.warn('voice encoder', e); } });
    pv.enc.configure(cfg);
  };
  pv.encode = function (s) {
    if (!pv.enc || pv.enc.state === 'closed') pv.newEnc();
    var f = new Float32Array(b2u(s).buffer);
    pv.enc.encode(new AudioData({ format: 'f32', sampleRate: 48000, numberOfChannels: 1,
      numberOfFrames: f.length, timestamp: pv.t, data: f }));
    pv.t += f.length * 1e6 / 48000;
  };
  pv.take = function () { return pv.out.splice(0).join(','); };
  pv.decode = function (id, s) {
    var d = pv.dec[id];
    if (!d || d.c.state === 'closed') {
      d = pv.dec[id] = { q: [], t: 0 };
      d.c = new AudioDecoder({
        output: function (a) { var f = new Float32Array(a.numberOfFrames);
          a.copyTo(f, { planeIndex: 0, format: 'f32-planar' }); a.close(); d.q.push(u2b(new Uint8Array(f.buffer))); },
        error: function (e) { console.warn('voice decoder', e); } });
      d.c.configure({ codec: 'opus', sampleRate: 48000, numberOfChannels: 1 });
    }
    d.c.decode(new EncodedAudioChunk({ type: 'key', timestamp: d.t, data: b2u(s) }));
    d.t += 20000;
  };
  pv.takePcm = function (id) { var d = pv.dec[id]; return d ? d.q.splice(0).join(',') : ''; };
  try { pv.newEnc(); } catch (e) { pv.ok = false; console.warn('voice: no Opus encoder', e); }
  return pv.ok;
})()
"""


func _setup_codec() -> void:
	if OS.has_feature("web"):
		_web_opus = bool(JavaScriptBridge.eval(WEB_CODEC_JS % BITRATE))
		codec = "opus-web" if _web_opus else "mulaw"
	elif ClassDB.class_exists("TwovoipOpusEncoder") and not OS.get_cmdline_user_args().has("--voice-mulaw"):
		_enc = ClassDB.instantiate("TwovoipOpusEncoder")
		# input is already 48 kHz mono (_pump_mic); no denoiser/AGC, matching the web side
		if int(_enc.call("initialize", RATE, RATE, 1, 0, 0, FRAME)) == OK and bool(_enc.call("create_opus_encoder", BITRATE, 5, true)):
			codec = "opus-native"
		else:
			_enc = null


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
