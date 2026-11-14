extends RefCounted
## Unit tests of how the design of the screens before the game fits the window
## (scripts/ui/menu/screen_layout.gd).
##   tests/run_unit_tests.sh screen_layout

const ScreenLayout = preload("res://scripts/ui/menu/screen_layout.gd")


func test_the_design_fits_the_window_whole(test) -> void:
	test.check(ScreenLayout.scale_in(ScreenLayout.DESIGN_SIZE) == 1.0 and ScreenLayout.position_in(ScreenLayout.DESIGN_SIZE) == Vector2.ZERO, "in zijn eigen maat: precies passend")
	test.check(ScreenLayout.scale_in(Vector2(2560, 1440)) == 2.0 and ScreenLayout.scale_in(Vector2(640, 360)) == 0.5, "groter en kleiner met het venster mee")
	test.check(ScreenLayout.scale_in(Vector2(2560, 720)) == 1.0 and ScreenLayout.position_in(Vector2(2560, 720)) == Vector2(640, 0), "een breed venster: de hoogte bepaalt, in het midden")
	test.check(ScreenLayout.scale_in(Vector2(1280, 1000)) == 1.0 and ScreenLayout.position_in(Vector2(1280, 1000)) == Vector2(0, 140), "een hoog venster: de breedte bepaalt, in het midden")
