extends RefCounted
## Unit tests of the logic of the death screen (scripts/ui/screens/death_screen_rules.gd):
## the line with how it happened and from when the keys work, without nodes.
##   tests/run_unit_tests.sh death_screen_rules

const DeathScreenRules = preload("res://scripts/ui/screens/death_screen_rules.gd")


func test_death_reason_names_who_and_how(test) -> void:
	test.check(DeathScreenRules.reason("honger", "Sjaan") == "Sjaan is van de honger omgekomen.", "van de honger")
	test.check(DeathScreenRules.reason("verdronken", "Kees").begins_with("Kees is in het water gevallen"), "verdronken")
	test.check(DeathScreenRules.reason("", "Kees") == "Kees heeft het niet gered.", "geen oorzaak: een algemene regel")
	test.check(DeathScreenRules.reason("onbekend", "Kees") == "Kees heeft het niet gered.", "een onbekende oorzaak: ook")


func test_every_cause_has_one_place_for_the_name(test) -> void:
	for cause: String in DeathScreenRules.CAUSES:
		test.check(String(DeathScreenRules.CAUSES[cause]).count("%s") == 1, "%s: één plek voor de naam" % cause)
	test.check(DeathScreenRules.UNKNOWN_CAUSE.count("%s") == 1, "de algemene regel ook")


func test_keys_work_after_the_wait(test) -> void:
	test.check(not DeathScreenRules.keys_work(10.0, 10.0), "meteen: nog niet")
	test.check(not DeathScreenRules.keys_work(10.0, 10.0 + DeathScreenRules.KEYS_AFTER - 0.1), "vlak voor het einde van de wachttijd: nog niet")
	test.check(DeathScreenRules.keys_work(0.0, DeathScreenRules.KEYS_AFTER), "precies na de wachttijd: wel")
	test.check(DeathScreenRules.keys_work(10.0, 10.0 + DeathScreenRules.KEYS_AFTER + 0.01), "en vlak erna, ook later op de klok")
	test.check(DeathScreenRules.keys_work(10.0, 60.0), "lang daarna: ook")
