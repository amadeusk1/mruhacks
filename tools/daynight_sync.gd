extends Node

## Two-client check that the day/night clock follows the host, not each machine's own clock.
## Start a host (e.g. a dedicated one: `-- --net-host --dedicated --net-port=7790`), then run this
## twice with different fake clock errors:
##   Godot --headless --path . res://tools/daynight_sync.tscn -- --net-port=7790 --clock-skew=300
##   Godot --headless --path . res://tools/daynight_sync.tscn -- --net-port=7790 --clock-skew=-500
## Each prints DAYNIGHT_PASS when its world time matches the host's to within 0.1 s.

func _ready() -> void:
	var skewed := Net.world_time()  # before syncing: this machine's (wrong) clock
	assert(Net.join_game("Clock") == "")
	await Net.session_started
	await get_tree().create_timer(1.5).timeout
	var err := Net.world_time() - Time.get_unix_time_from_system()  # host and clients share this machine
	var h := LivingTown.hour()
	print("DAYNIGHT skew_before=%.1f err_after=%.3f hour=%.4f phase=%s" % [skewed - Time.get_unix_time_from_system(), err, h, LivingTown.phase_name(h)])
	if absf(err) < 0.1:
		print("DAYNIGHT_PASS")
	else:
		print("DAYNIGHT_FAIL")
	Net.shutdown()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
