extends RefCounted
## Unit tests of scripts/ui/widgets/quest_marks.gd on its own: the places of a quest on the
## minimap (what its drawing depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh quest_marks

const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")


func test_quest_marks_keep_their_points(test) -> void:
	var marks := QuestMarks.new()
	test.check(marks.points.is_empty() and marks.colour == QuestMarks.COLOUR, "eerst geen plekken, amber")
	test.check(marks.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	marks.points = [Vector2(120, 40), Vector2(-30, 10)]
	test.check(marks.points == [Vector2(120, 40), Vector2(-30, 10)], "de plekken staan erin")
	marks._process(0.1)
	marks.points = []
	marks._process(0.1)
	test.check(marks.points.is_empty(), "en weer leeg te maken")
	marks.free()
