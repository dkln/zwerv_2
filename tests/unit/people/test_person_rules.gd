extends RefCounted
## Unit tests of what the people of the town share, worked out
## (scripts/world/people/person_rules.gd): the voice of a look, and the cycle of the steps.
##   tests/run_unit_tests.sh person_rules

const PersonRules = preload("res://scripts/world/people/person_rules.gd")


func test_the_voice_of_a_look(test) -> void:
	test.check(PersonRules.voice_of({}, "") == "man", "zonder look: een man")
	test.check(PersonRules.voice_of({"hair_style": "kort"}, "") == "man", "kort haar: een man")
	test.check(PersonRules.voice_of({"hair_style": "lang"}, "") == "vrouw", "lang haar: een vrouw")
	test.check(PersonRules.voice_of({"hair_style": "kort", "skirt": true}, "") == "vrouw", "een rok: een vrouw")
	test.check(PersonRules.voice_of({"hair_style": "kaal"}, "") == "oude_man", "kaal: een oude man")
	test.check(PersonRules.voice_of({"hair_style": "kort"}, "scootmobiel") == "oude_man", "op een scootmobiel: een oude man")
	test.check(PersonRules.voice_of({"hair_style": "lang"}, "rolstoel") == "vrouw", "lang haar gaat voor de rolstoel")


func test_the_speed_of_a_step(test) -> void:
	test.check(is_equal_approx(PersonRules.speed_of(0.07, 0.05), 1.4), "meters gedeeld door seconden")
	test.check(PersonRules.speed_of(0.0, 0.05) == 0.0, "stilstaan: nul")
	test.check(not is_inf(PersonRules.speed_of(1.0, 0.0)), "geen deling door nul")


func test_the_phase_goes_on_by_the_stride(test) -> void:
	test.check(is_equal_approx(PersonRules.phase_after(0.0, 0.62, 0.62), PI), "een stap verder: een halve slag")
	test.check(is_equal_approx(PersonRules.phase_after(1.0, 0.0, 0.62), 1.0), "niet bewogen: dezelfde fase")
	test.check(PersonRules.phase_after(0.0, 0.5, 1.05) < PersonRules.phase_after(0.0, 0.5, 0.62), "langere passen: minder slag per meter")


func test_walk_and_run_blend_in_and_out(test) -> void:
	test.check(is_equal_approx(PersonRules.walk_share_after(0.0, true, 0.1), 0.5), "lopen komt op met WALK_BLEND per seconde")
	test.check(PersonRules.walk_share_after(0.95, true, 0.1) == 1.0, "niet voorbij 1")
	test.check(is_equal_approx(PersonRules.walk_share_after(1.0, false, 0.1), 0.5), "stilstaan: het zakt weer")
	test.check(PersonRules.walk_share_after(0.2, false, 0.1) == 0.0, "niet onder 0")
	test.check(is_equal_approx(PersonRules.run_share_after(0.0, 1.0, 0.1), 0.4), "rennen komt op met RUN_BLEND per seconde")
	test.check(is_equal_approx(PersonRules.run_share_after(1.0, 0.0, 0.1), 0.6), "en zakt weer")
	test.check(PersonRules.run_share_after(0.5, 0.5, 0.1) == 0.5, "al waar het wezen moet")
