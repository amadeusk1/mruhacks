class_name SledRaceGame
extends RefCounted
## Sled Hill rules, authoritative on the server (or the solo player). No networking in here.
## Race: lobby (2-8, auto-starts LOBBY_WAIT s after the 2nd racer, or "start now") -> countdown ->
## racing -> results -> idle. Time trial: any time, one rider, own clock. Progress, checkpoints and
## finish times come from the server's view of the riders' poses (SledCourse), never from clients.

const MAX_RACERS := 8
const LOBBY_WAIT := 10.0
const LOBBY_TOP_UP := 5.0     ## a late join keeps at least this long to get ready
const COUNTDOWN := 3.0
const DNF_AFTER := 30.0       ## after the first finisher
const RACE_CAP := 150.0
const RESULTS_HOLD := 12.0
const MAX_JUMP := 25.0        ## metres of course between two poses before a pose is ignored

var phase := "idle"
var race_id := 0
var lobby: Array = []          ## ids, join order = grid order
var pending: Array = []        ## joined during a race: next lobby
var racers := {}               ## id -> {s, cp, done, time, dnf, lane}
var trials := {}               ## id -> {start, s, cp}
var trial_results := {}        ## id -> {time, rank, best}
var names := {}
var board: Array = []          ## [{name, time}] best 10, fastest first
var deadline := 0.0
var start_at := 0.0
var first_finish := 0.0
var results_at := 0.0
var version := 0
var _trial_serial := 0


func join(id: int, player_name: String, t: float) -> void:
	names[id] = player_name
	trials.erase(id)
	trial_results.erase(id)
	if phase == "countdown" or phase == "racing":
		if not pending.has(id) and not racers.has(id):
			pending.append(id)
		_bump()
		return
	if phase == "results":
		_to_idle()
	if lobby.has(id) or lobby.size() >= MAX_RACERS:
		return
	lobby.append(id)
	phase = "lobby"
	if lobby.size() == 2:
		deadline = t + LOBBY_WAIT
	elif lobby.size() > 2:
		deadline = maxf(deadline, t + LOBBY_TOP_UP)
	_bump()


func leave(id: int, _t: float) -> void:
	lobby.erase(id)
	pending.erase(id)
	trials.erase(id)
	trial_results.erase(id)
	if racers.has(id) and not bool(racers[id]["done"]):
		racers[id]["dnf"] = true
		racers[id]["done"] = true
	if phase == "lobby" and lobby.size() < 2:
		deadline = 0.0
		if lobby.is_empty():
			phase = "idle"
	_bump()


func start_now(id: int, t: float) -> void:
	if phase == "lobby" and lobby.has(id) and lobby.size() >= 2:
		deadline = t
		_bump()


## Starts a solo time trial; the rider gets COUNTDOWN seconds before their clock runs.
func trial(id: int, player_name: String, t: float) -> void:
	names[id] = player_name
	if racers.has(id) and phase in ["countdown", "racing"] and not bool(racers[id]["done"]):
		return
	lobby.erase(id)
	pending.erase(id)
	if phase == "lobby" and lobby.is_empty():
		phase = "idle"
	_trial_serial += 1
	trials[id] = {"start": t + COUNTDOWN, "s": 0.0, "cp": 0, "n": _trial_serial}
	trial_results.erase(id)
	_bump()


func pose(id: int, at: Vector3, t: float) -> void:
	var r: Dictionary = {}
	var started := 0.0
	if trials.has(id):
		r = trials[id]
		started = float(r["start"])
	elif racers.has(id) and phase == "racing" and not bool(racers[id]["done"]):
		r = racers[id]
		started = start_at
	else:
		return
	if t < started:
		return
	var s := SledCourse.locate(at, float(r["s"]) if float(r["s"]) > 0.0 else -1.0).x
	if float(r["s"]) > 0.0 and absf(s - float(r["s"])) > MAX_JUMP:
		return  # teleport / stale pose: ignore
	r["s"] = s
	while int(r["cp"]) < SledCourse.CHECKPOINTS.size() and s >= float(SledCourse.CHECKPOINTS[int(r["cp"])]):
		r["cp"] = int(r["cp"]) + 1
	if s < SledCourse.finish_s() or int(r["cp"]) < SledCourse.CHECKPOINTS.size():
		return
	var time := t - started
	if trials.has(id):
		trials.erase(id)
		var rank := _post(str(names.get(id, "Penguin")), time)
		trial_results[id] = {"time": time, "rank": rank, "best": _best_of(str(names.get(id, "")))}
	else:
		r["done"] = true
		r["time"] = time
		if first_finish <= 0.0:
			first_finish = t
		_post(str(names.get(id, "Penguin")), time)
	_bump()


func tick(t: float) -> void:
	for id in trials.keys():  # abandoned runs
		if t > float(trials[id]["start"]) + RACE_CAP:
			trials.erase(id)
			_bump()
	match phase:
		"lobby":
			if lobby.size() >= 2 and t >= deadline:
				_start(t)
		"countdown":
			if t >= start_at:
				phase = "racing"
				_bump()
		"racing":
			var all_done := true
			for id in racers:
				all_done = all_done and bool(racers[id]["done"])
			if all_done or (first_finish > 0.0 and t >= first_finish + DNF_AFTER) or t >= start_at + RACE_CAP:
				for id in racers:
					if not bool(racers[id]["done"]):
						racers[id]["done"] = true
						racers[id]["dnf"] = true
				phase = "results"
				results_at = t
				_bump()
		"results":
			if t >= results_at + RESULTS_HOLD:
				_to_idle()
				_bump()


## Live order: finishers by time, then everyone else by distance down the course.
func standings() -> Array:
	var rows: Array = []
	for id in racers:
		var r: Dictionary = racers[id]
		rows.append({"id": id, "name": str(names.get(id, "Penguin")), "s": float(r["s"]), "done": bool(r["done"]),
			"time": float(r["time"]), "dnf": bool(r["dnf"]), "lane": int(r["lane"])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa: bool = a["done"] and not a["dnf"]
		var fb: bool = b["done"] and not b["dnf"]
		if fa != fb:
			return fa
		if fa:
			return float(a["time"]) < float(b["time"])
		if bool(a["dnf"]) != bool(b["dnf"]):
			return not bool(a["dnf"])
		return float(a["s"]) > float(b["s"]))
	return rows


## What one rider (or a watcher on the hill) may see. Times are relative so clocks need not agree.
func view_for(id: int, t: float) -> Dictionary:
	var v := {"phase": phase, "race": race_id, "board": board, "lobby": [], "racer": racers.has(id),
		"in_lobby": lobby.has(id), "pending": pending.has(id), "left": 0.0}
	for lid in lobby:
		v["lobby"].append(str(names.get(lid, "Penguin")))
	if phase == "lobby" and lobby.size() >= 2:
		v["left"] = maxf(0.0, deadline - t)
	elif phase == "countdown" or phase == "racing":
		v["left"] = start_at - t  # negative once racing: elapsed race time
	if not racers.is_empty() and phase != "lobby" and phase != "idle":
		v["standings"] = standings()
	if racers.has(id):
		v["lane"] = int(racers[id]["lane"])
	if trials.has(id):
		v["trial_left"] = float(trials[id]["start"]) - t
		v["trial_id"] = int(trials[id]["n"])
	if trial_results.has(id):
		v["trial_result"] = trial_results[id]
	return v


func _start(t: float) -> void:
	race_id += 1
	racers.clear()
	for i in lobby.size():
		racers[lobby[i]] = {"s": 0.0, "cp": 0, "done": false, "time": 0.0, "dnf": false, "lane": i}
		trials.erase(lobby[i])
	lobby.clear()
	phase = "countdown"
	start_at = t + COUNTDOWN
	first_finish = 0.0
	_bump()


func _to_idle() -> void:
	phase = "idle"
	racers.clear()
	deadline = 0.0
	var queued := pending.duplicate()
	pending.clear()
	for id in queued:
		lobby.append(id)
	if not lobby.is_empty():
		phase = "lobby"
		if lobby.size() >= 2:
			deadline = results_at + RESULTS_HOLD + LOBBY_WAIT


## Adds a time to the board; returns its rank (1-based) or 0 if it didn't make the top 10.
## Each name keeps only its best time.
func _post(player_name: String, time: float) -> int:
	for e in board:
		if str(e["name"]) == player_name:
			if float(e["time"]) <= time:
				return 0
			board.erase(e)
			break
	board.append({"name": player_name, "time": snappedf(time, 0.01)})
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	board = board.slice(0, 10)
	for i in board.size():
		if str(board[i]["name"]) == player_name:
			return i + 1
	return 0


func _best_of(player_name: String) -> float:
	for e in board:
		if str(e["name"]) == player_name:
			return float(e["time"])
	return 0.0


func _bump() -> void:
	version += 1
