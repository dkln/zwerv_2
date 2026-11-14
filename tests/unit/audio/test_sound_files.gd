extends RefCounted
## Unit tests of where the sounds are (scripts/audio/sound_files.gd): every sound in the folder of
## its category, the babble per voice, and the generators' map (tools/megadrive/categorieen.py)
## the same as the game's.

const SoundFiles = preload("res://scripts/audio/sound_files.gd")


func test_every_sound_is_where_its_category_says(test) -> void:
	var names := SoundFiles.all_names()
	test.check(names.size() > 800, "alle geluiden gevonden (%d)" % names.size())
	var misplaced: Array[String] = []
	for sound_name in names:
		if not FileAccess.file_exists(SoundFiles.path_of(sound_name)):
			misplaced.append(sound_name)
	test.check(misplaced.is_empty(), "elk geluid in zijn map %s" % [misplaced.slice(0, 8)])
	var loose := DirAccess.get_files_at(SoundFiles.ROOT) as Array
	test.check(not loose.any(func(file_name: String) -> bool: return file_name.ends_with(".ogg")), "geen losse geluiden meer in de hoofdmap")


func test_categories(test) -> void:
	test.check(SoundFiles.category_of("brabbel_oude_man_blij_3") == "brabbel/oude_man", "brabbel per stem (oude man)")
	test.check(SoundFiles.category_of("brabbel_man_vraag_17") == "brabbel/man", "brabbel per stem (man)")
	test.check(SoundFiles.category_of("tram_bel") == "voertuigen" and SoundFiles.category_of("pijn_vrouw_2") == "mensen"
		and SoundFiles.category_of("ov_inchecken") == "ov" and SoundFiles.category_of("lift_ding") == "binnen", "de categorieën")
	var generators := FileAccess.get_file_as_string("res://tools/megadrive/categorieen.py")
	for entry: Array in SoundFiles.CATEGORIES:
		test.check(generators.contains('("%s", "%s")' % [entry[0], entry[1]]), "de generators kennen %s -> %s" % [entry[0], entry[1]])
