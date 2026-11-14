extends RefCounted
## Unit tests of how the protest flag waves (scripts/vehicles/protest_flag_rules.gd).
##   tests/run_unit_tests.sh protest_flag_rules

const ProtestFlagRules = preload("res://scripts/vehicles/protest_flag_rules.gd")


func test_every_flag_starts_at_its_own_moment(test) -> void:
	test.check(ProtestFlagRules.wave_offset(0) == 0.0, "nummer nul: geen voorsprong")
	test.check(is_equal_approx(ProtestFlagRules.wave_offset(10), 3.7), "tien nummers verder: 3,7 s voor")
	test.check(ProtestFlagRules.wave_offset(997) == 0.0 and ProtestFlagRules.wave_offset(998) == ProtestFlagRules.wave_offset(1), "na 997 nummers weer van voren af aan")
	test.check(ProtestFlagRules.wave_offset(123456) != ProtestFlagRules.wave_offset(123457), "twee vlaggen naast elkaar wapperen niet gelijk")
	test.check(ProtestFlagRules.wave_offset(996) < 370.0, "nooit meer dan een paar minuten")


func test_the_cloth_waves_to_both_sides(test) -> void:
	test.check(ProtestFlagRules.cloth_turn(0.0) == 0.0, "op tel nul recht achteruit")
	var most := deg_to_rad(ProtestFlagRules.WAVE_DEGREES)
	var highest := 0.0
	var lowest := 0.0
	var biggest_step := 0.0
	var before := 0.0
	for step in 60 * 30:
		var turn := ProtestFlagRules.cloth_turn(step / 60.0)
		test.check(absf(turn) <= most + 0.0001, "nooit verder dan %d graden" % int(ProtestFlagRules.WAVE_DEGREES)) if step % 300 == 0 else null
		highest = maxf(highest, turn)
		lowest = minf(lowest, turn)
		biggest_step = maxf(biggest_step, absf(turn - before))
		before = turn
	test.check(highest > most * 0.8 and highest <= most + 0.0001, "bijna helemaal naar de ene kant (%.1f graden)" % rad_to_deg(highest))
	test.check(lowest < -most * 0.8 and lowest >= -most - 0.0001, "en naar de andere (%.1f graden)" % rad_to_deg(lowest))
	test.check(biggest_step < deg_to_rad(1.5), "rustig: geen sprongen tussen twee beelden")


func test_the_wave_is_a_slow_one_with_a_quick_one_on_top(test) -> void:
	var seconds := 1.7
	var slow := sin(seconds * ProtestFlagRules.WAVE_SPEED) * ProtestFlagRules.SLOW_SHARE
	var quick := sin(seconds * ProtestFlagRules.WAVE_SPEED * ProtestFlagRules.QUICK_FACTOR) * ProtestFlagRules.QUICK_SHARE
	test.check(ProtestFlagRules.cloth_turn(seconds) == deg_to_rad(ProtestFlagRules.WAVE_DEGREES) * (slow + quick), "de trage en de snelle golf samen")
	test.check(is_equal_approx(ProtestFlagRules.SLOW_SHARE + ProtestFlagRules.QUICK_SHARE, 1.0), "samen hoogstens de hele uitslag")
	test.check(ProtestFlagRules.WAVE_DEGREES == 12.0 and ProtestFlagRules.WAVE_SPEED == 3.1, "twaalf graden, 3,1 rad/s")
