extends Node
## Two real clients + a dedicated server (ENet, localhost) exercising invites end to end.
## Run tools/invite_mp.sh. Role "owner" drives; role "guest" reacts and asserts. Chat lines
## ("STEP n") keep the two in step. Prints INVITE_MP PASS/FAIL lines; exits 1 on any failure.
##  1. guest walks into the owner's home uninvited (owner: "only_me") -> denied, back in town
##  2. owner invites twice in a row -> guest gets ONE card, clicks Accept -> inside the owner's
##     home showing the owner's furniture; the owner sees the guest there
##  3. owner in the cinema invites -> guest accepts -> guest in the cinema
##  4. owner invites home again, guest accepts, owner quits -> guest is sent back to town

const LAYOUT := {"shell": "homes/snow_dome_interior", "items": [{"id": "room_kit/armchair", "cell": [3, 3], "rot": 90}]}

var role := "owner"
var w: Node
var _cards := 0
var _denied := 0
var _fails := 0
var _steps: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
	w = load("res://scenes/world.tscn").instantiate()
	add_child(w)
	Net.chat_received.connect(func(_who: String, msg: String) -> void: _steps.append(msg))
	Net.invite_received.connect(func(_a, _b, _c, _d) -> void: _cards += 1)
	Net.visit_denied.connect(func(_n) -> void: _denied += 1)
	get_tree().create_timer(150.0).timeout.connect(func() -> void: _fail("timeout"); get_tree().quit(1))
	await _until(func(): return Net.roster().size() == 2 and str(w.call("current_location_id")) == "town", 40.0)
	await get_tree().create_timer(1.0).timeout
	if role == "owner":
		await _owner()
	else:
		await _guest()


func _owner() -> void:
	var guest := _other()
	Net.set_visitors("only_me")
	Net.publish_home(JSON.stringify(LAYOUT))
	Net.say("STEP 1")
	await _wait_step("ACK 1")
	await w.travel_to("home", "InsideSpawn")
	Net.invite(guest, "home")
	Net.invite(guest, "home")  # duplicate inside the cooldown: dropped
	await _wait_step("ACK 2")
	_check("owner sees guest in home", w._puppets.has(guest) and is_instance_valid(w._puppets[guest]))
	await w.travel_to("cinema", "InsideLobby")
	Net.invite(guest, "cinema")
	await _wait_step("ACK 3")
	await w.travel_to("home", "InsideSpawn")
	await get_tree().create_timer(4.5).timeout  # past the cooldown
	Net.invite(guest, "home")
	await _wait_step("ACK 4")
	print("INVITE_MP owner done fails=%d" % _fails)
	Net.shutdown()  # leaving: the guest must be sent back to town
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1 if _fails else 0)


func _guest() -> void:
	var owner := _other()
	await _wait_step("STEP 1")
	await w.travel_to("home", "InsideSpawn", owner)
	await _until(func(): return _denied > 0 and str(w.call("current_location_id")) == "town" and not w.is_traveling(), 10.0)
	_check("uninvited visit denied, back in town", _denied == 1 and str(w.call("current_location_id")) == "town")
	Net.say("ACK 1")
	await _until(func(): return _cards > 0, 10.0)
	await get_tree().create_timer(1.5).timeout
	_check("duplicate invite dropped (one card)", _cards == 1)
	_press_accept()
	await _until(func(): return str(w.call("current_location_id")) == "home" and not w.is_traveling(), 10.0)
	_check("accepted home invite -> owner's home", str(w.call("current_location_id")) == "home" and int(w.call("home_owner_id")) == owner)
	await get_tree().create_timer(1.5).timeout
	var layout: Node = w.get_node("LocationHost").find_child("HouseLayout", true, false)
	var ids: Array = layout.items.map(func(it): return "%s@%s" % [it["id"], it["cell"]]) if layout else []
	_check("guest sees owner's furniture", ids == ["room_kit/armchair@(3, 3)"])
	Net.say("ACK 2")
	await _until(func(): return _cards > 1, 15.0)
	await get_tree().create_timer(0.5).timeout
	_press_accept()
	await _until(func(): return str(w.call("current_location_id")) == "cinema" and not w.is_traveling(), 10.0)
	_check("accepted cinema invite -> cinema", str(w.call("current_location_id")) == "cinema")
	Net.say("ACK 3")
	await _until(func(): return _cards > 2, 15.0)
	await get_tree().create_timer(0.5).timeout
	_press_accept()
	await _until(func(): return str(w.call("current_location_id")) == "home" and not w.is_traveling(), 10.0)
	Net.say("ACK 4")
	await _until(func(): return str(w.call("current_location_id")) == "town" and not w.is_traveling(), 15.0)
	_check("host left -> guest back in town", str(w.call("current_location_id")) == "town")
	print("INVITE_MP guest done fails=%d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _press_accept() -> void:
	var card := UIRouter.top()
	for b in (card.find_children("*", "Button", true, false) if card else []):
		if (b as Button).text == "Accept":
			(b as Button).pressed.emit()
			return
	_fail("no Accept button on the invite card")


func _other() -> int:
	for e in Net.roster():
		if int(e["id"]) != Net.local_id():
			return int(e["id"])
	return 0


func _wait_step(s: String) -> void:
	await _until(func(): return _steps.has(s), 30.0)


func _until(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while not cond.call() and t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _check(what: String, ok: bool) -> void:
	print("INVITE_MP %s %s: %s" % [role, "PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _fail(what: String) -> void:
	_check(what, false)
