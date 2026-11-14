extends RefCounted
## Unit tests of the logic of the babble (scripts/audio/babble_rules.gd): voices and moods,
## which variant plays for a draw, the names, the pitch, the word of a sound. The draws and
## the players: tests/unit/audio/test_babble.gd.
##   tests/run_unit_tests.sh babble

const BabbleRules = preload("res://scripts/audio/babble_rules.gd")
const SoundFiles = preload("res://scripts/audio/sound_files.gd")


func test_voices_and_moods(test) -> void:
	for voice: String in BabbleRules.VOICES:
		test.check(BabbleRules.voice_name(voice) == voice, "%s is een stem" % voice)
	test.check(BabbleRules.voice_name("rasperig") == "rasperig", "een eigen stem blijft zichzelf")
	test.check(BabbleRules.voice_name("robot") == "man" and BabbleRules.voice_name("") == "man", "een onbekende stem wordt man")
	for mood: String in BabbleRules.MOODS:
		test.check(BabbleRules.mood_name(mood) == mood, "%s is een stemming" % mood)
	test.check(BabbleRules.mood_name("verveeld") == "neutraal" and BabbleRules.mood_name("") == "neutraal", "een onbekende stemming wordt neutraal")
	test.check(not BabbleRules.OWN_VOICES.any(func(voice: String) -> bool: return voice in BabbleRules.VOICES), "eigen stemmen worden niet uitgedeeld")


func test_recent_key(test) -> void:
	test.check(BabbleRules.recent_key("vrouw", "blij") == "vrouw/blij", "stem en stemming")
	test.check(BabbleRules.recent_key("robot", "verveeld") == "man/neutraal", "onbekend valt samen met man, neutraal")
	test.check(BabbleRules.recent_key("vrouw", "blij") != BabbleRules.recent_key("vrouw", "boos"), "elke stemming zijn eigen geheugen")


func test_free_variant(test) -> void:
	test.check(BabbleRules.free_variant(5, []) == 5, "niets gespeeld: de trekking zelf")
	test.check(BabbleRules.free_variant(5, [1, 2, 3]) == 5, "niet bij de laatste: de trekking zelf")
	test.check(BabbleRules.free_variant(5, [5]) == 6, "net gespeeld: de volgende")
	test.check(BabbleRules.free_variant(5, [7, 5, 6]) == 8, "ook de volgende gespeeld: verder")
	test.check(BabbleRules.free_variant(BabbleRules.VARIANTS, [BabbleRules.VARIANTS]) == 1, "na de laatste komt de eerste")
	test.check(BabbleRules.free_variant(BabbleRules.VARIANTS, [BabbleRules.VARIANTS, 1, 2]) == 3, "en rond verder")
	for drawn in range(1, BabbleRules.VARIANTS + 1):
		var variant := BabbleRules.free_variant(drawn, [30, 31, 32, 1, 2, 3])
		test.check(variant >= 1 and variant <= BabbleRules.VARIANTS and not variant in [30, 31, 32, 1, 2, 3], "trekking %d geeft een vrije variant (%d)" % [drawn, variant])


func test_recent_after(test) -> void:
	var recent := [1, 2]
	var after := BabbleRules.recent_after(recent, 9)
	test.check(after == [1, 2, 9], "de nieuwe komt achteraan")
	test.check(recent == [1, 2], "de lijst zelf blijft zoals hij was")
	test.check(BabbleRules.recent_after([], 4) == [4], "de eerste")
	var full := [1, 2, 3, 4, 5, 6]
	test.check(BabbleRules.recent_after(full, 7) == [2, 3, 4, 5, 6, 7], "bij meer dan %d valt de oudste af" % BabbleRules.RECENT)
	test.check(BabbleRules.recent_after(full, 7).size() == BabbleRules.RECENT, "nooit meer dan %d" % BabbleRules.RECENT)


func test_name_of(test) -> void:
	test.check(BabbleRules.name_of("vrouw", "boos", 12) == "brabbel_vrouw_boos_12", "brabbel_<stem>_<stemming>_<n>")
	test.check(BabbleRules.name_of("oude_man", "vraag", 1) == "brabbel_oude_man_vraag_1", "ook een stem van twee woorden")
	test.check(BabbleRules.name_of("robot", "verveeld", 3) == "brabbel_man_neutraal_3", "onbekend wordt man, neutraal")
	var missing: Array[String] = []
	for voice: String in BabbleRules.VOICES:
		for mood: String in BabbleRules.MOODS:
			for variant in [1, BabbleRules.VARIANTS]:
				if not FileAccess.file_exists(SoundFiles.path_of(BabbleRules.name_of(voice, mood, variant))):
					missing.append(BabbleRules.name_of(voice, mood, variant))
	test.check(missing.is_empty(), "van elke stem en stemming bestaan de eerste en de laatste variant %s" % [missing.slice(0, 6)])


func test_pitch_of(test) -> void:
	test.check(BabbleRules.pitch_of(0.0) == 1.0, "geen afwijking: 1")
	test.check(is_equal_approx(BabbleRules.pitch_of(0.05), 1.05) and is_equal_approx(BabbleRules.pitch_of(-0.05), 0.95), "hoger en lager")
	test.check(is_equal_approx(BabbleRules.pitch_of(0.5), 1.0 + BabbleRules.PITCH_SPREAD), "nooit verder dan de spreiding omhoog")
	test.check(is_equal_approx(BabbleRules.pitch_of(-0.5), 1.0 - BabbleRules.PITCH_SPREAD), "en omlaag")


func test_word_at(test) -> void:
	var line := "Heb je misschien wat kleingeld voor me?"
	test.check(BabbleRules.word_at(line, 0) == "Heb" and BabbleRules.word_at(line, 2) == "misschien", "het zoveelste geluid is het zoveelste woord")
	test.check(BabbleRules.word_at(line, 6) == "me?" and BabbleRules.word_at(line, 50) == "me?", "na het laatste woord: dat woord nog eens")
	test.check(BabbleRules.word_at("", 0) == "" and BabbleRules.word_at("   ", 3) == "", "zonder woorden: geen woord")
	test.check(BabbleRules.word_at("een   twee", 1) == "twee", "extra spaties tellen niet als woord")
	test.check(BabbleRules.word_at("hoi", 0) == "hoi" and BabbleRules.word_at("hoi", 4) == "hoi", "een regel van één woord")
