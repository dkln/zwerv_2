extends RefCounted
## Unit tests of the little random pitch of every sound effect
## (scripts/audio/sound_variation.gd).
##   tests/run_unit_tests.sh sound_variation

const SoundVariation = preload("res://scripts/audio/sound_variation.gd")


func test_pitch_stays_within_its_spread(test) -> void:
	var heard := {}
	for play_index in 60:
		var pitch := SoundVariation.pitch()
		heard[snappedf(pitch, 0.0001)] = true
		test.check(absf(pitch - 1.0) <= SoundVariation.SPREAD + 0.0001, "binnen de spreiding (%.3f)" % pitch)
	test.check(heard.size() > 20, "steeds een andere toonhoogte (%d)" % heard.size())


func test_pitch_with_a_spread_of_its_own(test) -> void:
	for play_index in 40:
		test.check(absf(SoundVariation.pitch(SoundVariation.UI_SPREAD) - 1.0) <= SoundVariation.UI_SPREAD + 0.0001, "de interface varieert minder")
		test.check(absf(SoundVariation.pitch(SoundVariation.LOOP_SPREAD) - 1.0) <= SoundVariation.LOOP_SPREAD + 0.0001, "een lus binnen zijn eigen spreiding")
	test.check(SoundVariation.pitch(0.0) == 1.0, "zonder spreiding: precies 1")
	test.check(SoundVariation.UI_SPREAD < SoundVariation.SPREAD, "de interface minder dan de rest")
