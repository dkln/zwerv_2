extends RefCounted
## Unit tests of the sizes of the loading screen (scripts/ui/screens/loading_screen_layout.gd).
##   tests/run_unit_tests.sh loading_screen_layout

const LoadingScreenLayout = preload("res://scripts/ui/screens/loading_screen_layout.gd")


func test_the_bar_and_its_panel(test) -> void:
	test.check(LoadingScreenLayout.SEGMENTS == 30 and LoadingScreenLayout.SEGMENT_HEIGHT == 14, "een balk van dertig blokjes van veertien hoog")
	test.check(LoadingScreenLayout.BOX_MARGIN == 12 and LoadingScreenLayout.BOX_BORDER == 3, "op een paneel met een rand en ruimte erin")
	test.check(LoadingScreenLayout.PERCENTAGE_SIZE.x == 48.0 and LoadingScreenLayout.PERCENTAGE_SIZE.y == 0.0, "het percentage houdt zijn breedte")
	test.check(LoadingScreenLayout.COLUMN_SEPARATION > LoadingScreenLayout.ROW_SEPARATION, "meer ruimte tussen de regels dan naast de balk")
	test.check(LoadingScreenLayout.LAYER == 100, "boven het spel en zijn HUD")
