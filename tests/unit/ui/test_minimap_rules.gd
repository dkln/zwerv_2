extends RefCounted
## Unit tests of the rules of the minimap (scripts/ui/hud/minimap_rules.gd): the kind of a
## tile, the picture of the town as plain data, and where the map and a mark land.
##   tests/run_unit_tests.sh minimap_rules

const MinimapRules = preload("res://scripts/ui/hud/minimap_rules.gd")


func test_kind_of_a_tile_by_its_folder(test) -> void:
	test.check(MinimapRules.kind_of("weg/asfalt") == "road" and MinimapRules.kind_of("snelweg/baan") == "road", "wegen")
	test.check(MinimapRules.kind_of("fietspad/rood") == "cycle_path", "een fietspad")
	test.check(MinimapRules.kind_of("water/gracht") == "water" and MinimapRules.kind_of("zwembad/bad") == "water", "water")
	test.check(MinimapRules.kind_of("stoep/tegel") == "pavement" and MinimapRules.kind_of("plein/klinkers") == "pavement", "stoep en plein")
	test.check(MinimapRules.kind_of("spoor/rails") == "rail" and MinimapRules.kind_of("tram/rails") == "rail", "spoor")
	test.check(MinimapRules.kind_of("natuur/bos") == "grass", "natuur is groen")
	test.check(MinimapRules.kind_of("natuur/pad_recht") == "pavement" and MinimapRules.kind_of("natuur/grind") == "pavement", "een pad door de natuur is stoep")
	test.check(MinimapRules.kind_of("plein/gras") == "grass" and MinimapRules.kind_of("weg/parkrand") == "grass", "gras en park gaan voor de map")
	test.check(MinimapRules.kind_of("iets/anders") == MinimapRules.DEFAULT_KIND and MinimapRules.kind_of("") == "land", "onbekend: land")


func test_top_cells_at_street_level(test) -> void:
	var top := MinimapRules.top_cells([Vector3i(0, 0, 0), Vector3i(0, -1, 0), Vector3i(1, -2, 0), Vector3i(1, -1, 0), Vector3i(2, 1, 0), Vector3i(3, 0, 5), Vector3i(3, 2, 5)])
	test.check(top.size() == 3, "een cel per kolom, niets boven straatniveau (%d)" % top.size())
	test.check(top[Vector2i(0, 0)] == Vector3i(0, 0, 0) and top[Vector2i(1, 0)] == Vector3i(1, -1, 0), "de hoogste op of onder straatniveau")
	test.check(top[Vector2i(3, 5)] == Vector3i(3, 0, 5) and not top.has(Vector2i(2, 0)), "een brugdek telt niet")
	test.check(MinimapRules.top_cells([]).is_empty(), "geen cellen: niets")


func test_bounds_of_the_columns(test) -> void:
	test.check(MinimapRules.bounds([Vector2i(-2, 3), Vector2i(4, 1), Vector2i(0, 7)]) == Rect2i(-2, 1, 7, 7), "van de laagste tot en met de hoogste kolom")
	test.check(MinimapRules.bounds([Vector2i(5, 5)]) == Rect2i(5, 5, 1, 1), "een kolom: een pixel")
	test.check(MinimapRules.bounds([]) == Rect2i(), "geen kolommen: niets")


func test_pixel_kinds_put_buildings_over_the_ground(test) -> void:
	var map_bounds := Rect2i(10, 20, 3, 2)
	var kinds := MinimapRules.pixel_kinds({Vector2i(10, 20): "road", Vector2i(12, 21): "grass"},
			[Vector3i(12, 0, 21), Vector3i(11, 3, 20), Vector3i(13, 0, 20), Vector3i(9, 0, 20), Vector3i(10, 0, 22)], map_bounds)
	test.check(kinds[Vector2i(0, 0)] == "road", "de grond op zijn pixel vanaf de hoek")
	test.check(kinds[Vector2i(2, 1)] == MinimapRules.BUILDING_KIND, "een gebouw gaat over de grond")
	test.check(kinds[Vector2i(1, 0)] == MinimapRules.BUILDING_KIND, "ook waar geen grond ligt, op elke hoogte")
	test.check(kinds.size() == 3, "gebouwen buiten de kaart tellen niet (%d)" % kinds.size())


func test_origin_of_the_picture(test) -> void:
	test.check(MinimapRules.origin(Vector2i(-3, 5), 4.0, Vector2.ZERO) == Vector2(-12.0, 20.0), "de hoek van de laagste cel")
	test.check(MinimapRules.origin(Vector2i(0, 0), 4.0, Vector2(10.0, 20.0)) == Vector2(10.0, 20.0), "vanaf waar de GridMap staat")


func test_shrouded_pixels(test) -> void:
	# the story has opened the cells with x >= 6
	var hidden := MinimapRules.shrouded_pixels(Vector2i(3, 2), Vector2i(5, 9), func(cell_x: int, _cell_z: int) -> bool: return cell_x >= 6)
	test.check(hidden == [Vector2i(0, 0), Vector2i(0, 1)], "de pixels van de dichte cellen, rij voor rij (%s)" % [hidden])
	test.check(MinimapRules.shrouded_pixels(Vector2i(3, 2), Vector2i.ZERO, func(_cell_x: int, _cell_z: int) -> bool: return true).is_empty(), "alles open: niets verhuld")
	test.check(MinimapRules.shrouded_pixels(Vector2i(3, 2), Vector2i.ZERO, func(_cell_x: int, _cell_z: int) -> bool: return false).size() == 6, "alles dicht: elke pixel")


func test_metres_across(test) -> void:
	test.check(MinimapRules.metres_across(0.0, 160.0) == 160.0, "in de stad: de gewone maat")
	test.check(MinimapRules.metres_across(40.0, 160.0) == 40.0, "binnen: de maat van de plattegrond")
	test.check(is_equal_approx(MinimapRules.interior_metres(Vector2(60.0, 40.0), 160.0), 66.0), "iets ruimer dan de langste kant")
	test.check(MinimapRules.interior_metres(Vector2(8.0, 6.0), 160.0) == MinimapRules.INTERIOR_MIN_METRES, "een snackbar: niet kleiner dan de kleinste maat")
	test.check(MinimapRules.interior_metres(Vector2(300.0, 100.0), 160.0) == 160.0, "een station: niet meer dan de stad laat zien")
	test.check(MinimapRules.pixels_per_metre(200.0, 160.0) == 1.25, "pixels per meter")


func test_map_and_marks_round_the_player(test) -> void:
	var centre := Vector2(100.0, 100.0)
	test.check(MinimapRules.map_size(Vector2(50.0, 30.0), 1.25, 4.0) == Vector2(250.0, 150.0), "de kaart zo groot als zijn cellen in beeld zijn")
	test.check(MinimapRules.map_position(centre, Vector2(40.0, 20.0), Vector2.ZERO, 1.25) == Vector2(50.0, 75.0), "de speler in het midden")
	test.check(MinimapRules.map_position(centre, Vector2(40.0, 20.0), Vector2(40.0, 20.0), 1.25) == centre, "op de hoek van de kaart: de hoek in het midden")
	test.check(MinimapRules.mark_position(centre, Vector2(40.0, 20.0), Vector2(40.0, 20.0), 1.25) == centre, "een plek waar de speler staat: in het midden")
	test.check(MinimapRules.mark_position(centre, Vector2(40.0, 20.0), Vector2(60.0, 0.0), 1.25) == Vector2(125.0, 75.0), "een plek naar het noordoosten: rechtsboven")
	test.check(MinimapRules.flat(Vector3(3.0, 9.0, -4.0)) == Vector2(3.0, -4.0), "x en z van een punt")


func test_arrow_points_along_the_heading(test) -> void:
	test.check(not MinimapRules.has_heading(Vector2.ZERO) and not MinimapRules.has_heading(Vector2(0.001, 0.0)), "geen richting: de pijl blijft staan")
	test.check(MinimapRules.has_heading(Vector2(0.0, -1.0)), "een richting")
	test.check(is_zero_approx(MinimapRules.arrow_rotation(Vector2(0.0, -1.0))), "naar het noorden (-z): omhoog")
	test.check(is_equal_approx(MinimapRules.arrow_rotation(Vector2(1.0, 0.0)), PI * 0.5), "naar het oosten: een kwartslag")
	test.check(is_equal_approx(absf(MinimapRules.arrow_rotation(Vector2(0.0, 1.0))), PI), "naar het zuiden: omlaag")


func test_which_places_are_marked(test) -> void:
	test.check(MinimapRules.is_target_marked(false, 900.0, false), "buiten: een open plek, hoe ver ook")
	test.check(not MinimapRules.is_target_marked(false, 10.0, true), "buiten: niet onder de sluier")
	test.check(MinimapRules.is_target_marked(true, MinimapRules.INDOOR_TARGET_REACH, true), "binnen: een plek in het gebouw")
	test.check(not MinimapRules.is_target_marked(true, MinimapRules.INDOOR_TARGET_REACH + 1.0, false), "binnen: niet een plek in de stad")
	test.check(MinimapRules.is_waypoint_marked(Vector2(5.0, 5.0), false), "de marker buiten")
	test.check(not MinimapRules.is_waypoint_marked(Vector2(5.0, 5.0), true), "niet op een plattegrond")
	test.check(not MinimapRules.is_waypoint_marked(Vector2.INF, false), "geen marker: niets")
