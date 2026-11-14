extends RefCounted
## Unit tests of the sizes of the level-up screen (scripts/ui/screens/level_up_screen_layout.gd).
##   tests/run_unit_tests.sh level_up_screen_layout

const LevelUpScreenLayout = preload("res://scripts/ui/screens/level_up_screen_layout.gd")


func test_panel_and_stage(test) -> void:
	test.check(LevelUpScreenLayout.PANEL_SIZE == Vector2(600, 0), "het paneel 600 breed, zo hoog als wat erin staat")
	test.check(LevelUpScreenLayout.panel_margin_top() == 18.0, "boven en onder driekwart van de marge opzij")
	test.check(LevelUpScreenLayout.stage_size() == Vector2(552, 110), "het podium zo breed als het paneel binnen zijn marges")


func test_on_screen(test) -> void:
	test.check(LevelUpScreenLayout.on_screen(Transform2D.IDENTITY, Vector2(100, 40)) == Rect2(0, 0, 100, 40), "zonder verschuiving: op de oorsprong")
	var moved := Transform2D(0.0, Vector2(30, 50))
	test.check(LevelUpScreenLayout.on_screen(moved, Vector2(100, 40)) == Rect2(30, 50, 100, 40), "verschoven: daar")
	var scaled := Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(10, 20))
	test.check(LevelUpScreenLayout.on_screen(scaled, Vector2(100, 40)).is_equal_approx(Rect2(10, 20, 200, 80)), "geschaald: zo groot als in het venster")


func test_index_at(test) -> void:
	var rectangles := [Rect2(0, 0, 100, 40), Rect2(0, 50, 100, 40), Rect2(0, 100, 100, 40)]
	test.check(LevelUpScreenLayout.index_at(rectangles, Vector2(10, 10)) == 0, "in de eerste")
	test.check(LevelUpScreenLayout.index_at(rectangles, Vector2(50, 120)) == 2, "in de derde")
	test.check(LevelUpScreenLayout.index_at(rectangles, Vector2(50, 45)) == -1, "ertussen: geen")
	test.check(LevelUpScreenLayout.index_at(rectangles, Vector2(-500, -500)) == -1, "ver weg: geen")
	test.check(LevelUpScreenLayout.index_at([], Vector2.ZERO) == -1, "geen rijen: geen")
	test.check(LevelUpScreenLayout.index_at([Rect2(0, 0, 10, 10), Rect2(0, 0, 10, 10)], Vector2(5, 5)) == 0, "over elkaar: de eerste")
