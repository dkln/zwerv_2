extends RefCounted
## Unit tests of how the stats of the player look (scripts/ui/hud/stat_look.gd): every stat
## has a bar, two colours and an icon that exists.
##   tests/run_unit_tests.sh stat_look

const StatLook = preload("res://scripts/ui/hud/stat_look.gd")


func test_every_stat_has_its_look(test) -> void:
	test.check(StatLook.STATS.keys() == ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"], "de vier stats in hun volgorde")
	for stat_name: String in StatLook.STATS:
		var stat: Dictionary = StatLook.STATS[stat_name]
		test.check(StatLook.PIXEL_ICONS.has(stat.icon), "%s: zijn icoon bestaat" % stat_name)
		test.check(int(stat.segments) > 0 and int(stat.height) > 0 and stat.colour != stat.empty, "%s: een balk met twee kleuren" % stat_name)


func test_icons_are_seven_by_seven(test) -> void:
	for icon_name: String in StatLook.PIXEL_ICONS:
		var rows: Array = StatLook.PIXEL_ICONS[icon_name]
		test.check(rows.size() == 7 and rows.all(func(row: String) -> bool: return row.length() == 7), "%s: 7 x 7 pixels" % icon_name)
		test.check(rows.any(func(row: String) -> bool: return row.contains("#")), "%s: er staat iets in" % icon_name)


func test_experience_bar_and_flashes(test) -> void:
	test.check(StatLook.XP_SEGMENTS > 0 and StatLook.XP_SEGMENT_HEIGHT > 0 and StatLook.XP_COLOUR != StatLook.XP_EMPTY_COLOUR, "de XP-balk: segmenten in twee kleuren")
	test.check(StatLook.GAINED_FLASH != StatLook.LOST_FLASH and StatLook.FLASH_SECONDS > 0.0, "erbij en eraf lichten anders op, even")
	test.check(StatLook.LOST_FLASH.r > StatLook.LOST_FLASH.g, "eraf is roodachtig")
