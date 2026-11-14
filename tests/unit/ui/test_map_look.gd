extends RefCounted
## Unit tests of how the maps of the HUD look (scripts/ui/hud/map_look.gd): every kind of
## ground the rules know has a colour, and the marks can be told apart.
##   tests/run_unit_tests.sh map_look

const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const MinimapRules = preload("res://scripts/ui/hud/minimap_rules.gd")
const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")


func test_every_kind_of_ground_has_a_colour(test) -> void:
	for folder: String in MinimapRules.KINDS:
		test.check(MapLook.GROUND_COLOURS.has(MinimapRules.KINDS[folder]), "%s: de soort %s heeft een kleur" % [folder, MinimapRules.KINDS[folder]])
	test.check(MapLook.GROUND_COLOURS.has(MinimapRules.DEFAULT_KIND) and MapLook.GROUND_COLOURS.has(MinimapRules.BUILDING_KIND), "ook onbekende grond en een gebouw")


func test_colours_can_be_told_apart(test) -> void:
	var colours: Array = MapLook.GROUND_COLOURS.values()
	var different := true
	for first in colours.size():
		for second in range(first + 1, colours.size()):
			different = different and colours[first] != colours[second]
	test.check(different, "elke soort grond zijn eigen kleur")
	test.check(not colours.has(MapLook.EMPTY), "een lege cel is geen grond")
	test.check(MapLook.WAYPOINT_COLOUR != MapLook.EXIT_MARK_COLOUR and MapLook.WAYPOINT_COLOUR != QuestMarks.COLOUR and MapLook.EXIT_MARK_COLOUR != QuestMarks.COLOUR, "marker, uitgang en questplek elk hun kleur")
