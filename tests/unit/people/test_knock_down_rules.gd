extends RefCounted
## Unit tests of the sums of someone knocked over (scripts/world/people/knock_down_rules.gd).
##   tests/run_unit_tests.sh knock_down_rules

const KnockDownRules = preload("res://scripts/world/people/knock_down_rules.gd")


func test_the_way_it_is_thrown(test) -> void:
	test.check(KnockDownRules.flat(Vector3(1.0, 5.0, -2.0)) == Vector3(1.0, 0.0, -2.0), "de duw langs de grond")
	test.check(KnockDownRules.towards(Vector3(3.0, 9.0, 0.0), Vector3.BACK).is_equal_approx(Vector3.RIGHT), "met de duw mee")
	test.check(KnockDownRules.towards(Vector3(0.0, 4.0, 0.05), Vector3.BACK) == Vector3.BACK, "zonder duw: de kant waar het heen keek")
	test.check(KnockDownRules.towards(Vector3.ZERO, Vector3.LEFT) == Vector3.LEFT, "geen duw")


func test_thrown_up_by_the_blow(test) -> void:
	var slow := KnockDownRules.thrown_velocity(Vector3(2.0, 3.0, 0.0), 1.0, 0.0)
	test.check(slow.is_equal_approx(Vector3(2.0, KnockDownRules.UP_BASE, 0.0)), "een tikje: de duw en een beetje omhoog")
	var hard := KnockDownRules.thrown_velocity(Vector3(2.0, 0.0, 0.0), 2.0, 10.0)
	test.check(is_equal_approx(hard.x, 4.0) and is_equal_approx(hard.y, 1.5 + 2.2), "harder: hoger, de duw maal de factor")
	test.check(KnockDownRules.thrown_velocity(Vector3.ZERO, 1.0, 500.0).y == KnockDownRules.MOST_UP, "nooit hoger dan MOST_UP")


func test_tumbling(test) -> void:
	var spin := KnockDownRules.thrown_spin(Vector3.BACK, 10.0, 0.0, 0.0)
	test.check(spin.is_equal_approx(Vector3(6.0, 0.0, 0.0)), "voorover om de as dwars op de worp (%s)" % spin)
	test.check(is_equal_approx(KnockDownRules.thrown_spin(Vector3.BACK, 10.0, 2.0, 0.0).length(), 8.0), "met extra draai")
	test.check(is_equal_approx(KnockDownRules.thrown_spin(Vector3.BACK, 100.0, 9.0, 0.0).length(), KnockDownRules.MOST_SPIN), "niet sneller dan MOST_SPIN")
	test.check(is_equal_approx(KnockDownRules.thrown_spin(Vector3.BACK, 0.0, 0.0, -2.5).y, -2.5), "en wat om de staande as")


func test_a_dive_out_of_a_door(test) -> void:
	var start := KnockDownRules.dive_start(Vector3.BACK, Vector3(1.0, 0.0, 2.0))
	test.check(start.origin.is_equal_approx(Vector3(1.0, KnockDownRules.DIVE_LIFT, 2.0)), "opgetild boven de straat")
	# the head (the body's +y) points the way it is thrown, nearly flat
	test.check((start.basis * Vector3.UP).dot(Vector3.BACK) > 0.9, "plat, het hoofd vooruit")
	test.check(KnockDownRules.dive_velocity(Vector3(0.0, 9.0, 5.0), 1.0).is_equal_approx(Vector3(0.0, KnockDownRules.DIVE_UP, 5.0)), "een beetje omhoog, de duw mee")
	var spin := KnockDownRules.dive_spin(Vector3.BACK, 0.5)
	test.check(is_equal_approx(spin.x, KnockDownRules.DIVE_SPIN) and is_equal_approx(spin.z, 0.5), "nauwelijks draaiend in de lucht")


func test_the_blows_of_the_lying_body(test) -> void:
	test.check(KnockDownRules.is_hard_blow(3.0, 0.0), "vanaf HARD_SPEED telt een klap")
	test.check(not KnockDownRules.is_hard_blow(2.9, 0.0), "zachter niet")
	test.check(not KnockDownRules.is_hard_blow(9.0, 0.05), "niet twee keer vlak na elkaar")
	test.check(KnockDownRules.blow_strength(16.0) == 1.0 and KnockDownRules.blow_strength(40.0) == 1.0, "de hardste klap: alle scherven")
	test.check(is_equal_approx(KnockDownRules.blow_strength(8.0), 0.5), "half zo hard: de helft")
	test.check(KnockDownRules.blow_strength(0.5) == KnockDownRules.LEAST_STRENGTH, "altijd wat scherven")
