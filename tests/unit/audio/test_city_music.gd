extends RefCounted
## Unit tests of the music of the town (scripts/audio/city_music.gd, the behaviour): which
## loop plays when (the city's, a building's, none), the jingles and the level following
## them, stepped by hand without the town. The levels as plain sums:
## tests/unit/audio/test_city_music_rules.gd. That it really sounds in the game:
## tests/integration/world/test_city_music.gd.
##   tests/run_unit_tests.sh city_music

const CityMusic = preload("res://scripts/audio/city_music.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _music() -> CityMusic:
	var music := CityMusic.new()
	tree.root.add_child(music)
	return music


func test_ducking_counts_and_never_goes_below_zero(test) -> void:
	var music := _music()
	music.duck(true)
	music.duck(true)
	test.check(music.jingles_playing() == 2, "twee keer omlaag: twee")
	music.duck(false)
	music.duck(false)
	music.duck(false)
	test.check(music.jingles_playing() == 0, "vaker omhoog dan omlaag: nul, niet minder")
	music.free()


func test_the_level_follows_a_jingle(test) -> void:
	var music := _music()
	test.check(music.level_db() == CityMusic.VOLUME_DB, "aan het begin: het gewone niveau")
	music.duck(true)
	music._process(1.0)
	test.check(is_equal_approx(music.level_db(), CityMusic.VOLUME_DB - CityMusic.JINGLE_DUCK_DB), "na een seconde onder een deuntje: omlaag")
	music.duck(false)
	music._process(0.01)
	test.check(music.level_db() > CityMusic.VOLUME_DB - CityMusic.JINGLE_DUCK_DB and music.level_db() < CityMusic.VOLUME_DB, "daarna geleidelijk terug")
	music._process(1.0)
	test.check(is_equal_approx(music.level_db(), CityMusic.VOLUME_DB), "en weer op niveau")
	music.free()


func test_city_then_a_building_and_back(test) -> void:
	var music := _music()
	test.check(music.file() == "" and music.loop_count() == 0, "voor het kaartdeuntje: geen muziek")
	music.set_indoor("")
	test.check(music.file() == "", "naar buiten voor het deuntje klaar is: nog steeds geen muziek")
	music.play_city()
	test.check(music.file() == CityMusic.CITY_MUSIC and music.loop_count() == 1, "na het deuntje: de spelmuziek")
	test.check(music.weight_of(CityMusic.CITY_MUSIC) == 0.0, "die begint stil")
	music._process(CityMusic.FADE_IN)
	test.check(is_equal_approx(music.weight_of(CityMusic.CITY_MUSIC), 1.0), "en is na de fade helemaal in")
	music.set_indoor("handelaar_loop.ogg")
	test.check(music.indoor_file() == "handelaar_loop.ogg" and music.file() == "handelaar_loop.ogg", "naar binnen: de muziek van de handelaar")
	test.check(music.loop_count() == 2, "tijdens de overgang spelen er twee")
	music._process(CityMusic.INDOOR_MUSIC_FADE * 0.5)
	var coming := music.weight_of("handelaar_loop.ogg")
	var going := music.weight_of(CityMusic.CITY_MUSIC)
	test.check(absf(coming - 0.5) < 0.01 and absf(going - 0.5) < 0.01, "halverwege: allebei half (%.2f, %.2f)" % [coming, going])
	music._process(CityMusic.INDOOR_MUSIC_FADE)
	test.check(music.loop_count() == 1 and music.player_of(CityMusic.CITY_MUSIC) == null, "daarna alleen die van binnen")
	music.set_indoor("")
	test.check(music.indoor_file() == "" and music.file() == CityMusic.CITY_MUSIC, "weer buiten: de spelmuziek")
	music._process(CityMusic.INDOOR_MUSIC_FADE + 0.1)
	test.check(music.loop_count() == 1 and music.player_of(CityMusic.CITY_MUSIC) != null, "één speler over")
	music.free()


func test_stop_fades_everything_out_and_leaves_it_out(test) -> void:
	var music := _music()
	music.play_city()
	music._process(CityMusic.FADE_IN)
	music.stop(0.8)
	test.check(music.file() == "", "gestopt: geen lus meer aan de beurt")
	music._process(1.0)
	test.check(music.loop_count() == 0, "na de fade: niets speelt")
	music.set_indoor("")
	test.check(music.file() == "", "naar buiten na de dood: de spelmuziek komt niet terug")
	music.free()


func test_a_jingle_holds_the_music_down_while_it_plays(test) -> void:
	var music := _music()
	music.play_jingle("res://assets/audio/muziek/bestaat_niet.ogg", -4.0, "Niets")
	test.check(music.jingles_playing() == 0 and not music.has_node("Niets"), "zonder bestand: geen deuntje")
	music.play_jingle("res://assets/audio/muziek/deuntje_taak_klaar.ogg", -4.0, "TaakDeuntje")
	var jingle := music.get_node_or_null("TaakDeuntje") as AudioStreamPlayer
	test.check(jingle != null and jingle.volume_db == -4.0, "het deuntje speelt op zijn eigen volume")
	test.check(music.jingles_playing() == 1, "de muziek omlaag zolang het speelt")
	if jingle:
		jingle.finished.emit()
		test.check(music.jingles_playing() == 0, "afgelopen: de muziek weer omhoog")
	music.free()


func test_the_map_jingle_first_then_the_city_music(test) -> void:
	var music := _music()
	music.start_with_map_jingle()
	var jingle := music.get_node_or_null("KaartDeuntje") as AudioStreamPlayer
	if jingle == null:
		test.check(not ResourceLoader.exists(CityMusic.MAP_JINGLE) and music.file() == CityMusic.CITY_MUSIC, "zonder kaartdeuntje: meteen de spelmuziek")
	else:
		test.check(jingle.volume_db == CityMusic.MAP_JINGLE_VOLUME_DB and music.file() == "" and music.loop_count() == 0, "eerst het kaartdeuntje, nog geen spelmuziek")
		jingle.finished.emit()
		test.check(music.file() == CityMusic.CITY_MUSIC and music.loop_count() == 1, "na het deuntje: de spelmuziek")
	music.free()


func test_a_new_loop_joins_the_loudest_and_starts_silent(test) -> void:
	var music := _music()
	music.play_city()
	var city := music.player_of(CityMusic.CITY_MUSIC)
	test.check(city != null and city.name == "StadMuziek" and city.volume_db <= -80.0, "de speler van de spelmuziek begint stil")
	test.check(music.player_of("bestaat_niet.ogg") == null and music.weight_of("bestaat_niet.ogg") == 0.0, "een lus die niet speelt: geen speler, gewicht 0")
	music._process(CityMusic.FADE_IN)
	test.check(is_equal_approx(city.volume_db, CityMusic.VOLUME_DB - CityMusic.CITY_LOOP_SOFTER_DB), "ingefade: het muziekniveau, de spelmuziek wat zachter (%.1f)" % city.volume_db)
	music.set_indoor("bestaat_niet.ogg")
	test.check(music.file() == "bestaat_niet.ogg" and music.loop_count() == 1, "een lus zonder bestand: geen speler erbij")
	music.free()


func test_loud_while_paused_keeps_the_level(test) -> void:
	var music := _music()
	var was_paused := tree.paused
	tree.paused = true
	music._process(1.0)
	test.check(is_equal_approx(music.level_db(), CityMusic.PAUSED_DB), "gepauzeerd: zachter")
	music.loud_while_paused = func() -> bool: return true
	music._process(1.0)
	test.check(is_equal_approx(music.level_db(), CityMusic.VOLUME_DB), "gepauzeerd in de winkel: het gewone niveau")
	tree.paused = was_paused
	music.free()
