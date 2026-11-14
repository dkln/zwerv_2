extends RefCounted
## Unit tests of where the places of a quest stand on the minimap
## (scripts/ui/widgets/quest_marks_layout.gd).
##   tests/run_unit_tests.sh quest_marks_layout

const QuestMarksLayout = preload("res://scripts/ui/widgets/quest_marks_layout.gd")


func test_a_place_on_the_minimap_gets_its_diamond(test) -> void:
	var map_size := Vector2(200, 100)
	var inset := QuestMarksLayout.EDGE_INSET
	test.check(QuestMarksLayout.is_on_map(Vector2(100, 50), map_size), "het midden: op de kaart")
	test.check(QuestMarksLayout.is_on_map(Vector2(inset, inset), map_size), "net binnen de rand: nog op de kaart")
	test.check(not QuestMarksLayout.is_on_map(Vector2(inset - 1.0, 50), map_size), "in de rand zelf: niet meer")
	test.check(not QuestMarksLayout.is_on_map(Vector2(200.0 - inset, 50), map_size), "de rechterrand hoort er niet bij")
	test.check(not QuestMarksLayout.is_on_map(Vector2(100, -40), map_size) and not QuestMarksLayout.is_on_map(Vector2(400, 50), map_size), "buiten de kaart: niet")


func test_a_far_place_sits_on_the_edge(test) -> void:
	var map_size := Vector2(200, 100)
	var inset := QuestMarksLayout.EDGE_INSET
	test.check(QuestMarksLayout.edge_place(Vector2(900, 50), map_size) == Vector2(200.0 - inset, 50), "recht naar rechts: op de rechterrand (%s)" % QuestMarksLayout.edge_place(Vector2(900, 50), map_size))
	test.check(QuestMarksLayout.edge_place(Vector2(-900, 50), map_size) == Vector2(inset, 50), "recht naar links: op de linkerrand")
	test.check(QuestMarksLayout.edge_place(Vector2(100, -900), map_size) == Vector2(100, inset), "recht omhoog: op de bovenrand")
	test.check(QuestMarksLayout.edge_place(Vector2(100, 900), map_size) == Vector2(100, 100.0 - inset), "recht omlaag: op de onderrand")
	# from the middle (100, 50) towards (300, 250): 45 degrees, the bottom edge comes first
	test.check(QuestMarksLayout.edge_place(Vector2(300, 250), map_size) == Vector2(100.0 + 50.0 - inset, 100.0 - inset), "schuin: waar de lijn de rand raakt (%s)" % QuestMarksLayout.edge_place(Vector2(300, 250), map_size))
	for point: Vector2 in [Vector2(950, -420), Vector2(-17, 300), Vector2(205, 51), Vector2(-1, -1)]:
		var place := QuestMarksLayout.edge_place(point, map_size)
		var on_edge := is_equal_approx(place.x, inset) or is_equal_approx(place.x, 200.0 - inset) \
				or is_equal_approx(place.y, inset) or is_equal_approx(place.y, 100.0 - inset)
		var inside := place.x >= inset and place.x <= 200.0 - inset and place.y >= inset and place.y <= 100.0 - inset
		test.check(on_edge and inside, "%s: op de rand, binnen de kaart (%s)" % [point, place])
