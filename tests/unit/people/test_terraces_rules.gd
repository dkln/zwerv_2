extends RefCounted
## Unit tests of who sits on the terraces (scripts/world/people/terraces_rules.gd).
##   tests/run_unit_tests.sh terraces_rules

const TerracesRules = preload("res://scripts/world/people/terraces_rules.gd")


func test_some_of_the_chairs_are_taken(test) -> void:
	test.check(TerracesRules.is_taken(1) and TerracesRules.is_taken(TerracesRules.OCCUPIED), "tot en met OCCUPIED: bezet")
	test.check(not TerracesRules.is_taken(TerracesRules.OCCUPIED + 1) and not TerracesRules.is_taken(TerracesRules.ROLL_MOST), "daarboven: leeg")
	var taken := 0
	for roll in range(1, TerracesRules.ROLL_MOST + 1):
		taken += 1 if TerracesRules.is_taken(roll) else 0
	test.check(taken == TerracesRules.OCCUPIED, "precies OCCUPIED van de honderd")
	test.check(TerracesRules.GUEST_KIND == "klant", "wie er zit is een klant")
