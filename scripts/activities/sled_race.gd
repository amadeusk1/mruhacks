extends Node
## SledRace autoload: the Sled Hill race/time-trial service over Net (ENet/WebSocket).
## The server (host, dedicated server, or the solo player) owns a SledRaceGame and feeds it every
## hill rider's pose (Net._relay_sled -> host_pose); riders send intents and receive their own view.
## The best-times board persists on the server (user://sled_board.json).
##
## Client: connect view_changed(view); call join_race() / leave_race() / start_now() / time_trial().

signal view_changed(view: Dictionary)

const BOARD_PATH := "user://sled_board.json"
const LIVE_SEND := 0.25

var game := SledRaceGame.new()   # server only
var view: Dictionary = {}
var _sent_version := -1
var _live_send := 0.0
var _members: Array = []


func _ready() -> void:
	Net.roster_changed.connect(_on_roster)
	_load_board()


func is_host() -> bool:
	return not Net.is_online() or multiplayer.is_server()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------ intents --
func join_race() -> void:
	_intent("join")


func leave_race() -> void:
	_intent("leave")


func start_now() -> void:
	_intent("start")


func time_trial() -> void:
	_intent("trial")


## Offline the local rider's poses never reach Net's relay: feed them here.
func local_pose(at: Vector3) -> void:
	if not Net.is_online():
		game.pose(Net.local_id(), at, now())


func _intent(action: String) -> void:
	if is_host():
		_host_intent(Net.local_id(), action)
	else:
		request_intent.rpc_id(1, action)


@rpc("any_peer", "call_remote", "reliable")
func request_intent(action: String) -> void:
	if multiplayer.is_server():
		_host_intent(multiplayer.get_remote_sender_id(), action)


@rpc("authority", "call_remote", "reliable")
func deliver_view(v: Dictionary) -> void:
	view = v
	view_changed.emit(view)


# --------------------------------------------------------------- host --
func host_pose(id: int, at: Vector3) -> void:
	if is_host():
		game.pose(id, at, now())


func _host_intent(peer: int, action: String) -> void:
	var t := now()
	if Net.is_online() and not _on_hill(peer):
		return
	var who := _name_of(peer)
	match action:
		"join": game.join(peer, who, t)
		"leave": game.leave(peer, t)
		"start": game.start_now(peer, t)
		"trial": game.trial(peer, who, t)
	_sync(true)


func _process(delta: float) -> void:
	if not is_host():
		return
	var before := game.version
	var board_before := str(game.board)
	game.tick(now())
	if str(game.board) != board_before or game.version != before:
		if str(game.board) != board_before:
			_save_board()
	_live_send -= delta
	var live := game.phase == "racing" or game.phase == "countdown" or not game.trials.is_empty()
	if game.version != _sent_version or (live and _live_send <= 0.0):
		_sync(false)


func _sync(_force: bool) -> void:
	_sent_version = game.version
	_live_send = LIVE_SEND
	var t := now()
	var ids: Array = _members if Net.is_online() else [Net.local_id()]
	for id in ids:
		var v := game.view_for(int(id), t)
		if int(id) == Net.local_id():
			view = v
			view_changed.emit(view)
		elif multiplayer.get_peers().has(int(id)):
			deliver_view.rpc_id(int(id), v)


## Riders who leave the hill (or the game) drop out of lobbies and races.
func _on_roster() -> void:
	if not Net.is_online() or not multiplayer.is_server():
		return
	var now_on: Array = []
	for e in Net.roster():
		if str(e.get("location", "")) == "sled_hill" and not bool(e.get("hidden", false)):
			now_on.append(int(e.get("id", 0)))
	for id in _members:
		if not now_on.has(id):
			game.leave(int(id), now())
	_members = now_on
	_sync(true)


func _on_hill(peer: int) -> bool:
	for e in Net.roster():
		if int(e.get("id", 0)) == peer:
			return str(e.get("location", "")) == "sled_hill" and not bool(e.get("hidden", false))
	return false


## Server-side name from the roster, never from the client.
func _name_of(peer: int) -> String:
	for e in Net.roster():
		if int(e.get("id", 0)) == peer:
			return str(e.get("name", "Penguin"))
	return str(Net.local_profile().get("name", "You")) if peer == Net.local_id() else "Penguin"


func _load_board() -> void:
	var f := FileAccess.open(BOARD_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		for e in data:
			if e is Dictionary and e.has("name") and e.has("time"):
				game.board.append({"name": str(e["name"]).substr(0, 16), "time": float(e["time"])})
	game.board = game.board.slice(0, 10)


func _save_board() -> void:
	var f := FileAccess.open(BOARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(game.board))
