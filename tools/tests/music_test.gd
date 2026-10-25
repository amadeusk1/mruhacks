extends SceneTree
## Headless check of the activity music bed: which place plays which track, that mp3s loop,
## and that leaving crossfades back to a single player.
##   Godot --headless --path . --script res://tools/tests/music_test.gd

var fails := 0
var _music: Node
var _net: Node
var Bed: GDScript


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	# Resolve the autoload after it has compiled with the other singletons. Preloading
	# music.gd from this script runs before those names exist.
	await process_frame
	_music = root.get_node_or_null("Music")
	_net = root.get_node_or_null("Net")
	if _music == null or _music.get_script() == null or _net == null:
		print("FAIL music autoload did not load")
		quit(1)
		return
	Bed = _music.get_script()
	_catalog()
	_areas()
	_picks()
	await _playback()
	print("MUSIC_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _catalog() -> void:
	for place in Bed.SETS:
		var songs: Array = Bed.SETS[place]
		check(not songs.is_empty(), "empty set %s" % place)
		for song in songs:
			var path := "res://audio/music/" + str(song)
			check(FileAccess.file_exists(path), "missing " + path)
			if str(song).ends_with(".mp3"):
				var stream := load(path) as AudioStreamMP3
				if stream == null:
					check(false, "load %s" % song)
					continue
				check(stream.get_length() > 20.0, "mp3 length %s" % song)
				check(stream.loop, "import loop %s" % song)
				Bed.prepare(stream)
				check(stream.loop, "prepare loop %s" % song)
	check(Bed.SETS["games"][0] == "minigame.mp3", "minigame placeholder replaced")
	check(not (Bed.SETS["games"] as Array).has("minigame"), "old ogg name left the games set")
	check(Bed.SETS["basketball"][0] == "basketball.mp3" and (Bed.SETS["basketball"] as Array).has("basketball_2.mp3"), "both basketball tracks")
	check(not Bed.SETS.has("home"), "igloo bed is not in yet")


func _areas() -> void:
	check(Bed.area_for(false, "town", "basketball") == "title", "menu stays on the title")
	check(Bed.area_for(true, "", "") == "town", "no location yet is town")
	check(Bed.area_for(true, "town", "") == "town", "open town")
	check(Bed.area_for(true, "home", "") == "town", "igloo keeps the town bed")
	check(Bed.area_for(true, "home", "fishing") == "town", "a zone does not follow you into a house")
	check(Bed.area_for(true, "plaza", "") == "town", "shops keep the town bed")
	check(Bed.area_for(true, "cafe", "") == "cafe", "cafe")
	check(Bed.area_for(true, "cinema", "") == "cinema", "cinema")
	check(Bed.area_for(true, "casino", "") == "casino", "casino")
	check(Bed.area_for(true, "arcade", "") == "arcade", "arcade")
	check(Bed.area_for(true, "sled_hill", "") == "sled", "sled hill")
	check(Bed.area_for(true, "town", "basketball") == "basketball", "court zone")
	check(Bed.area_for(true, "town", "fishing") == "fishing", "fishing zone")
	check(Bed.area_for(true, "town", "sketch") == "sketch", "sketch zone")
	check(Bed.area_for(true, "town", "games") == "games", "snowball arena uses the minigame bed")
	check(Bed.area_for(true, "court", "") == "basketball", "a court location")
	check(Bed.area_for(true, "cafe", "fishing") == "cafe", "a room wins over a town zone")
	check(Bed.area_for(true, "snowball_arena", "") == "games", "future snowball location")


func _picks() -> void:
	var both: Array = Bed.SETS["sled"]
	check(Bed.pick_song(both, "", 0) == "sled_race.mp3", "roll 0 is the default")
	check(Bed.pick_song(both, "", 1) == "sled_race_2.mp3", "roll 1 is the alternate")
	check(Bed.pick_song(both, "sled_race.mp3", 0) == "sled_race_2.mp3", "does not repeat")
	check(Bed.pick_song(Bed.SETS["title"], "Pengloo Party.ogg", 4) == "Pengloo Party.ogg", "a one-song set replays")
	var seen := {}
	for i in 8:
		seen[Bed.pick_song(Bed.SETS["arcade"], "", i)] = true
	check(seen.size() == 2, "arcade alternates across rolls")


func _playback() -> void:
	_music = root.get_node("Music")
	_net = root.get_node("Net")
	# process_frame is emitted before Node._process, so one extra frame is the first
	# one where the autoload has actually published the title bed.
	await process_frame
	check(_music.area == "title", "title before a session, got %s" % _music.area)
	check(_music._current == "Pengloo Party.ogg" and _music._a.playing, "title track playing (%s)" % _music._current)
	_music.start()
	var player := Node3D.new()
	player.name = "MusicTestPenguin"
	player.add_to_group("local_player")
	root.add_child(player)
	_net._place_hidden = false
	await _goto("cafe", "")
	check(_music.area == "cafe", "entered cafe")
	check(str(_music._current).begins_with("cafe"), "cafe track %s" % _music._current)
	check(_looping(), "cafe stream loops")
	var cafe_song := str(_music._current)
	await process_frame
	await process_frame
	check(_music._current == cafe_song, "a looping bed does not rotate every frame")
	# Hidden door trip keeps the cafe bed until the next place is published.
	_net._place_hidden = true
	_net._place_location = "town"
	await _frames(2)
	check(_music.area == "cafe", "hold the bed while presence is hidden")
	_net._place_hidden = false
	await _goto("town", "")
	check(_music.area == "town" and str(_music._current).ends_with(".ogg"), "back to town music (%s)" % _music._current)
	check(_music._b.playing, "previous bed is still fading")
	await create_timer(Bed.FADE_S + 0.35).timeout
	check(not _music._b.playing and _music._a.playing, "fade ends on one player")
	await _goto("cinema", "")
	check(_music.area == "cinema" and str(_music._current).begins_with("cinema"), "cinema %s" % _music._current)
	await _goto("casino", "")
	check(_music.area == "casino" and str(_music._current).begins_with("casino"), "casino %s" % _music._current)
	check(not str(_music._current).ends_with(".ogg"), "casino no longer uses the minigame ogg")
	await _goto("arcade", "")
	check(str(_music._current).begins_with("arcade") and _looping(), "arcade %s" % _music._current)
	await _goto("sled_hill", "")
	check(_music.area == "sled" and str(_music._current).begins_with("sled_race"), "sled %s" % _music._current)
	await _goto("home", "")
	check(_music.area == "town" and str(_music._current).ends_with(".ogg"), "home stays on town (%s)" % _music._current)
	_net._court_on = true
	_net._court_box = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	player.position = Vector3.ZERO
	await _goto("town", "")
	check(_music.area == "basketball" and str(_music._current).begins_with("basketball"), "court %s" % _music._current)
	check((Bed.SETS["basketball"] as Array).has(_music._current), "court picked a basketball file")
	player.position = Vector3(40, 0, 40)
	await create_timer(0.25).timeout
	check(_music.area == "basketball", "court exit waits before dropping the bed")
	await create_timer(Bed.ZONE_EXIT_S).timeout
	check(_music.area == "town", "off the court returns to town")
	_net._court_on = false
	var rail := Node3D.new()
	rail.add_to_group("fish_spot")
	root.add_child(rail)
	rail.position = Vector3(80, 0, 80)
	player.position = Vector3(82, 0, 81)
	await _frames(2)
	check(_music.area == "fishing" and str(_music._current).begins_with("fishing"), "fishing dock %s" % _music._current)
	player.position = Vector3(0, 0, 0)
	await create_timer(Bed.ZONE_EXIT_S + 0.25).timeout
	check(_music.area == "town", "leaving the dock returns to town")
	rail.queue_free()
	var pavilion := Node3D.new()
	pavilion.name = "SketchClub"
	pavilion.add_to_group("sketch_pavilion")
	root.add_child(pavilion)
	pavilion.position = Vector3.ZERO
	player.position = Vector3.ZERO
	await _frames(2)
	check(_music.area == "sketch" and str(_music._current).begins_with("sketch_club"), "pavilion %s" % _music._current)
	pavilion.queue_free()
	_music._pavilion = null
	player.position = Vector3(0, 0, 30)
	await create_timer(Bed.ZONE_EXIT_S + 0.25).timeout
	_net._snow_on = true
	_net._snow_area = Rect2(Vector2(-2, 28), Vector2(8, 8))
	await _frames(2)
	check(_music.area == "games" and str(_music._current).begins_with("minigame"), "arena %s" % _music._current)
	_net._snow_on = false
	_music.play_title()
	await _frames(2)
	check(_music.area == "title" and _music._current == "Pengloo Party.ogg", "play_title restores the menu")


func _goto(location: String, _zone: String) -> void:
	_net._place_hidden = false
	_net._place_location = location
	await _frames(2)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _looping() -> bool:
	return _music._a.stream is AudioStreamMP3 and (_music._a.stream as AudioStreamMP3).loop
