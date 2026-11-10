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
