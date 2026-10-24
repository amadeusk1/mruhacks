extends Node
## Two-instance seating test over real ENet on localhost (host first, then client):
##   Godot --path . res://tools/seating_mp.tscn -- --net-host --net-name=Snowdrop --out=/abs/dir/
##   Godot --path . res://tools/seating_mp.tscn -- --net-join --net-name=Milo --out=/abs/dir/
## Host sits on the plaza bench nearest the spawn; the client aims at the SAME seat, must be given
## the free one beside it (friends side by side), walks over and sits; both see the other seated.
## Prints SEAT_MP lines and exits 0 on pass.

var out := "/tmp/"
var host := false
var w: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a == "--net-host": host = true
	w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	get_tree().create_timer(240.0).timeout.connect(func() -> void: _done(false, "TIMEOUT"))
	var seats: Array = []
	while seats.size() < 10:  # session up and the town built
		await get_tree().create_timer(1.0).timeout
		seats = get_tree().get_nodes_in_group("seats")
	await get_tree().create_timer(2.0).timeout
	var kits := {}
	for s in seats:
		kits[s.kit] = kits.get(s.kit, 0) + 1
	print("SEAT_MP seats in town: %d %s" % [seats.size(), kits])
	var p: Node3D = w.get_node("Penguin")
	get_viewport().gui_release_focus()  # the chat box can hold focus in an unattended run (blocks play)
	print("SEAT_MP locks travel=%s typing=%s" % [p.get("_input_locked"), p.get("_typing_locked")])
	p.call("set_typing_locked", false)
	var benches := seats.filter(func(s): return s.name.begins_with("bench") or s.get_parent().name.begins_with("bench"))
	benches.sort_custom(func(a, b): return a.seat_point.distance_to(p.global_position) < b.seat_point.distance_to(p.global_position))
	var target: SeatSpot = benches[0]  # same choice on both instances (same spawn, same layout)
	print("SEAT_MP target %s at %s" % [target.name, target.seat_point])
	if not host:
		await get_tree().create_timer(4.0).timeout  # host is seated by now
		var tname := target.name
		target = get_tree().get_nodes_in_group("seats").filter(func(s): return s.name == tname)[0]  # the room may have rebuilt
		if Net.claim_bench(target.bench_key()):
			_done(false, "client claimed the host's seat")
			return
	var seat := SeatSpot.pick(get_tree(), target.seat_point, 0.7)
	if seat == null or (not host and seat == target):
		_done(false, "no free seat picked")
		return
	p.set("_pending_bench", seat)
	p.call("_begin_click", p.call("_closest_nav_point", seat.seat_point))
	print("SEAT_MP walking %.1f m to %s" % [p.global_position.distance_to(seat.seat_point), seat.name])
	var sname := seat.name
	for i in 900:
		await get_tree().physics_frame
		p.call("set_typing_locked", false)  # unattended window: a focused HUD button re-locks typing
		if not is_instance_valid(seat):  # the room rebuilt (the join can re-enter town): aim again
			seat = get_tree().get_nodes_in_group("seats").filter(func(s): return s.name == sname)[0]
			p.set("_pending_bench", seat)
			p.call("_begin_click", p.call("_closest_nav_point", seat.seat_point))
		if p.call("is_sitting"):
			break
	if not p.call("is_sitting") or p.call("current_bench") != seat:
		_done(false, "did not sit at %s (still %.1f m away, sitting=%s)" % [seat.name, p.global_position.distance_to(seat.seat_point), p.call("is_sitting")])
		return
	print("SEAT_MP %s sat at %s" % [Net.local_profile()["name"], seat.name])
	var seen := false
	var spot := seat.seat_point
	var yaw := seat.face_yaw
	for i in 120:  # until the friend is seen seated beside me
		await get_tree().create_timer(1.0).timeout
		var others := get_tree().get_nodes_in_group("remote_player").filter(func(n): return n.visible)
		seen = others.any(func(n): return n.call("is_sitting") and n.global_position.distance_to(spot) < 1.5)
		if i % 10 == 0:
			print("SEAT_MP %s sees %s" % [Net.local_profile()["name"], others.map(func(n): return "%s sit=%s d=%.1f" % [n.name, n.call("is_sitting"), n.global_position.distance_to(spot)])])
		if seen:
			break
	await get_tree().create_timer(2.0).timeout  # sit clips settle
	var cam: Camera3D = w.get_node("CameraRig/Camera3D")
	(w.get_node("CameraRig") as Node3D).set_process(false)
	for c in w.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	cam.global_position = spot + fwd * 3.2 + Vector3(0, 1.6, 0)
	cam.look_at(spot + Vector3(0, 0.4, 0), Vector3.UP)
	for f in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%sseating_bench_%s.png" % [out, "host" if host else "client"]
	get_viewport().get_texture().get_image().save_png(path)
	if host:
		await get_tree().create_timer(10.0).timeout  # keep the server up while the client finishes
	_done(seen, "other penguin seated beside me: %s (%s)" % [seen, path])


func _done(ok: bool, why: String) -> void:
	print("SEAT_MP %s %s: %s" % ["host" if host else "client", "PASS" if ok else "FAIL", why])
	get_tree().quit(0 if ok else 1)
