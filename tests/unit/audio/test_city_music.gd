extends RefCounted
## Unit tests of the music of the town (scripts/audio/city_music.gd): the levels as plain
## sums, and which loop plays when (the city's, a building's, none), stepped by hand without
## the town. That it really sounds in the game: tests/integration/world/test_city_music.gd.
##   tests/run_unit_tests.sh city_music

const CityMusic = preload("res://scripts/audio/city_music.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _music() -> CityMusic:
	var music := CityMusic.new()
	tree.root.add_child(music)
	return music


func test_level_is_softer_paused_and_under_a_jingle(test) -> void:
	test.check(CityMusic.level_target(false, false, 0) == CityMusic.VOLUME_DB, "spelend: het gewone niveau")
	test.check(CityMusic.level_target(true, false, 0) == CityMusic.PAUSED_DB, "gepauzeerd: zachter")
	test.check(CityMusic.level_target(true, true, 0) == CityMusic.VOLUME_DB, "gepauzeerd in de winkel: het gewone niveau")
	test.check(CityMusic.level_target(false, true, 0) == CityMusic.VOLUME_DB, "de winkel zonder pauze: het gewone niveau")
	test.check(is_equal_approx(CityMusic.level_target(false, false, 1), CityMusic.VOLUME_DB - CityMusic.JINGLE_DUCK_DB), "onder een deuntje: zachter")
	test.check(CityMusic.level_target(false, false, 3) == CityMusic.level_target(false, false, 1), "meer deuntjes: niet nog zachter")
	test.check(is_equal_approx(CityMusic.level_target(true, false, 2), CityMusic.PAUSED_DB - CityMusic.JINGLE_DUCK_DB), "gepauzeerd onder een deuntje: allebei")


func test_own_level_of_a_loop(test) -> void:
	test.check(CityMusic.own_level_db(CityMusic.CITY_MUSIC) == -CityMusic.CITY_LOOP_SOFTER_DB, "de spelmuziek: wat zachter")
	test.check(CityMusic.own_level_db("handelaar_loop.ogg") == 0.0, "de muziek van een gebouw: niet")
	test.check(CityMusic.own_level_db(CityMusic.MUZAK_PREFIX + "derrek.ogg") == -CityMusic.MUZAK_SOFTER_DB, "muzak van een supermarkt: nog zachter")


func test_loop_volume_fades_with_equal_power(test) -> void:
	var level := CityMusic.VOLUME_DB
	test.check(is_equal_approx(CityMusic.loop_volume_db(level, "handelaar_loop.ogg", 1.0), level), "ingefade: het muziekniveau")
	test.check(is_equal_approx(CityMusic.loop_volume_db(level, CityMusic.CITY_MUSIC, 1.0), level - CityMusic.CITY_LOOP_SOFTER_DB), "de spelmuziek: zachter")
	test.check(CityMusic.loop_volume_db(level, "handelaar_loop.ogg", 0.0) < -80.0, "niet ingefade: stil")
	# halfway two loops together are as loud as one: sin² + cos² = 1
	var coming := db_to_linear(CityMusic.loop_volume_db(0.0, "a.ogg", 0.5))
	var going := db_to_linear(CityMusic.loop_volume_db(0.0, "b.ogg", 0.5))
	test.check(absf(coming * coming + going * going - 1.0) < 0.001, "halverwege: samen even luid (%.3f)" % (coming * coming + going * going))
	test.check(CityMusic.loop_volume_db(level, "a.ogg", 2.0) == CityMusic.loop_volume_db(level, "a.ogg", 1.0), "boven 1: als 1")


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
