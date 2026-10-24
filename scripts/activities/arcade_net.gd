extends Node
## ArcadeNet autoload: the arcade's shared state over Net.
##  - Duo cabinet matches (Puck Rally, Snow Trails): server-authoritative. Seated players pick a
##    game, ready up, get a 3-2-1 countdown, play, see results and can rematch. Everyone in the
##    arcade receives the live state, so the cabinet screen shows the match to onlookers.
##  - High score tables per solo game (top 10, persisted on the server in user://arcade_scores.json)
##    plus each cabinet's "now playing" line for the 3D screens.
## The server is the host, the dedicated server, or the solo player (offline everything is local).

signal duo_changed(cab: String, state: Dictionary)
signal boards_changed
signal playing_changed

const SCORES_PATH := "user://arcade_scores.json"
const GAMES := {"pac": 200000, "tetris": 999999, "dino": 99999, "fish": 99999, "star": 99999}   ## id -> score cap
const DUO_GAMES := ["puck", "trails"]
const COUNTDOWN := 3.0
const SEND_PLAYERS := 0.05
const SEND_ROOM := 0.1

var boards := {}        ## game -> [{name, score}]
var playing := {}       ## cabinet key -> {name, game, score}
var duo := {}           ## cab -> last state received (clients) / sent (server)

# server
var _tables := {}       ## cab -> {game, phase, ready, inputs, sim, until, send, room_send, players}
var _score_at := {}     ## peer -> last accepted score time
var _play_at := {}      ## peer -> cab key they report


func _ready() -> void:
	Net.roster_changed.connect(_on_roster)
	_load()


func is_host() -> bool:
	return not Net.is_online() or multiplayer.is_server()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------- client API --
func submit_score(game: String, score: int) -> void:
	_send("score", [game, score])


func report_playing(cab: String, game: String, score: int) -> void:
	_send("playing", [cab, game, score])


func stop_playing() -> void:
	_send("stop", [])


func duo_ready() -> void:
	_send("ready", [])


func duo_pick(game: String) -> void:
	_send("pick", [game])


func duo_input(value: float) -> void:
	if is_host():
		_host("input", Net.local_id(), [value])
	else:
		request_input.rpc_id(1, value)


func best_of(game: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load("user://arcade_best.cfg")
	return int(cfg.get_value("best", game, 0))


## Local personal best (kept even offline). True when it is a new best.
func note_local_best(game: String, score: int) -> bool:
	var cfg := ConfigFile.new()
	cfg.load("user://arcade_best.cfg")
	if score <= int(cfg.get_value("best", game, 0)):
		return false
	cfg.set_value("best", game, score)
	cfg.save("user://arcade_best.cfg")
	return true


func _send(action: String, args: Array) -> void:
	if is_host():
		_host(action, Net.local_id(), args)
	else:
		request.rpc_id(1, action, args)


@rpc("any_peer", "call_remote", "reliable")
func request(action: String, args: Array) -> void:
	if multiplayer.is_server():
		_host(action, multiplayer.get_remote_sender_id(), args)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func request_input(value: float) -> void:
	if multiplayer.is_server():
		_host("input", multiplayer.get_remote_sender_id(), [value])


@rpc("authority", "call_remote", "reliable")
func deliver_boards(b: Dictionary) -> void:
	boards = b
	boards_changed.emit()


@rpc("authority", "call_remote", "reliable")
func deliver_playing(p: Dictionary) -> void:
	playing = p
	playing_changed.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func deliver_duo(cab: String, state: Dictionary) -> void:
	duo[cab] = state
	duo_changed.emit(cab, state)


@rpc("authority", "call_remote", "reliable")
func deliver_duo_phase(cab: String, state: Dictionary) -> void:
	deliver_duo(cab, state)


# ------------------------------------------------------------------ server --
func _host(action: String, peer: int, args: Array) -> void:
	match action:
		"score":
			if args.size() == 2:
				_host_score(peer, str(args[0]), int(args[1]))
		"playing":
			if args.size() == 3 and _in_arcade(peer):
				var cab := str(args[0]).substr(0, 80)
				_play_at[peer] = cab
				var row := {"name": _name_of(peer), "game": str(args[1]).substr(0, 12), "score": clampi(int(args[2]), 0, 9999999)}
				if str(playing.get(cab, {})) != str(row):
					playing[cab] = row
					_push_playing()
		"stop":
			if _play_at.has(peer):
				playing.erase(_play_at[peer])
				_play_at.erase(peer)
				_push_playing()
		"ready", "pick", "input":
			var cab := _cab_of_peer(peer)
			if cab == "":
				return
			var t := _table(cab)
			var side := (t.get("seated", t["players"]) as Array).find(peer)
			if side < 0:
				return
			if action == "input":
				if args.size() == 1:  # live input is sent out with the next state, not echoed
					t["inputs"][side] = float(args[0])
					if t["sim"] is TrailsGame and str(t["phase"]) == "live":
						(t["sim"] as TrailsGame).set_dir(side, int(args[0]))
				return
			if action == "ready" and str(t["phase"]) in ["idle", "results"]:
				t["ready"][peer] = true
			elif action == "pick" and args.size() == 1 and str(t["phase"]) in ["idle", "results"] and DUO_GAMES.has(str(args[0])):
				t["game"] = str(args[0])
				t["ready"] = {}
				t["phase"] = "idle"
			_publish(cab, true)


func _host_score(peer: int, game: String, score: int) -> void:
	if not GAMES.has(game) or score <= 0:
		return
	var t := now()
	if t - float(_score_at.get(peer, -10.0)) < 3.0:
		return  # one game over every few seconds at most
	_score_at[peer] = t
	score = mini(score, int(GAMES[game]))  # shortcut: solo games run on the client, so a score is capped not proven; server-side replays if cheating shows up
	var who := _name_of(peer)
	var list: Array = boards.get(game, [])
	for e in list:
		if str(e["name"]) == who:
			if int(e["score"]) >= score:
				return
			list.erase(e)
			break
	list.append({"name": who, "score": score})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	boards[game] = list.slice(0, 10)
	_save()
	_push_boards()


func _process(delta: float) -> void:
	if not is_host():
		return
	for cab in _tables.keys():
		var t: Dictionary = _tables[cab]
		var phase := str(t["phase"])
		var players: Array = t["players"]
		if players.size() < 2:
			if phase == "live" or phase == "countdown":
				t["phase"] = "results"
				t["sim"] = null
				_publish(cab, true)
			continue
		if phase in ["idle", "results"] and bool(t["ready"].get(players[0], false)) and bool(t["ready"].get(players[1], false)):
			t["phase"] = "countdown"
			t["until"] = now() + COUNTDOWN
			t["ready"] = {}
			t["inputs"] = {0: 0.5, 1: 0.5} if str(t["game"]) == "puck" else {0: 1, 1: 3}
			if str(t["game"]) == "puck":
				var board := PuckBoard.new()
				board.start()
				board.running = false
				t["sim"] = board
			else:
				var trails := TrailsGame.new()
				trails.start()
				t["sim"] = trails
			_publish(cab, true)
		elif phase == "countdown" and now() >= float(t["until"]):
			t["phase"] = "live"
			if t["sim"] is PuckBoard:
				(t["sim"] as PuckBoard).running = true
			_publish(cab, true)
		elif phase == "live":
			var done := false
			if t["sim"] is PuckBoard:
				var board: PuckBoard = t["sim"]
				board.step_with(delta, float(t["inputs"].get(0, 0.5)), float(t["inputs"].get(1, 0.5)))
				done = not board.running
			else:
				var trails: TrailsGame = t["sim"]
				trails.step(delta)
				done = trails.done
			if done:
				t["phase"] = "results"
				_publish(cab, true)
				t["sim"] = null
			else:
				_publish(cab, false, delta)


func _table(cab: String) -> Dictionary:
	if not _tables.has(cab):
		_tables[cab] = {"game": "puck", "phase": "idle", "ready": {}, "inputs": {}, "sim": null, "until": 0.0,
			"send": 0.0, "room_send": 0.0, "players": [], "last": {}}
	return _tables[cab]


## The state players and onlookers see. Reliable on phase changes, unreliable while live.
func _publish(cab: String, reliable: bool, delta := 0.0) -> void:
	var t: Dictionary = _table(cab)
	var state := {"cab": cab, "game": t["game"], "phase": t["phase"], "names": _names(t["players"]),
		"ids": t["players"], "ready": t["ready"].keys(), "left": maxf(0.0, float(t["until"]) - now())}
	if t["sim"] is PuckBoard:
		state.merge((t["sim"] as PuckBoard).pose())
	elif t["sim"] is TrailsGame:
		state.merge((t["sim"] as TrailsGame).view())
	elif t["last"].has("sa"):
		state["sa"] = t["last"]["sa"]
		state["sb"] = t["last"]["sb"]
	if state.has("sa"):
		t["last"] = {"sa": state["sa"], "sb": state["sb"]}
	t["send"] = float(t["send"]) - delta
	t["room_send"] = float(t["room_send"]) - delta
	var to_players := reliable or float(t["send"]) <= 0.0
	var to_room := reliable or float(t["room_send"]) <= 0.0
	if not to_players and not to_room:
		return
	if to_players:
		t["send"] = SEND_PLAYERS
	if to_room:
		t["room_send"] = SEND_ROOM
	duo[cab] = state
	for id in _arcade_peers():
		var seated: bool = (t["players"] as Array).has(id)
		if not (to_room or (seated and to_players)):
			continue
		if id == Net.local_id():
			duo_changed.emit(cab, state)
		elif multiplayer.get_peers().has(id):
			if reliable:
				deliver_duo_phase.rpc_id(id, cab, state)
			else:
				deliver_duo.rpc_id(id, cab, state)


func _push_boards() -> void:
	boards_changed.emit()
	if not Net.is_online():
		return
	for id in _arcade_peers():
		if id != Net.local_id() and multiplayer.get_peers().has(id):
			deliver_boards.rpc_id(id, boards)


func _push_playing() -> void:
	playing_changed.emit()
	if not Net.is_online():
		return
	for id in _arcade_peers():
		if id != Net.local_id() and multiplayer.get_peers().has(id):
			deliver_playing.rpc_id(id, playing)


## Seats decide who is at which duo cabinet; leaving the arcade drops "now playing".
var _was_in: Array = []


func _on_roster() -> void:
	if not is_host():
		return
	var seats := {}
	for e in Net.roster():
		var bench := str(e.get("bench", ""))
		var cab := _cab_of_bench(bench)
		if cab != "":
			if not seats.has(cab):
				seats[cab] = [0, 0]
			seats[cab][1 if bench.ends_with("_player_2") else 0] = int(e.get("id", 0))
	for cab in _tables.keys():
		if not seats.has(cab):
			_tables[cab]["players"] = []
	for cab in seats:
		var pair: Array = seats[cab]
		var t := _table(cab)
		var players: Array = [] if (int(pair[0]) == 0 or int(pair[1]) == 0) else pair
		if str(players) != str(t["players"]):
			t["players"] = players
			t["ready"] = {}
			if str(t["phase"]) != "live" and str(t["phase"]) != "countdown":
				t["phase"] = "idle"
		# a lone player still sees the cabinet lobby state
		t["seated"] = pair
		_publish(cab, true)
	var now_in := _arcade_peers()
	for peer in _play_at.keys():
		if not now_in.has(peer):
			playing.erase(_play_at[peer])
			_play_at.erase(peer)
			_push_playing()
	for id in now_in:  # newcomers get the boards and screens
		if not _was_in.has(id) and id != Net.local_id() and multiplayer.get_peers().has(id):
			deliver_boards.rpc_id(id, boards)
			deliver_playing.rpc_id(id, playing)
	_was_in = now_in


func _arcade_peers() -> Array:
	if not Net.is_online():
		return [Net.local_id()]
	var out: Array = []
	for e in Net.roster():
		if str(e.get("location", "")) == "arcade" and not bool(e.get("hidden", false)):
			out.append(int(e.get("id", 0)))
	return out


func _in_arcade(peer: int) -> bool:
	return not Net.is_online() or _arcade_peers().has(peer)


func _cab_of_peer(peer: int) -> String:
	for e in Net.roster():
		if int(e.get("id", 0)) == peer:
			return _cab_of_bench(str(e.get("bench", "")))
	return ""


static func _cab_of_bench(bench: String) -> String:
	for suffix in ["_player_1", "_player_2"]:
		if bench.ends_with(suffix):
			return bench.trim_suffix(suffix)
	return ""


func _names(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append(_name_of(int(id)))
	return out


func _name_of(peer: int) -> String:
	for e in Net.roster():
		if int(e.get("id", 0)) == peer:
			return str(e.get("name", "Penguin"))
	return str(Net.local_profile().get("name", "You"))


func _load() -> void:
	var f := FileAccess.open(SCORES_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	for game in data:
		if GAMES.has(str(game)) and data[game] is Array:
			var list: Array = []
			for e in data[game]:
				if e is Dictionary and e.has("name") and e.has("score"):
					list.append({"name": str(e["name"]).substr(0, 16), "score": mini(int(e["score"]), int(GAMES[str(game)]))})
			boards[str(game)] = list.slice(0, 10)


func _save() -> void:
	var f := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(boards))
