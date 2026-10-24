extends Node
## Host-authorized handoff: clients never receive the service's server key.
const Player := preload("res://ui/activities/cinema/cinema_player.gd")
var _overlay: Control
var _player: Node
var _seat: Node
var _request_id := ""
var _instance := ""
var _server_key := ""
var _server_url := ""
var _roster_busy := false
var _pending: Dictionary = {}
var _refresh := 0.0

func _ready() -> void:
	Activities.requested.connect(_on_activity)
	Net.host_lost.connect(_close)
	Net.roster_changed.connect(_check_membership)

func _process(delta: float) -> void:
	if Net.role_label() != "Host":
		if Net.role_label() != "Join":
			_close()
		_instance = ""
		_server_key = ""
		return
	_refresh -= delta
	if _refresh <= 0.0 and not _roster_busy:
		_refresh = 3.0
		_publish_roster()

func _host_config() -> bool:
	if not _instance.is_empty():
		return not _server_key.is_empty()
	_instance = Crypto.new().generate_random_bytes(24).hex_encode()
	# Read only on the trusted host. This file is outside the exported game/repo.
	var path := OS.get_environment("PENGLOO_CINEMA_SERVER_ENV")
	if path.is_empty():
		path = OS.get_environment("HOME").path_join(".config/pengloo/cinema.env")
	var config := {}
	if FileAccess.file_exists(path):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var parts := line.split("=", true, 1)
			if parts.size() == 2:
				config[parts[0]] = parts[1]
	_server_key = OS.get_environment("CINEMA_GAME_SERVER_KEY")
	if _server_key.is_empty():
		_server_key = str(config.get("CINEMA_GAME_SERVER_KEY", ""))
	_server_url = OS.get_environment("PENGLOO_CINEMA_GATEWAY")
	if _server_url.is_empty():
		_server_url = str(config.get("CINEMA_ORIGIN", "")) + "/cinema/"
	return not _server_key.is_empty() and _server_url.begins_with("http")

func _member(id: int) -> Dictionary:
	for row in Net.roster():
		if int(row.get("id", 0)) == id and row.get("location") == "cinema" and not row.get("hidden", true):
			return row
	return {}

func _post(endpoint: String, data: Dictionary) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	var err := req.request(_server_url + "internal/" + endpoint, PackedStringArray(["Content-Type: application/json", "X-Pengloo-Server-Key: " + _server_key]), HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK:
		req.queue_free()
		return {}
	var result: Array = await req.request_completed
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return {}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

func _publish_roster() -> bool:
	if Net.role_label() != "Host" or not _host_config():
		return false
	while _roster_busy:
		await get_tree().process_frame
		if Net.role_label() != "Host":
			return false
	_roster_busy = true
	var members: Array = []
	for row in Net.roster():
		if not _member(int(row.id)).is_empty():
			members.append({"id": str(row.id), "name": str(row.name), "eligible": int(row.id) == 1})
	var response := await _post("roster", {"instance": _instance, "members": members})
	_roster_busy = false
	return bool(response.get("ok", false))

func _on_activity(activity: String, anchor: Node, player: Node) -> void:
	if activity != "cinema" or is_instance_valid(_overlay):
		return
	_player = player
	_seat = anchor if anchor is SeatSpot else null
	_overlay = Player.new()
	_overlay.finished.connect(_on_finished)
	UIRouter.push(_overlay)
	_request_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if Net.role_label() == "Host":
		_issue_ticket(1, _request_id)
	elif Net.role_label() == "Join":
		request_ticket.rpc_id(1, _request_id)
	else:
		_deliver_local(_request_id, "", "Join a hosted world to watch together.")

@rpc("any_peer", "call_remote", "reliable")
func request_ticket(request_id: String) -> void:
	if Net.role_label() == "Host":
		_issue_ticket(multiplayer.get_remote_sender_id(), request_id)

func _issue_ticket(id: int, request_id: String) -> void:
	if id <= 0 or request_id.length() != 32 or _pending.has(id):
		return
	if _member(id).is_empty():
		_send_ticket(id, request_id, "", "Enter the cinema before watching.")
		return
	_pending[id] = true
	var instance := _instance
	var ok := await _publish_roster()
	instance = _instance
	var response: Dictionary = {}
	if ok and not _member(id).is_empty():
		response = await _post("ticket", {"instance": instance, "member": str(id)})
	_pending.erase(id)
	if Net.role_label() != "Host" or instance != _instance:
		return
	var ticket := str(response.get("ticket", ""))
	if _member(id).is_empty():
		ticket = ""
	_send_ticket(id, request_id, ticket, "Cinema is unavailable. The host's cinema service may be offline." if ticket.is_empty() else "")

func _send_ticket(id: int, request_id: String, ticket: String, error: String) -> void:
	if id == 1:
		_deliver_local(request_id, ticket, error)
	elif multiplayer.get_peers().has(id):
		deliver_ticket.rpc_id(id, request_id, ticket, error)

@rpc("authority", "call_remote", "reliable")
func deliver_ticket(request_id: String, ticket: String, error: String) -> void:
	_deliver_local(request_id, ticket, error)

func _deliver_local(request_id: String, ticket: String, error: String) -> void:
	if request_id != _request_id or not is_instance_valid(_overlay):
		return
	if ticket.is_empty():
		for child in _overlay.get_children():
			child.queue_free()
		_overlay._show_error(error)
	else:
		_overlay.authorize(ticket)

func _check_membership() -> void:
	if is_instance_valid(_overlay) and _member(Net.local_id()).is_empty():
		_close()
	_refresh = 0.0

func _close() -> void:
	if is_instance_valid(_overlay):
		_overlay.close()

func _on_finished() -> void:
	_request_id = ""
	if is_instance_valid(_player):
		if is_instance_valid(_seat) and _player.has_method("current_bench") and _player.call("current_bench") == _seat:
			_player.call("stand_up")
	_overlay = null
	_player = null
	_seat = null
