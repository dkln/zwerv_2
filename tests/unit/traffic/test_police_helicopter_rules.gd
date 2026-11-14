extends RefCounted
## Unit tests of how the police helicopter flies and flashes
## (scripts/vehicles/police_helicopter_rules.gd): the rotors, the flashing lamps, the search
## light and the circle.
##   tests/run_unit_tests.sh police_helicopter_rules

const PoliceHelicopterRules = preload("res://scripts/vehicles/police_helicopter_rules.gd")


func test_the_rotors_turn(test) -> void:
	test.check(PoliceHelicopterRules.rotor_speed(1.0) == TAU and PoliceHelicopterRules.rotor_speed(5.0) == TAU * 5.0, "een toer per seconde is tau rad/s")
	test.check(PoliceHelicopterRules.rotor_angle(1.0, 5.0, 0.0) == 1.0, "zonder tijd draait er niets")
	test.check(is_equal_approx(PoliceHelicopterRules.rotor_angle(0.0, 5.0, 0.05), TAU * 0.25), "een kwart toer in een twintigste seconde")
	test.check(absf(PoliceHelicopterRules.rotor_angle(0.0, 5.0, 0.3) - PI) < 0.0001, "anderhalve toer is een halve verder")
	var angle := 0.0
	for step in 600:
		angle = PoliceHelicopterRules.rotor_angle(angle, PoliceHelicopterRules.TAIL_ROTOR_TURNS, 1.0 / 60.0)
		if step % 100 == 0:
			test.check(angle >= 0.0 and angle < TAU, "de hoek blijft binnen een toer (%d)" % step)
	test.check(PoliceHelicopterRules.TAIL_ROTOR_TURNS > PoliceHelicopterRules.MAIN_ROTOR_TURNS, "de staartrotor draait sneller")


func test_fast_blades_blur_into_a_disc(test) -> void:
	test.check(PoliceHelicopterRules.spin_blur(0.0) == 0.0 and PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.BLUR_FROM) == 0.0, "langzaam: scherpe bladen")
	test.check(PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.BLUR_FROM * 1.5) == 0.5, "anderhalf keer de grens: half wazig")
	test.check(PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.BLUR_FROM * 2.0) == 1.0 and PoliceHelicopterRules.spin_blur(1000.0) == 1.0, "vanaf twee keer: een schijf")
	test.check(PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.rotor_speed(PoliceHelicopterRules.MAIN_ROTOR_TURNS)) == 1.0, "de hoofdrotor is een schijf")
	test.check(PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.rotor_speed(PoliceHelicopterRules.TAIL_ROTOR_TURNS)) == 1.0, "de staartrotor ook")


func test_the_strobe_and_the_beacon_flash_in_turn(test) -> void:
	test.check(PoliceHelicopterRules.flash_phase(0.0) == 0.0, "op tel nul begint de cyclus")
	test.check(is_equal_approx(PoliceHelicopterRules.flash_phase(PoliceHelicopterRules.FLASH_CYCLE * 0.5), 0.5), "halverwege")
	test.check(is_equal_approx(PoliceHelicopterRules.flash_phase(PoliceHelicopterRules.FLASH_CYCLE * 3.25), 0.25), "elke cyclus opnieuw")
	test.check(PoliceHelicopterRules.strobe_lit(0.0) and PoliceHelicopterRules.strobe_lit(0.11) and not PoliceHelicopterRules.strobe_lit(PoliceHelicopterRules.FLASH_LIT), "de flitser aan het begin, kort")
	test.check(not PoliceHelicopterRules.beacon_lit(0.0) and PoliceHelicopterRules.beacon_lit(0.5) and PoliceHelicopterRules.beacon_lit(0.61), "het zwaailicht een halve cyclus later")
	test.check(not PoliceHelicopterRules.beacon_lit(0.49) and not PoliceHelicopterRules.beacon_lit(0.63), "en ook kort")
	var strobe_frames := 0
	var beacon_frames := 0
	var steps := 1000
	for step in steps:
		var phase := float(step) / steps
		var strobe := PoliceHelicopterRules.strobe_lit(phase)
		var beacon := PoliceHelicopterRules.beacon_lit(phase)
		strobe_frames += 1 if strobe else 0
		beacon_frames += 1 if beacon else 0
		if strobe and beacon:
			test.check(false, "nooit tegelijk aan (%.3f)" % phase)
	test.check(absf(strobe_frames - steps * PoliceHelicopterRules.FLASH_LIT) <= 1.0 and absf(beacon_frames - steps * PoliceHelicopterRules.FLASH_LIT) <= 1.0, "elk het aandeel FLASH_LIT van de tijd aan (%d, %d)" % [strobe_frames, beacon_frames])


func test_the_search_light_comes_on_when_it_gets_dark(test) -> void:
	test.check(not PoliceHelicopterRules.searchlight_on(0.0) and not PoliceHelicopterRules.searchlight_on(0.34), "overdag uit")
	test.check(PoliceHelicopterRules.searchlight_on(PoliceHelicopterRules.SEARCHLIGHT_FROM) and PoliceHelicopterRules.searchlight_on(1.0), "vanaf de schemer aan")


func test_which_way_round(test) -> void:
	test.check(PoliceHelicopterRules.turning(true) == -1.0 and PoliceHelicopterRules.turning(false) == 1.0, "tegen de klok in loopt de hoek terug")
	test.check(is_equal_approx(PoliceHelicopterRules.circle_angle(0.0, false, 22.0, 50.0, 1.0), 0.44), "22 m/s om 50 m: 0,44 rad per seconde")
	test.check(is_equal_approx(PoliceHelicopterRules.circle_angle(0.0, true, 22.0, 50.0, 1.0), -0.44), "tegen de klok in de andere kant op")
	test.check(PoliceHelicopterRules.circle_angle(1.0, true, 22.0, 50.0, 0.0) == 1.0, "zonder tijd blijft hij waar hij is")
	test.check(is_equal_approx(PoliceHelicopterRules.circle_angle(0.0, false, 2.0, 0.0, 1.0), 2.0), "een straal van niets telt als een meter")
	test.check(absf(PoliceHelicopterRules.circle_angle(TAU - 0.1, false, 10.0, 50.0, 1.0) - 0.1) < 0.0001, "de hoek blijft binnen een rondje")


func test_where_it_is_on_the_circle(test) -> void:
	var centre := Vector3(100.0, 0.0, -20.0)
	test.check(PoliceHelicopterRules.circle_out(0.0) == Vector3(1.0, 0.0, 0.0), "hoek nul: naar +x")
	test.check(PoliceHelicopterRules.circle_out(PI / 2.0).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "een kwart verder: naar +z")
	test.check(PoliceHelicopterRules.circle_position(centre, 50.0, 40.0, 0.0) == Vector3(150.0, 40.0, -20.0), "op de straal, op hoogte")
	for step in 12:
		var here := PoliceHelicopterRules.circle_position(centre, 50.0, 40.0, step * TAU / 12.0)
		test.check(absf(Vector2(here.x - centre.x, here.z - centre.z).length() - 50.0) < 0.0001 and here.y == 40.0, "steeds op 50 m van het midden, 40 m hoog (%d)" % step)


func test_it_flies_along_the_circle(test) -> void:
	test.check(PoliceHelicopterRules.circle_ahead(0.0, false).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "met de klok mee op +x: naar +z")
	test.check(PoliceHelicopterRules.circle_ahead(0.0, true).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "tegen de klok in: naar -z")
	for anticlockwise: bool in [true, false]:
		for step in 8:
			var angle := step * TAU / 8.0
			var later := PoliceHelicopterRules.circle_angle(angle, anticlockwise, 22.0, 50.0, 0.01)
			var moved := PoliceHelicopterRules.circle_position(Vector3.ZERO, 50.0, 0.0, later) - PoliceHelicopterRules.circle_position(Vector3.ZERO, 50.0, 0.0, angle)
			var ahead := PoliceHelicopterRules.circle_ahead(angle, anticlockwise)
			test.check(moved.normalized().dot(ahead) > 0.99, "vooruit is de kant die hij op gaat (%s, %d)" % [anticlockwise, step])
			test.check(absf(ahead.dot(PoliceHelicopterRules.circle_out(angle))) < 0.0001 and absf(ahead.length() - 1.0) < 0.0001, "langs de cirkel")


func test_banked_into_the_turn_with_the_nose_down(test) -> void:
	for anticlockwise: bool in [true, false]:
		for step in 8:
			var angle := step * TAU / 8.0
			var turned := PoliceHelicopterRules.circle_basis(angle, anticlockwise)
			var ahead := PoliceHelicopterRules.circle_ahead(angle, anticlockwise)
			var out := PoliceHelicopterRules.circle_out(angle)
			var what := "%s, %d" % ["tegen de klok in" if anticlockwise else "met de klok mee", step]
			test.check(turned.is_equal_approx(turned.orthonormalized()), "een zuivere draaiing (%s)" % what)
			var nose := turned * Vector3(0.0, 0.0, 1.0)
			test.check(Vector3(nose.x, 0.0, nose.z).normalized().dot(ahead) > 0.99, "de neus langs de cirkel (%s)" % what)
			test.check(absf(rad_to_deg(asin(-nose.y)) - PoliceHelicopterRules.NOSE_DOWN_DEGREES) < 0.5, "de neus zes graden omlaag (%s)" % what)
			var top := turned * Vector3.UP
			test.check(top.dot(out) < -0.15 and top.y > 0.9, "de bovenkant naar het midden van de cirkel (%s)" % what)
			test.check(absf(rad_to_deg(top.angle_to(Vector3.UP)) - 15.2) < 1.0, "ongeveer veertien graden schuin (%s)" % what)
