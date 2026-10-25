class_name LobbyLink
extends Node
## A community server's link to the pengloo.party lobby (docs/Engine Specs/Community Servers.md).
## Dials OUT to <lobby>/host, registers, heartbeats, and bridges every relayed player channel into
## a local WebSocket to our own WebSocketMultiplayerPeer, so Net sees ordinary clients and no game
## code changes. Started by Net.host_game() on a dedicated server run with --public.
## Wire format (services/lobby/main.go): text = JSON control, binary = [u32 LE ch][u8 opcode][payload].
## Optional cinema: the host's OWN gateway (services/cinema with the host's media server and codes)
## is reached by players at /s/<id>/cinema/*; each request arrives as a "cinema" channel carrying raw
## TCP bytes for that gateway. The host's credentials stay on this machine.

const HEARTBEAT_S := 15.0
const BUFFER := 1 << 22   # every player's traffic shares the host socket
const TOKEN_FILE := "user://lobby_host_token.txt"

var _host := WebSocketPeer.new()
var _open := false
var _local := {}     # ch -> WebSocketPeer into 127.0.0.1:Net.PORT
var _tcp := {}       # ch -> StreamPeerTCP into our cinema gateway
var _cinema_pid := -1
const HELPER_PORT := 8195
var _queued := {}    # ch -> Array of [opcode, payload] waiting for that local socket to open
var _hb := 0.0
var _retry_in := 0.0
var _backoff := 2.0
var listed_id := ""


func _ready() -> void:
	if Net.host_cinema == "" and Net.host_cinema_env != "":
		_start_cinema_helper()
	if not Net.dedicated:  # a listen-host plays on its own community server
		Net.community = true
		Net.community_cinema = Net.host_cinema != ""
	_connect()


func _exit_tree() -> void:
	_drop_all()
	if _cinema_pid > 0:
		OS.kill(_cinema_pid)  # the helper only serves this hosting session


## Bundled gateway next to the game (deploy/build-desktop.sh puts it there), or PENGLOO_CINEMA_BIN.
static func helper_path() -> String:
	var env := OS.get_environment("PENGLOO_CINEMA_BIN")
	if env != "":
		return env
	var exe := OS.get_executable_path().get_base_dir()
	var file := "pengloo-cinema.exe" if OS.has_feature("windows") else "pengloo-cinema"
	for dir in [exe, exe.path_join("../../..")]:  # macOS: beside PenglooParty.app
		if FileAccess.file_exists(dir.path_join(file)):
			return dir.path_join(file).simplify_path()
	return ""


func _start_cinema_helper() -> void:
	var bin := helper_path()
	if bin == "":
		push_warning("LOBBY cinema helper not found; this server lists without a cinema")
		return
	# the env file is the host's own (EMBY_*, CINEMA_*_CODE); listen address and origin are ours
	OS.set_environment("CINEMA_LISTEN", "127.0.0.1:%d" % HELPER_PORT)  # set vars beat the file's
	OS.set_environment("CINEMA_ORIGIN", Net.lobby_base())  # players' browsers are on pengloo.party
	_cinema_pid = OS.create_process(bin, ["--env", ProjectSettings.globalize_path(Net.host_cinema_env)])
	if _cinema_pid > 0:
		Net.host_cinema = "127.0.0.1:%d" % HELPER_PORT
		print("LOBBY cinema helper started (pid %d)" % _cinema_pid)


func _connect() -> void:
	_host = WebSocketPeer.new()
	_host.inbound_buffer_size = BUFFER
	_host.outbound_buffer_size = BUFFER
	_host.max_queued_packets = 16384
	var url := Net.lobby_base().replace("https://", "wss://").replace("http://", "ws://") + "/host?token=" + _token().uri_encode()
	if _host.connect_to_url(url) != OK:
		_schedule_retry("couldn't open the lobby socket")
	_open = false


func _process(delta: float) -> void:
	if _retry_in > 0.0:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
		return
	_host.poll()
	var st := _host.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _open:
		_open = true
		_send_ctrl({"t": "register", "name": _name(), "max": Net.max_players, "version": Net.build_version(),
			"region": OS.get_environment("PENGLOO_SERVER_REGION"), "cinema": Net.host_cinema != ""})
	elif st == WebSocketPeer.STATE_CLOSED:
		_drop_all()
		_schedule_retry("lobby closed (%d %s)" % [_host.get_close_code(), _host.get_close_reason()])
		return
	if not _open:
		return
	while _host.get_available_packet_count() > 0:
		var pkt := _host.get_packet()
		if _host.was_string_packet():
			_on_ctrl(JSON.parse_string(pkt.get_string_from_utf8()))
		elif pkt.size() >= 5:
			_to_local(pkt.decode_u32(0), pkt[4], pkt.slice(5))
	for ch in _local.keys():
		_pump(ch)
	for ch in _tcp.keys():
		_pump_tcp(ch)
	_hb -= delta
	if _hb <= 0.0:
		_hb = HEARTBEAT_S
		_send_ctrl({"t": "hb", "players": Net.roster().size()})


func _on_ctrl(m: Variant) -> void:
	if not (m is Dictionary):
		return
	match str(m.get("t", "")):
		"registered":
			listed_id = str(m.get("id", ""))
			_backoff = 2.0
			CinemaService.retarget()  # our own players (and we) reach our cinema through the relay
			print("LOBBY listed as %s (%s): players join from the Servers list on pengloo.party" % [listed_id, _name()])
		"error":
			push_warning("LOBBY refused: %s" % str(m.get("error", "")))
			_backoff = 60.0  # a rejected name won't fix itself quickly
		"ping":
			_send_ctrl({"t": "pong", "at": m.get("at", 0)})
		"open":
			var ch := int(m.get("ch", 0))
			if str(m.get("kind", "")) == "cinema":
				_open_cinema(ch)
				return
			var ws := WebSocketPeer.new()
			ws.inbound_buffer_size = 1 << 20
			ws.outbound_buffer_size = 1 << 20
			ws.connect_to_url("ws://127.0.0.1:%d" % Net.PORT)
			_local[ch] = ws
			_queued[ch] = []
		"close":
			var ch := int(m.get("ch", 0))
			if _tcp.has(ch):
				(_tcp[ch] as StreamPeerTCP).disconnect_from_host()
				_tcp.erase(ch)
				_queued.erase(ch)
			if _local.has(ch):
				(_local[ch] as WebSocketPeer).close()
				_local.erase(ch)
				_queued.erase(ch)


func _to_local(ch: int, op: int, payload: PackedByteArray) -> void:
	if _tcp.has(ch):
		var tcp: StreamPeerTCP = _tcp[ch]
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.put_data(payload)
		else:
			(_queued[ch] as Array).append([op, payload])
		return
	if not _local.has(ch):
		return
	var ws: WebSocketPeer = _local[ch]
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		(_queued[ch] as Array).append([op, payload])
		return
	_send_local(ws, op, payload)


func _send_local(ws: WebSocketPeer, op: int, payload: PackedByteArray) -> void:
	if op == 1:
		ws.send_text(payload.get_string_from_utf8())
	else:
		ws.send(payload)


## One player's local socket: flush what queued while it opened, relay its packets to the lobby.
func _pump(ch: int) -> void:
	var ws: WebSocketPeer = _local[ch]
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		_local.erase(ch)
		_queued.erase(ch)
		_send_ctrl({"t": "close", "ch": ch})
		return
	if st != WebSocketPeer.STATE_OPEN:
		return
	for q in _queued[ch]:
		_send_local(ws, q[0], q[1])
	(_queued[ch] as Array).clear()
	while ws.get_available_packet_count() > 0:
		var payload := ws.get_packet()
		var frame := PackedByteArray()
		frame.resize(5)
		frame.encode_u32(0, ch)
		frame[4] = 1 if ws.was_string_packet() else 2
		frame.append_array(payload)
		_host.send(frame)


func _open_cinema(ch: int) -> void:
	var at := Net.host_cinema.rsplit(":", true, 1)
	var ip := IP.resolve_hostname(at[0]) if at.size() == 2 else ""
	var tcp := StreamPeerTCP.new()
	if ip == "" or tcp.connect_to_host(ip, int(at[1])) != OK:
		_send_ctrl({"t": "close", "ch": ch})
		return
	_tcp[ch] = tcp
	_queued[ch] = []


## One cinema request: raw HTTP bytes both ways. Read before checking the status, so the response
## bytes that arrive just before the gateway closes (Connection: close) aren't lost.
func _pump_tcp(ch: int) -> void:
	var tcp: StreamPeerTCP = _tcp[ch]
	tcp.poll()
	var st := tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		return
	if st == StreamPeerTCP.STATUS_CONNECTED:
		for q in _queued[ch]:
			tcp.put_data(q[1])
		(_queued[ch] as Array).clear()
		var n := tcp.get_available_bytes()
		if n > 0:
			var got: Array = tcp.get_partial_data(mini(n, 1 << 16))
			if got[0] == OK and (got[1] as PackedByteArray).size() > 0:
				var frame := PackedByteArray()
				frame.resize(5)
				frame.encode_u32(0, ch)
				frame[4] = 2
				frame.append_array(got[1])
				_host.send(frame)
			return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_tcp.erase(ch)
		_queued.erase(ch)
		_send_ctrl({"t": "close", "ch": ch})


func _send_ctrl(m: Dictionary) -> void:
	if _host.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_host.send_text(JSON.stringify(m))


func _drop_all() -> void:
	for ch in _local:
		(_local[ch] as WebSocketPeer).close()
	_local.clear()
	for ch in _tcp:
		(_tcp[ch] as StreamPeerTCP).disconnect_from_host()
	_tcp.clear()
	_queued.clear()


func _schedule_retry(why: String) -> void:
	_open = false
	_retry_in = _backoff
	push_warning("LOBBY %s; retrying in %d s" % [why, int(_backoff)])
	_backoff = minf(_backoff * 2.0, 60.0)


func _name() -> String:
	return Net.server_name if Net.server_name != "" else "Penguin Server"


## Stable per server (the lobby derives the listing id from it), kept in user:// so a restart
## keeps its spot and favourites. PENGLOO_HOST_TOKEN overrides, e.g. for a container without storage.
func _token() -> String:
	var env := OS.get_environment("PENGLOO_HOST_TOKEN")
	if env.length() >= 16:
		return env
	var f := FileAccess.open(TOKEN_FILE, FileAccess.READ)
	if f:
		var t := f.get_as_text().strip_edges()
		if t.length() >= 16:
			return t
	var token := Crypto.new().generate_random_bytes(24).hex_encode()
	var w := FileAccess.open(TOKEN_FILE, FileAccess.WRITE)
	if w:
		w.store_string(token)
	return token
