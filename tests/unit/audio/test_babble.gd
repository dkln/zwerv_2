extends RefCounted
## Unit tests of Babble.sound_name (scripts/audio/babble.gd): the name of a babble sound for
## a voice and a mood.

const Babble = preload("res://scripts/audio/babble.gd")


## The name is brabbel_<voice>_<mood>_<n>, n one of the variants.
func test_name_has_voice_mood_and_variant(test) -> void:
	var name := Babble.sound_name("vrouw", "boos")
	test.check(name.begins_with("brabbel_vrouw_boos_"), "begint met brabbel_vrouw_boos_ (%s)" % name)
	var variant := int(name.get_slice("_", 3))
	test.check(variant >= 1 and variant <= Babble.VARIANTS, "variant tussen 1 en %d (%d)" % [Babble.VARIANTS, variant])


## The same voice and mood never give the same variant twice in a row.
func test_never_the_same_variant_twice(test) -> void:
	var last := Babble.sound_name("man", "blij")
	for attempt in 50:
		var next := Babble.sound_name("man", "blij")
		test.check(next != last, "niet twee keer %s achter elkaar" % next)
		last = next


## An unknown voice or mood falls back to "man" and "neutraal".
func test_unknown_voice_and_mood_fall_back(test) -> void:
	test.check(Babble.sound_name("robot", "verveeld").begins_with("brabbel_man_neutraal_"), "onbekend wordt man, neutraal")


## A word always sounds the same: the same variant and pitch for the same word, whatever
## signs or capitals are round it, and different words spread over the variants.
func test_a_word_has_its_own_sound(test) -> void:
	test.check(Babble.sound_name("vrouw", "blij", "kroket") == Babble.sound_name("vrouw", "blij", "kroket"), "hetzelfde woord: hetzelfde geluid")
	test.check(Babble.variant_of("Kroket!") == Babble.variant_of("kroket"), "hoofdletters en leestekens tellen niet")
	test.check(is_equal_approx(Babble.pitch_of("kroket"), Babble.pitch_of("kroket")), "en dezelfde toonhoogte")
	test.check(absf(Babble.pitch_of("kroket") - 1.0) <= Babble.PITCH_SPREAD + 0.0001, "binnen de spreiding")
	var variants := {}
	for word: String in ["ja", "nee", "kroket", "tram", "geld", "morgen", "station", "fiets", "koffie", "weer"]:
		variants[Babble.variant_of(word)] = true
		test.check(Babble.variant_of(word) >= 1 and Babble.variant_of(word) <= Babble.VARIANTS, "%s: een bestaande variant" % word)
	test.check(variants.size() == Babble.VARIANTS, "verschillende woorden gebruiken alle varianten")


## A line plays one sound per word, in the order of its words: the same text, the same
## conversation to hear.
func test_a_line_sounds_the_same_every_time(test) -> void:
	var line := "Heb je misschien wat kleingeld voor me?"
	var first: Array[String] = []
	var second: Array[String] = []
	for index in 9:
		first.append(Babble.sound_name("man", "neutraal", Babble.word_at(line, index)))
		second.append(Babble.sound_name("man", "neutraal", Babble.word_at(line, index)))
	test.check(first == second, "dezelfde regel: dezelfde reeks geluiden")
	test.check(Babble.word_at(line, 0) == "Heb" and Babble.word_at(line, 2) == "misschien", "het zoveelste geluid is het zoveelste woord")
	test.check(Babble.word_at(line, 50) == "me?", "na het laatste woord: dat woord nog eens")
	test.check(Babble.word_at("", 0) == "" and Babble.sound_name("man", "blij", "").begins_with("brabbel_man_blij_"), "zonder woord: zomaar een variant")
