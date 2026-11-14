extends RefCounted
## Unit tests of where the parts of the HUD stand (scripts/ui/hud/hud_layout.gd).
##   tests/run_unit_tests.sh hud_layout

const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")


func test_scale_is_the_smaller_ratio(test) -> void:
	test.check(HudLayout.scale_factor(HudLayout.DESIGN_SIZE) == 1.0, "het venster van het ontwerp: niet geschaald")
	test.check(HudLayout.scale_factor(Vector2(2560.0, 1440.0)) == 2.0, "twee keer zo groot: twee keer")
	test.check(HudLayout.scale_factor(Vector2(2560.0, 720.0)) == 1.0, "breder dan hoog: de hoogte telt")
	test.check(HudLayout.scale_factor(Vector2(640.0, 720.0)) == 0.5, "smaller: de breedte telt")


func test_design_area_gives_the_corners_room(test) -> void:
	test.check(HudLayout.design_area(HudLayout.DESIGN_SIZE) == HudLayout.DESIGN_SIZE, "het ontwerp zelf")
	test.check(HudLayout.design_area(Vector2(2560.0, 1440.0)) == HudLayout.DESIGN_SIZE, "zelfde verhouding: zelfde vlak")
	test.check(HudLayout.design_area(Vector2(2560.0, 720.0)) == Vector2(2560.0, 720.0), "een breed venster: meer ruimte opzij")


func test_parts_stay_in_their_corners(test) -> void:
	var area := HudLayout.DESIGN_SIZE
	test.check(HudLayout.player_frame_position() == Vector2(24.0, 24.0), "het spelerskader linksboven")
	test.check(HudLayout.notice_position(area) == Vector2(280.0, 34.0), "de melding midden bovenin (%s)" % HudLayout.notice_position(area))
	test.check(HudLayout.minimap_position(area) == Vector2(1056.0, 24.0), "de minimap rechtsboven (%s)" % HudLayout.minimap_position(area))
	test.check(HudLayout.tracker_position(area) == Vector2(956.0, 356.0), "de tracker rechts onder de minimap (%s)" % HudLayout.tracker_position(area))
	test.check(HudLayout.money_position(area, Vector2(120.0, 40.0)) == Vector2(1136.0, 652.0), "het geld rechtsonder (%s)" % HudLayout.money_position(area, Vector2(120.0, 40.0)))
	test.check(HudLayout.actions_position(area, Vector2(200.0, 60.0)) == Vector2(24.0, 632.0), "de acties linksonder (%s)" % HudLayout.actions_position(area, Vector2(200.0, 60.0)))


func test_the_column_top_right(test) -> void:
	test.check(HudLayout.map_column_size() == Vector2(200.0, 336.0), "de kolom van locatie, minimap, klok en marker (%s)" % HudLayout.map_column_size())
	test.check(HudLayout.location_size() == Vector2(200.0, 58.0), "de locatie bovenaan, zo breed als de minimap")
	test.check(HudLayout.map_in_column() == Vector2(0.0, 66.0), "de minimap eronder, met een tussenruimte")
	test.check(HudLayout.clock_in_column() == Vector2(0.0, 274.0), "de klok acht pixels onder de minimap (%s)" % HudLayout.clock_in_column())
	test.check(HudLayout.waypoint_in_column() == Vector2(0.0, 304.0), "de marker daaronder (%s)" % HudLayout.waypoint_in_column())
	test.check(HudLayout.waypoint_in_column().y < HudLayout.map_column_size().y, "alles binnen de kolom")


func test_a_wider_window_moves_only_the_right_side(test) -> void:
	var wide := Vector2(1600.0, 720.0)
	test.check(HudLayout.minimap_position(wide).x == 1600.0 - 24.0 - 200.0, "de minimap blijft aan de rechterrand")
	test.check(HudLayout.tracker_position(wide).x + HudLayout.TRACKER_WIDTH == wide.x - HudLayout.MARGIN, "de tracker ook")
	test.check(is_equal_approx(HudLayout.notice_position(wide).x + HudLayout.NOTICE_WIDTH * 0.5, 800.0), "de melding blijft in het midden")
	test.check(HudLayout.actions_position(wide, Vector2(200.0, 60.0)).x == HudLayout.MARGIN, "links verandert er niets")
	test.check(HudLayout.MAP_TOP > HudLayout.LOCATION_HEIGHT, "de minimap staat onder het vak van de locatie")
