extends RefCounted
## Unit tests of the logic of the music of the town (scripts/audio/city_music_rules.gd): the
## levels and the steps of the fades as plain sums, without players or a tree. Which loop
## plays when: tests/unit/audio/test_city_music.gd.
##   tests/run_unit_tests.sh city_music_rules

const CityMusicRules = preload("res://scripts/audio/city_music_rules.gd")


func test_level_is_softer_paused_and_under_a_jingle(test) -> void:
	test.check(CityMusicRules.level_target(false, false, 0) == CityMusicRules.VOLUME_DB, "spelend: het gewone niveau")
	test.check(CityMusicRules.level_target(true, false, 0) == CityMusicRules.PAUSED_DB, "gepauzeerd: zachter")
	test.check(CityMusicRules.level_target(true, true, 0) == CityMusicRules.VOLUME_DB, "gepauzeerd in de winkel: het gewone niveau")
	test.check(CityMusicRules.level_target(false, true, 0) == CityMusicRules.VOLUME_DB, "de winkel zonder pauze: het gewone niveau")
	test.check(is_equal_approx(CityMusicRules.level_target(false, false, 1), CityMusicRules.VOLUME_DB - CityMusicRules.JINGLE_DUCK_DB), "onder een deuntje: zachter")
	test.check(CityMusicRules.level_target(false, false, 3) == CityMusicRules.level_target(false, false, 1), "meer deuntjes: niet nog zachter")
	test.check(is_equal_approx(CityMusicRules.level_target(true, false, 2), CityMusicRules.PAUSED_DB - CityMusicRules.JINGLE_DUCK_DB), "gepauzeerd onder een deuntje: allebei")


func test_level_moves_to_its_target_at_a_fixed_speed(test) -> void:
	var step := CityMusicRules.LEVEL_SPEED * 0.1
	test.check(is_equal_approx(CityMusicRules.next_level_db(-11.0, -17.0, 0.1), -11.0 - step), "omlaag: een stap per tijd")
	test.check(is_equal_approx(CityMusicRules.next_level_db(-17.0, -11.0, 0.1), -17.0 + step), "omhoog: ook")
	test.check(CityMusicRules.next_level_db(-11.0, -17.0, 10.0) == -17.0, "niet voorbij het doel")
	test.check(CityMusicRules.next_level_db(-11.0, -11.0, 1.0) == -11.0, "op het doel: het blijft")


func test_own_level_of_a_loop(test) -> void:
	test.check(CityMusicRules.own_level_db(CityMusicRules.CITY_MUSIC) == -CityMusicRules.CITY_LOOP_SOFTER_DB, "de spelmuziek: wat zachter")
	test.check(CityMusicRules.own_level_db("handelaar_loop.ogg") == 0.0, "de muziek van een gebouw: niet")
	test.check(CityMusicRules.own_level_db(CityMusicRules.MUZAK_PREFIX + "derrek.ogg") == -CityMusicRules.MUZAK_SOFTER_DB, "muzak van een supermarkt: nog zachter")


func test_loop_volume_fades_with_equal_power(test) -> void:
	var level := CityMusicRules.VOLUME_DB
	test.check(is_equal_approx(CityMusicRules.loop_volume_db(level, "handelaar_loop.ogg", 1.0), level), "ingefade: het muziekniveau")
	test.check(is_equal_approx(CityMusicRules.loop_volume_db(level, CityMusicRules.CITY_MUSIC, 1.0), level - CityMusicRules.CITY_LOOP_SOFTER_DB), "de spelmuziek: zachter")
	test.check(CityMusicRules.loop_volume_db(level, "handelaar_loop.ogg", 0.0) < CityMusicRules.SILENT_DB, "niet ingefade: stil")
	# halfway two loops together are as loud as one: sin² + cos² = 1
	var coming := db_to_linear(CityMusicRules.loop_volume_db(0.0, "a.ogg", 0.5))
	var going := db_to_linear(CityMusicRules.loop_volume_db(0.0, "b.ogg", 0.5))
	test.check(absf(coming * coming + going * going - 1.0) < 0.001, "halverwege: samen even luid (%.3f)" % (coming * coming + going * going))
	test.check(CityMusicRules.loop_volume_db(level, "a.ogg", 2.0) == CityMusicRules.loop_volume_db(level, "a.ogg", 1.0), "boven 1: als 1")
	test.check(CityMusicRules.loop_volume_db(level, "a.ogg", -1.0) == CityMusicRules.loop_volume_db(level, "a.ogg", 0.0), "onder 0: als 0")


func test_music_keeps_its_pitch_in_slow_motion(test) -> void:
	test.check(CityMusicRules.music_pitch(1.0) == 1.0, "gewone snelheid: gewone toonhoogte")
	test.check(is_equal_approx(CityMusicRules.music_pitch(0.25), 4.0), "een kwart zo snel: vier keer zo hoog gespeeld, dus weer gewoon")
	test.check(is_equal_approx(CityMusicRules.music_pitch(0.0), 100.0), "stilstand: begrensd, geen deling door nul")


func test_jingle_count_never_goes_below_zero(test) -> void:
	test.check(CityMusicRules.jingles_after(0, true) == 1 and CityMusicRules.jingles_after(1, true) == 2, "een erbij")
	test.check(CityMusicRules.jingles_after(2, false) == 1, "een eraf")
	test.check(CityMusicRules.jingles_after(0, false) == 0, "nooit onder nul")


func test_fade_is_never_shorter_than_the_shortest(test) -> void:
	test.check(CityMusicRules.fade_seconds(1.2) == 1.2, "een gewone fade: zo lang als gevraagd")
	test.check(CityMusicRules.fade_seconds(0.0) == CityMusicRules.SHORTEST_FADE, "geen tijd: de kortste")
	test.check(CityMusicRules.fade_seconds(-3.0) == CityMusicRules.SHORTEST_FADE, "negatief: ook")


func test_weight_moves_along_the_fade(test) -> void:
	test.check(is_equal_approx(CityMusicRules.next_weight(0.0, true, 0.6, 1.2), 0.5), "erin: halverwege na de halve tijd")
	test.check(is_equal_approx(CityMusicRules.next_weight(1.0, false, 0.6, 1.2), 0.5), "eruit: ook")
	test.check(CityMusicRules.next_weight(0.9, true, 5.0, 1.2) == 1.0, "niet voorbij 1")
	test.check(CityMusicRules.next_weight(0.1, false, 5.0, 1.2) == 0.0, "niet onder 0")


func test_a_loop_is_gone_when_faded_out(test) -> void:
	test.check(CityMusicRules.is_faded_out(0.0, false), "uitgefade: weg")
	test.check(not CityMusicRules.is_faded_out(0.2, false), "nog te horen: nog niet")
	test.check(not CityMusicRules.is_faded_out(0.0, true), "de lus die erin komt begint op nul en blijft")


func test_loudest_loop_of_the_ones_playing(test) -> void:
	var weights := {"a.ogg": 0.3, "b.ogg": 0.7, "c.ogg": 0.9}
	test.check(CityMusicRules.loudest_loop(weights, ["a.ogg", "b.ogg", "c.ogg"]) == "c.ogg", "de luidste")
	test.check(CityMusicRules.loudest_loop(weights, ["a.ogg", "b.ogg"]) == "b.ogg", "een lus die niet speelt telt niet")
	test.check(CityMusicRules.loudest_loop({"a.ogg": 0.5, "b.ogg": 0.5}, ["a.ogg", "b.ogg"]) == "a.ogg", "even luid: de eerste")
	test.check(CityMusicRules.loudest_loop({"a.ogg": 0.0}, ["a.ogg"]) == "a.ogg", "ook een lus die nog stil is")
	test.check(CityMusicRules.loudest_loop(weights, []) == "" and CityMusicRules.loudest_loop({}, []) == "", "niets speelt: geen")


func test_a_new_loop_starts_at_the_same_point_in_the_bar(test) -> void:
	test.check(is_equal_approx(CityMusicRules.start_position(12.5, 30.0), 12.5), "binnen de lus: hetzelfde punt")
	test.check(is_equal_approx(CityMusicRules.start_position(42.5, 30.0), 12.5), "voorbij het einde: rond")
	test.check(CityMusicRules.start_position(0.0, 30.0) == 0.0, "niets speelt: vooraan")
	test.check(CityMusicRules.start_position(5.0, 0.0) < 0.01, "een lus zonder lengte: geen deling door nul")
