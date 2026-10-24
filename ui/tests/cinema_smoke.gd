extends Node
## Cinema smoke test: enter the cinema, open/close the lobby kiosk, the seat HUD and the
## close-up player 5 times, then leave. Prints CINEMA_SMOKE PASS (and quits) or crashes trying.
##   Godot --path . res://ui/tests/cinema_smoke.tscn          (windowed: exercises WRY too)
##   PENGLOO_CINEMA_URL=http://127.0.0.1:1/cinema/ ...        (service down -> Demo fallback)


func _ready() -> void:
	var room := (load("res://scenes/locations/cinema.tscn") as PackedScene).instantiate() as Node3D
	add_child(room)
	for i in 3:
		await get_tree().process_frame
	var seat: SeatSpot = null
	var kiosk: Node = room.find_child("CinemaLibraryKiosk", true, false)
	for n in room.get_children():
		if n is SeatSpot and n.kit == "cinema":
			seat = n
			break
	assert(seat != null and kiosk != null, "cinema seat/kiosk missing")
	var p := (load("res://scenes/penguin.tscn") as PackedScene).instantiate()
	add_child(p)
	await get_tree().process_frame
	for round in 5:
		Activities.request("cinema", kiosk, p)
		await _wait(1.0)
		var k: Control = CinemaSession.get("_kiosk")
		assert(is_instance_valid(k), "kiosk did not open")
		k.call("close")
		await _wait(0.3)
		p.call("sit_down", seat, seat.seat_point, seat.face_yaw, seat.seat_point + Vector3(0, 0, 1))
		p.call("set_seat_clip", "cinema")
		Activities.request("cinema", seat, p)
		await _wait(0.6)
		var hud: Control = CinemaSession.get("_hud")
		assert(is_instance_valid(hud), "seat HUD did not open")
		hud.call("_toggle_popcorn", true)
		hud.call("_save_seat")
		var close_up: Control = CinemaSession.PLAYER.new()
		close_up.set("url", CinemaSession.PLAYER.service_url())
		UIRouter.push(close_up)
		await _wait(1.5)
		close_up.call("close")
		await _wait(0.3)
		hud.call("close")
		await _wait(0.3)
		print("CINEMA_SMOKE round ", round + 1, " ok (source=", CinemaSession.source.status, ")")
	room.queue_free()
	p.queue_free()
	await _wait(0.5)
	print("CINEMA_SMOKE PASS")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
