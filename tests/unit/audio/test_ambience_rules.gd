extends RefCounted
## Unit tests of the logic of the background sound of a place
## (scripts/audio/ambience_rules.gd): which loop, how loud, the name of its player and where
## it starts. The players and the crossfade: tests/unit/audio/test_ambience.gd.
##   tests/run_unit_tests.sh ambience

const AmbienceRules = preload("res://scripts/audio/ambience_rules.gd")


func test_every_place_has_its_loop(test) -> void:
	test.check(AmbienceRules.file_of("straat") == "straat_loop.ogg", "de straat heeft zijn lus")
	test.check(AmbienceRules.file_of("station") == "station_loop.ogg", "het station heeft zijn lus")
	test.check(AmbienceRules.file_of("winkel") == "winkel_loop.ogg", "de winkel heeft zijn lus")
	for place: String in AmbienceRules.PLACES:
		test.check(FileAccess.file_exists(AmbienceRules.path_of(place)), "de lus van %s bestaat" % place)


func test_nowhere_and_unknown_places_have_no_sound(test) -> void:
	test.check(AmbienceRules.file_of("") == "" and AmbienceRules.file_of("maan") == "", "geen plek en een onbekende plek: geen bestand")
	test.check(AmbienceRules.path_of("") == "" and AmbienceRules.path_of("maan") == "", "en dus geen pad")
	test.check(not AmbienceRules.has_sound("") and not AmbienceRules.has_sound("maan"), "en geen geluid")
	test.check(AmbienceRules.has_sound("straat"), "de straat wel")


func test_the_path_is_in_the_folder(test) -> void:
	test.check(AmbienceRules.path_of("winkel") == "res://assets/audio/omgeving/winkel_loop.ogg", "het pad is de map en het bestand")


func test_levels(test) -> void:
	test.check(AmbienceRules.volume_db_of("straat") == -16.0, "de straat op -16 dB")
	test.check(AmbienceRules.volume_db_of("station") == -13.0, "het station op -13 dB")
	test.check(AmbienceRules.volume_db_of("winkel") == -15.0, "de winkel op -15 dB")
	test.check(AmbienceRules.volume_db_of("maan") == AmbienceRules.SILENT_DB, "een onbekende plek is stil")
	for place: String in AmbienceRules.PLACES:
		test.check(AmbienceRules.volume_db_of(place) > AmbienceRules.SILENT_DB and AmbienceRules.volume_db_of(place) < 0.0,
				"%s klinkt zacht maar hoorbaar" % place)


func test_player_name(test) -> void:
	test.check(AmbienceRules.player_name("station") == "Omgeving_station", "de speler heet naar zijn plek")


func test_start_position(test) -> void:
	test.check(AmbienceRules.start_position(0.0, 30.0) == 0.0, "trekking 0: aan het begin")
	test.check(is_equal_approx(AmbienceRules.start_position(0.5, 30.0), 15.0), "trekking een half: halverwege")
	test.check(is_equal_approx(AmbienceRules.start_position(1.0, 30.0), 30.0), "trekking 1: aan het eind")
	test.check(AmbienceRules.start_position(0.7, 0.0) == 0.0, "een lus zonder lengte: 0")
