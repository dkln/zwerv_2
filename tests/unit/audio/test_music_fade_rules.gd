extends RefCounted
## Unit tests of the logic of music running into the next piece
## (scripts/audio/music_fade_rules.gd): the volume along a fade in and a fade out, equal
## power. The players and the tweens: tests/unit/audio/test_music_fade.gd.
##   tests/run_unit_tests.sh music_fade

const MusicFadeRules = preload("res://scripts/audio/music_fade_rules.gd")


func test_fade_in_goes_from_silence_to_its_level(test) -> void:
	test.check(MusicFadeRules.fade_in_db(-4.0, 0.0) <= -99.0, "aan het begin: stil (%.1f dB)" % MusicFadeRules.fade_in_db(-4.0, 0.0))
	test.check(is_equal_approx(MusicFadeRules.fade_in_db(-4.0, 1.0), -4.0), "aan het eind: op niveau")
	var before := MusicFadeRules.fade_in_db(-4.0, 0.0)
	for step in range(1, 11):
		var now := MusicFadeRules.fade_in_db(-4.0, step / 10.0)
		test.check(now > before, "stap %d luider dan de vorige" % step)
		before = now


func test_fade_out_goes_from_its_level_to_silence(test) -> void:
	test.check(is_equal_approx(MusicFadeRules.fade_out_db(-6.0, 0.0), -6.0), "aan het begin: waar hij was")
	test.check(MusicFadeRules.fade_out_db(-6.0, 1.0) <= -99.0, "aan het eind: stil")
	var before := MusicFadeRules.fade_out_db(-6.0, 0.0)
	for step in range(1, 11):
		var now := MusicFadeRules.fade_out_db(-6.0, step / 10.0)
		test.check(now < before, "stap %d zachter dan de vorige" % step)
		before = now


## Equal power: the two together are as loud all the way, so halfway both are 3 dB down.
func test_equal_power(test) -> void:
	test.check(absf(MusicFadeRules.fade_in_db(0.0, 0.5) + 3.0103) < 0.001, "halverwege komt de ene op -3 dB")
	test.check(absf(MusicFadeRules.fade_out_db(0.0, 0.5) + 3.0103) < 0.001, "en zit de andere op -3 dB")
	for step in 11:
		var share := step / 10.0
		var coming := db_to_linear(MusicFadeRules.fade_in_db(-5.0, share))
		var going := db_to_linear(MusicFadeRules.fade_out_db(-5.0, share))
		var power := coming * coming + going * going
		test.check(absf(power - db_to_linear(-5.0) * db_to_linear(-5.0)) < 0.0001, "samen even luid op %.1f" % share)


func test_never_minus_infinity(test) -> void:
	test.check(is_finite(MusicFadeRules.fade_in_db(-4.0, 0.0)) and is_finite(MusicFadeRules.fade_out_db(-4.0, 1.0)), "stil is een eindig getal")
	test.check(is_finite(MusicFadeRules.fade_in_db(MusicFadeRules.SILENT_DB, 1.0)), "ook naar stilte toe")
	test.check(MusicFadeRules.SECONDS > 0.0 and MusicFadeRules.SILENT_DB <= -60.0, "een overgang duurt even en stil is stil")
