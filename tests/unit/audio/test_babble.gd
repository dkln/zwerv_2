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


## The same voice and mood never give one of the last RECENT variants again.
func test_no_variant_again_soon(test) -> void:
	var recent: Array[String] = []
	for attempt in 80:
		var next := Babble.sound_name("man", "blij")
		test.check(not next in recent, "%s niet binnen %d keer opnieuw" % [next, Babble.RECENT])
		recent.append(next)
		if recent.size() > Babble.RECENT:
			recent.pop_front()


## An unknown voice or mood falls back to "man" and "neutraal".
func test_unknown_voice_and_mood_fall_back(test) -> void:
	test.check(Babble.sound_name("robot", "verveeld").begins_with("brabbel_man_neutraal_"), "onbekend wordt man, neutraal")


## Every word a random sound: the same word (or line) does not always sound the same, and in
## a while every variant comes by.
func test_every_word_a_random_sound(test) -> void:
	var line := "Heb je misschien wat kleingeld voor me?"
	var first: Array[String] = []
	var second: Array[String] = []
	for index in 9:
		first.append(Babble.sound_name("man", "neutraal", Babble.word_at(line, index)))
		second.append(Babble.sound_name("man", "neutraal", Babble.word_at(line, index)))
	test.check(first != second, "dezelfde regel klinkt elke keer anders")
	var heard := {}
	for attempt in 400:
		heard[Babble.sound_name("vrouw", "vraag", "kroket")] = true
	test.check(heard.size() == Babble.VARIANTS, "alle %d varianten komen langs (%d)" % [Babble.VARIANTS, heard.size()])
	test.check(Babble.word_at(line, 0) == "Heb" and Babble.word_at(line, 2) == "misschien", "het zoveelste geluid is het zoveelste woord")
	test.check(Babble.word_at(line, 50) == "me?", "na het laatste woord: dat woord nog eens")
	test.check(Babble.word_at("", 0) == "", "zonder woorden: geen woord")


## Every word at its own random pitch, within PITCH_SPREAD of 1.
func test_every_word_a_random_pitch(test) -> void:
	var pitches := {}
	for play_index in 30:
		var pitch := Babble.played_pitch("kroket")
		pitches[snappedf(pitch, 0.0001)] = true
		test.check(absf(pitch - 1.0) <= Babble.PITCH_SPREAD + 0.0001, "binnen de spreiding (%.3f)" % pitch)
	test.check(pitches.size() > 10, "steeds een andere toonhoogte (%d)" % pitches.size())
