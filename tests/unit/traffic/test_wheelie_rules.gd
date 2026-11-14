extends RefCounted
## Unit tests of the sums of a wheelie (scripts/vehicles/wheelie_rules.gd): when one may
## start, the wobble, up and down, the bounce of the landing and the turn about the rear wheel.
##   tests/run_unit_tests.sh wheelie_rules

const WheelieRules = preload("res://scripts/vehicles/wheelie_rules.gd")


func test_up_while_held_or_not_down_yet(test) -> void:
	test.check(WheelieRules.is_up(2.0, 0.0), "nog seconden te gaan: omhoog")
	test.check(WheelieRules.is_up(0.0, 0.2), "nog niet neer: omhoog")
	test.check(not WheelieRules.is_up(0.0, 0.0) and not WheelieRules.is_up(0.0, WheelieRules.UP_ANGLE), "plat: niet omhoog")
	test.check(not WheelieRules.is_up(-0.5, 0.005), "bijna plat en uitgeteld: niet omhoog")


func test_one_starts_about_every_mean_pause(test) -> void:
	test.check(is_equal_approx(WheelieRules.start_chance(1.0 / 60.0) * 60.0 * WheelieRules.MEAN_PAUSE, 1.0), "gemiddeld één per MEAN_PAUSE seconden")
	test.check(WheelieRules.start_chance(0.0) == 0.0, "zonder tijd geen kans")
	test.check(WheelieRules.start_chance(0.2) == 0.2 / 45.0, "de kans groeit met de stap")


func test_it_may_only_start_when_allowed_and_down(test) -> void:
	test.check(WheelieRules.may_start(true, 0.0), "mag, en plat")
	test.check(not WheelieRules.may_start(false, 0.0), "mag niet")
	test.check(not WheelieRules.may_start(true, WheelieRules.DOWN_ANGLE) and not WheelieRules.may_start(true, 0.3), "nog niet neer van de vorige")


func test_the_front_wobbles_round_its_height(test) -> void:
	test.check(WheelieRules.wanted_angle(0.5, 0.0) == 0.5, "op tel nul precies de hoogte")
	var highest := 0.0
	var lowest := 10.0
	for step in 600:
		var wanted := WheelieRules.wanted_angle(0.5, step / 60.0)
		highest = maxf(highest, wanted)
		lowest = minf(lowest, wanted)
	test.check(is_equal_approx(highest, 0.5 * (1.0 + WheelieRules.WOBBLE_SHARE)) or absf(highest - 0.5 * 1.12) < 0.001, "hoogstens het aandeel erboven (%.3f)" % highest)
	test.check(absf(lowest - 0.5 * 0.88) < 0.001, "en eronder (%.3f)" % lowest)
	test.check(WheelieRules.wanted_angle(0.0, 3.0) == 0.0, "zonder hoogte geen wiebel")


func test_up_and_down_go_gradually(test) -> void:
	test.check(WheelieRules.risen(0.2, 0.5, 0.0) == 0.2 and WheelieRules.dropped(0.2, 0.0) == 0.2, "zonder tijd verandert er niets")
	var one_step := WheelieRules.risen(0.0, 0.5, 1.0 / 60.0)
	test.check(one_step > 0.0 and one_step < 0.5, "één stap: een stukje omhoog")
	test.check(is_equal_approx(one_step, 0.5 * (1.0 - exp(-WheelieRules.RISE_RATE / 60.0))), "met de stijgsnelheid")
	test.check(absf(WheelieRules.risen(0.0, 0.5, 10.0) - 0.5) < 0.0001, "na lang: op de hoogte")
	var down := WheelieRules.dropped(0.5, 1.0 / 60.0)
	test.check(down < 0.5 and down > 0.0, "één stap: een stukje neer")
	test.check(is_equal_approx(down, 0.5 * exp(-WheelieRules.DROP_RATE / 60.0)), "met de daalsnelheid")
	test.check(0.5 - down > one_step, "neer gaat sneller dan omhoog")
	test.check(WheelieRules.dropped(0.5, 10.0) < 0.0001, "na lang: plat")


func test_the_front_wheel_bounces_on_landing(test) -> void:
	test.check(WheelieRules.spring(0.0, 0.5) == 0.0, "op het moment van landen nog niets")
	var highest := 0.0
	for step in 48:
		var spring := WheelieRules.spring(step / 60.0, 0.5)
		test.check(spring >= 0.0, "nooit onder de weg")
		highest = maxf(highest, spring)
	test.check(highest > 0.01 and highest < WheelieRules.BOUNCE_SHARE * 0.5, "een klein stuitje (%.3f)" % highest)
	test.check(WheelieRules.spring(0.7, 0.5) < WheelieRules.spring(0.1, 0.5), "het dooft uit")
	test.check(WheelieRules.spring(0.1, 0.0) == 0.0, "geen hoogte: geen stuit")
	test.check(WheelieRules.spring(0.1, 1.0) == 2.0 * WheelieRules.spring(0.1, 0.5), "hoger gevallen: verder gestuit")


func test_the_bounce_only_shows_when_nearly_down(test) -> void:
	test.check(WheelieRules.bounced(0.005, 0.03) == 0.03, "bijna plat: de stuit erin")
	test.check(WheelieRules.bounced(0.015, 0.01) == 0.015, "de stuit kleiner dan de hoek: de hoek")
	test.check(WheelieRules.bounced(0.3, 0.5) == 0.3, "nog hoog: geen stuit")
	test.check(WheelieRules.bounced(WheelieRules.BOUNCE_UNDER, 0.5) == WheelieRules.BOUNCE_UNDER, "op de grens niet")
	test.check(not WheelieRules.bounce_done(0.0) and not WheelieRules.bounce_done(WheelieRules.BOUNCE_SECONDS), "de stuit duurt even")
	test.check(WheelieRules.bounce_done(WheelieRules.BOUNCE_SECONDS + 0.01), "en is dan voorbij")


func test_the_body_turns_about_the_rear_contact(test) -> void:
	var pivot := Vector3(0.0, 0.0, -0.6)
	var flat := WheelieRules.tilt_about(0.0, pivot)
	test.check(flat.is_equal_approx(Transform3D.IDENTITY), "plat: niets gedraaid")
	var turned := WheelieRules.tilt_about(deg_to_rad(30.0), pivot)
	test.check((turned * pivot).distance_to(pivot) < 0.0001, "het achterwiel blijft op zijn plek")
	var front := turned * Vector3(0.0, 0.0, 0.6)
	test.check(absf(front.y - 1.2 * sin(deg_to_rad(30.0))) < 0.0001, "het voorwiel gaat omhoog (%.3f m)" % front.y)
	test.check(absf(front.distance_to(pivot) - 1.2) < 0.0001, "even ver van het achterwiel als eerst")
	test.check(absf((turned * Vector3(0.4, 0.0, 0.6)).x - 0.4) < 0.0001, "niet opzij")
	var other_pivot := Vector3(0.1, 0.05, -1.0)
	test.check((WheelieRules.tilt_about(0.7, other_pivot) * other_pivot).distance_to(other_pivot) < 0.0001, "om welk punt ook")
