extends RefCounted
## Unit tests of the sizes and places of the player frame (scripts/ui/hud/player_frame_layout.gd).
##   tests/run_unit_tests.sh player_frame_layout

const Layout = preload("res://scripts/ui/hud/player_frame_layout.gd")


func test_portrait_picture_fits_inside_its_border(test) -> void:
	var inner := Layout.portrait_inner()
	test.check(inner.position == Vector2(3.0, 3.0) and inner.size == Vector2(70.0, 70.0), "70 x 70 binnen een rand van 3 (%s)" % inner)
	test.check(is_equal_approx(inner.end.x + Layout.PORTRAIT_BORDER, Layout.PORTRAIT_SIZE), "rechts evenveel rand als links")


func test_badge_sticks_out_of_the_corner(test) -> void:
	var badge_size := Vector2(60.0, 20.0)
	var position := Layout.badge_position(badge_size)
	test.check(position == Vector2(26.0, 66.0), "de rechter- en onderrand 10 px buiten het portret (%s)" % position)
	test.check(is_equal_approx(position.x + badge_size.x, Layout.PORTRAIT_SIZE + Layout.BADGE_OUTSIDE), "ook bij een andere breedte klopt de rechterrand")
	test.check(Layout.badge_position(Vector2(100.0, 20.0)).x < 0.0, "een breed plaatje steekt links uit, niet rechts")


func test_column_stands_beside_the_portrait(test) -> void:
	test.check(Layout.column_position() == Vector2(90.0, 2.0), "naast het portret (%s)" % Layout.column_position())
	test.check(Layout.column_position().x > Layout.PORTRAIT_SIZE, "met ruimte ertussen")
	test.check(Layout.ICON_COLUMN_WIDTH >= 14.0, "de icoonkolom is breed genoeg voor een icoon van 7 pixels op dubbele grootte")
