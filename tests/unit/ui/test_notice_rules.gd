extends RefCounted
## Unit tests of the rules of the notices of the HUD (scripts/ui/hud/notice_rules.gd).
##   tests/run_unit_tests.sh notice_rules

const NoticeRules = preload("res://scripts/ui/hud/notice_rules.gd")


func test_a_notice_is_a_heading_a_name_and_a_time(test) -> void:
	var made := NoticeRules.notice("KOP", "Naam", 4.0)
	test.check(made == {"heading": "KOP", "name": "Naam", "seconds": 4.0, "jingle": ""}, "zonder deuntje (%s)" % [made])
	test.check(NoticeRules.notice("KOP", "Naam", 4.0, "res://deun.ogg").jingle == "res://deun.ogg", "met een deuntje")
	test.check(NoticeRules.level_name(4) == "Level 4", "de naam van een nieuw level")
	test.check(NoticeRules.AREA_HEADING != NoticeRules.MISSION_HEADING and NoticeRules.MISSION_HEADING != NoticeRules.LEVEL_HEADING, "elke soort melding haar eigen kop")


func test_the_same_name_while_it_is_up_is_a_repeat(test) -> void:
	var centre := NoticeRules.notice(NoticeRules.AREA_HEADING, "Centrum", 4.0)
	test.check(NoticeRules.is_repeat(true, "Centrum", centre), "hetzelfde gebied terwijl het er staat: een herhaling")
	test.check(not NoticeRules.is_repeat(false, "Centrum", centre), "de melding is weg: geen herhaling")
	test.check(not NoticeRules.is_repeat(true, "Station", centre), "een ander gebied: geen herhaling")
	test.check(not NoticeRules.is_repeat(true, "Centrum", {}), "een melding zonder naam: geen herhaling van een naam")
