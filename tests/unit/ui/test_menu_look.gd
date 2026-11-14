extends RefCounted
## Unit tests of the colours the screens before the game share (scripts/ui/menu/menu_look.gd).
##   tests/run_unit_tests.sh menu_look

const MenuLook = preload("res://scripts/ui/menu/menu_look.gd")


func test_the_colours(test) -> void:
	test.check(MenuLook.SKY.get_luminance() < 0.1 and MenuLook.SKY.a == 1.0, "de nachtlucht is donker en dekkend")
	test.check(MenuLook.STAR_BRIGHT.get_luminance() > MenuLook.STAR_DIM.get_luminance(), "de grote sterren helderder dan de kleine")
	test.check(MenuLook.TITLE_COLOUR.get_luminance() > MenuLook.SOFT_TEXT.get_luminance() and MenuLook.SOFT_TEXT.get_luminance() > MenuLook.MUTED_TEXT.get_luminance(),
		"titel, zachte tekst, gedempte tekst: van licht naar minder licht")
