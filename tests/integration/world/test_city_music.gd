extends "res://tests/integration/support/town_test.gd"
## The city music really plays (scripts/audio/city_music.gd, the node "Muziek" of the HUD): the map jingle (KaartDeuntje) starts once
## the map is there, and after it the loop of the town (StadMuziek) with a stream; one loop
## everywhere (spel_loop.ogg); into a building with its own music (the merchant's) and out
## again crossfades there and back. The town as the game starts it (the jingle only plays
## at the start), so a world of its own.
##   tests/run_integration_tests.sh city_music


static func world_options() -> Dictionary:
	return {"wake": false}


## The player of the city music, waited for (it starts after the jingle; null if it never
## does) and faded in.
func _city_music() -> AudioStreamPlayer:
	await wait_until(func() -> bool: return hud.music.get_node_or_null("StadMuziek") != null, 60.0)
	await wait_until(func() -> bool: return hud.music.weight_of(hud.music.file()) >= 1.0, 8.0)
	return hud.music.get_node_or_null("StadMuziek") as AudioStreamPlayer


## The map jingle starts first, and after it the city music, with a stream, playing.
func test_jingle_first_then_the_city_music(test) -> void:
	var jingle_seen := false
	var music: AudioStreamPlayer = null
	# by the clock, not by game time: the jingle plays in real seconds, however fast the
	# frames of the test run (--fixed-fps)
	var started := Time.get_ticks_msec()
	while music == null and Time.get_ticks_msec() - started < 30000:
		var jingle := hud.music.get_node_or_null("KaartDeuntje") as AudioStreamPlayer
		if jingle and not jingle_seen:
			jingle_seen = true
			print("deuntje speelt: %s, %.1f s" % [jingle.playing, jingle.stream.get_length()])
		await tree.process_frame
		music = hud.music.get_node_or_null("StadMuziek") as AudioStreamPlayer
	test.check(jingle_seen, "kaartdeuntje start")
	test.check(music != null, "stadsmuziek start na het deuntje")
	if music:
		print("stadsmuziek: %s (%s), speelt %s, %.1f dB" % [hud.music.file(),
			music.stream.resource_path if music.stream.resource_path != "" else "los bestand",
			music.playing, music.volume_db])
		test.check(music.stream != null and music.stream.get_length() > 10.0, "stadsmuziek heeft een stream")
		test.check(music.playing, "stadsmuziek speelt")


## Faded in, the music is at the level of playing (or of the pause, if the game is held),
## it is the one loop of the game, and that loop sounds CITY_LOOP_SOFTER_DB softer.
func test_the_game_loop_plays_at_its_level(test) -> void:
	var music := await _city_music()
	test.check(music != null, "de stadsmuziek speelt")
	if music == null:
		return
	print("niveau stadsmuziek: %.1f dB" % hud.music.level_db())
	var expected: float = hud.music.PAUSED_DB if tree.paused else hud.music.VOLUME_DB
	# under a jingle (a mission announced at the start) the music is held down
	if hud.music.jingles_playing() > 0:
		expected -= hud.music.JINGLE_DUCK_DB
	test.check(absf(hud.music.level_db() - expected) < 0.5, "stadsmuziek op %.0f dB (%s%s)" % [expected,
		"gepauzeerd" if tree.paused else "spelend", ", onder een deuntje" if hud.music.jingles_playing() > 0 else ""])
	test.check(hud.music.file() == hud.music.CITY_MUSIC, "de spelmuziek (%s) speelt" % hud.music.CITY_MUSIC)
	var outdoor: AudioStreamPlayer = hud.music.player_of(hud.music.file())
	if outdoor:
		print("spelmuziek op %.1f dB" % outdoor.volume_db)
		test.check(absf(outdoor.volume_db - (hud.music.level_db() - hud.music.CITY_LOOP_SOFTER_DB)) < 0.5,
			"de spelmuziek %.0f dB zachter dan het muziekniveau" % hud.music.CITY_LOOP_SOFTER_DB)


## Into a building with music of its own (the merchant's) the music crossfades to it, at
## the usual level; out again it fades back to the game's loop, one player left.
func test_indoor_music_crossfades_in_and_back(test) -> void:
	var music := await _city_music()
	test.check(music != null, "de stadsmuziek speelt")
	if music == null:
		return
	var first_file: String = hud.music.file()
	hud.set_indoor_music("handelaar_loop.ogg")
	await seconds(hud.music.INDOOR_MUSIC_FADE + 0.5)
	test.check(hud.music.file() == "handelaar_loop.ogg", "binnen: de muziek van de handelaar")
	var indoor: AudioStreamPlayer = hud.music.player_of("handelaar_loop.ogg")
	test.check(indoor != null and absf(indoor.volume_db - hud.music.level_db()) < 0.5, "de handelaarsmuziek op het gewone niveau")
	hud.set_indoor_music("")
	await seconds(hud.music.INDOOR_MUSIC_FADE + 0.5)
	test.check(hud.music.file() == first_file and hud.music.loop_count() == 1, "weer buiten: de spelmuziek, één speler")
	var still: AudioStreamPlayer = hud.music.player_of(first_file)
	test.check(still != null and still.playing, "de spelmuziek speelt door")
