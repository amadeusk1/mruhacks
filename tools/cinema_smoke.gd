extends Node
## Cinema port smoke tests (one per ported piece; see Engine Specs/Cinema Sandbox Log).
##   Godot --path . res://tools/cinema_smoke.tscn -- --part=client
## Needs the gateway (services/cinema) on PENGLOO_CINEMA_URL and the host invite code in
## PENGLOO_CINEMA_TEST_CODE (set from the shell at run time; never stored).
## Prints CINEMA_SMOKE <part> PASS|FAIL and quits.

var part := "client"
var url := ""
var code := ""
var room: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.get_slice("=", 1)
	url = OS.get_environment("PENGLOO_CINEMA_URL")
	code = OS.get_environment("PENGLOO_CINEMA_TEST_CODE")
	room = (load("res://scenes/locations/cinema.tscn") as PackedScene).instantiate() as Node3D
	add_child(room)  # enter the cinema
	await get_tree().process_frame
	match part:
		"client":
			_client()
		"room":  # baseline: just enter and leave the cinema
			_done(true)
		_:
			_done(false, "unknown part")


func _done(ok: bool, why := "") -> void:
	print("CINEMA_SMOKE ", part, " ", "PASS" if ok else "FAIL", " ", why)
	room.queue_free()  # leave the cinema
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


# ---- 1. service client --------------------------------------------------------------------
func _client() -> void:
	var c := CinemaServiceClient.new()
	add_child(c)
	c.set_service("http://127.0.0.1:1/cinema/")
	c.health(func(dead_up: bool) -> void:
		if dead_up:
			_done(false, "dead service reported up"); return
		c.set_service(url)
		c.health(func(up: bool) -> void:
			if not up:
				_done(false, "service down at " + url); return
			c.login("Smoke", code, func(ok: bool, err: String) -> void:
				if not ok:
					_done(false, "login: " + err); return
				c.library("", func(films: Variant) -> void:
					c.state(func(st: Variant) -> void:
						var n: int = (films as Array).size() if films is Array else 0
						c.logout(func() -> void:
							_done(n > 0 and st is Dictionary and not c.signed_in, "films=%d state=%s" % [n, st is Dictionary])))))))
