extends Node

## A "dumb" extra player for filming: joins the local host like any client, then keeps
## click-walking to a spot beside the host's penguin and follows it between locations.
## Run one process per bot (headless is fine; the host assigns each a coat colour):
##   Godot --headless --path . res://tools/follow_bot.tscn -- --net-name=Pip --slot=0
## --slot=N (0..7) picks the bot's place in a ring around the host so they don't bunch up.
## --leader=Name follows that player instead of the host.
## Exits 3 if the host drops it (tools/follow_bots.sh rejoins), 4 if no host answers.
##
## Building the town freezes this process for ~7 s, long enough for the host's ENet to drop it.
## So the bot builds the town in a solo session first, closes it (the world stays loaded and
## in game), then joins and just announces itself in town. Following the host back into town
## from a building rebuilds it and may get the bot dropped; the launcher then rejoins.

const RADIUS := 1.6
const RETARGET := 0.5   # re-path only when the goal has moved this far
const NEAR := 0.7       # close enough: stand still
const DOORS := {"cafe": "Inside", "arcade": "Inside", "casino": "Inside", "cinema": "InsideScreen"}  # rooms without a BusArrival

var _w: Node
var _name := "Bot"
var _slot := 0
var _leader := ""
var _goal := Vector3.INF
var _joined := false
var _fisher: Node
var _snow: Node
var _seat: Node
var _arrived := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-name="):
			_name = a.trim_prefix("--net-name=")
		elif a.begins_with("--slot="):
			_slot = int(a.trim_prefix("--slot="))
		elif a.begins_with("--leader="):
			_leader = a.trim_prefix("--leader=")
	_w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_w)
	await get_tree().create_timer(1.0).timeout
	_w.call("_on_solo_pressed")
	while not _w.get("_in_game") or _w.get("_traveling") or _w.call("current_location_id") != LocationCatalog.MAIN:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout  # let the town settle before going online
	Net.shutdown()
	Net.host_lost.connect(func() -> void: get_tree().quit(3))
	Net.connect_failed.connect(func(_why: String) -> void: get_tree().quit(4))
	var err := Net.join_game(_name)
	if err != "":
		print("FOLLOW_BOT %s: %s" % [_name, err])
		get_tree().quit(4)
		return
	await Net.session_started
	Net.arrive(LocationCatalog.MAIN, "BusArrival", false)
	_joined = true
	print("FOLLOW_BOT %s following" % _name)
	var tick := Timer.new()
	tick.wait_time = 0.3
	tick.autostart = true
	tick.timeout.connect(_follow)
	add_child(tick)
	var pilot := preload("res://tools/sled_pilot.gd").new()  # races on Sled Hill
	pilot.period = 1.35 + 0.12 * float(_slot)
	pilot.phase = float(_slot) * 1.3
	add_child(pilot)
	_fisher = preload("res://tools/fish_pilot.gd").new()  # fishes beside a fishing leader
	_fisher.offset = 0.7 * float(_slot) / 2.0
	add_child(_fisher)
	_snow = preload("res://tools/snow_pilot.gd").new()  # plays the snowball fight beside its leader
	_snow.team = ["coral", "teal", "teal", ""][mini(_slot / 2, 3)]
	add_child(_snow)
	_seat = preload("res://tools/seat_pilot.gd").new()  # sits beside a leader in the cinema or casino
	add_child(_seat)
	add_child(preload("res://tools/poker_pilot.gd").new())  # plays its hands once seated at the poker table


func _follow() -> void:
	if not _joined or not Net.is_online() or _w.get("_traveling"):
		return
	var entry := _leader_entry()
	if entry.is_empty():
		return
	var place := str(entry.get("location", ""))
	if place != "" and place != "home" and place != _w.call("current_location_id"):
		_goal = Vector3.INF
		_w.call("travel_to", place, DOORS.get(place, "BusArrival"))
		return
	_fisher.active = str(entry.get("fisher", "")) != ""
	if _fisher.active:
		return
	var lead: Node3D = (_w.get("_puppets") as Dictionary).get(int(entry["id"]))
	var me: Node3D = _w.get_node("Penguin")
	var map := (me.get("agent") as NavigationAgent3D).get_navigation_map()
	if _arrived != str(_w.call("current_location_id")):
		# every bot lands on the same door spot; stacked penguins shove one through the floor
		_arrived = str(_w.call("current_location_id"))
		var step := TAU * float(_slot) / 8.0
		me.global_position = NavigationServer3D.map_get_closest_point(map, me.global_position + Vector3(cos(step), 0.0, sin(step)) * 0.9) + Vector3(0, 0.1, 0)
	if lead == null or not is_instance_valid(lead) or not lead.visible:
		return
	var here := str(_w.call("current_location_id"))
	_seat.kit = "*" if here == "cafe" else here
	if here in ["casino", "cafe"]:  # a walk-in keeps walking; sit once the leader does
		_seat.active = lead.has_method("is_sitting") and bool(lead.call("is_sitting"))
	if here == "cinema":
		var room: Node = _w.get_node("LocationHost").get_child(0)
		_seat.active = lead.global_position.distance_to(room.get_meta("hall_center", Vector3(240, 0, 50))) < 14.0
	if _seat.active:
		_seat.near = lead.global_position
		return
	var arena := get_tree().get_first_node_in_group("snow_arena")
	_snow.active = _snow.team != "" and arena != null \
			and (arena.get("_field") as Rect2).grow(4.0).has_point(Vector2(lead.global_position.x, lead.global_position.z))
	if _snow.active:
		return
	var angle := TAU * float(_slot) / 8.0 + PI * 0.125
	var spot := lead.global_position + Vector3(cos(angle), 0.0, sin(angle)) * RADIUS
	# indoors a ring spot can fall behind a wall; stand on the nearest floor instead (a bot that
	# never moves never sends a pose, so the host would never see it)
	spot = NavigationServer3D.map_get_closest_point(map, spot)
	if me.global_position.distance_to(spot) < NEAR:
		return
	if _goal == Vector3.INF or _goal.distance_to(spot) > RETARGET:
		_goal = spot
		me.call("command_walk_to", spot)


func _leader_entry() -> Dictionary:
	for e in Net.roster():
		var id := int(e.get("id", 0))
		if id == Net.local_id():
			continue
		if (_leader == "" and id == 1) or (_leader != "" and str(e.get("name", "")) == _leader):
			return e
	return {}
