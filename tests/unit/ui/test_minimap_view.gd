extends RefCounted
## Unit tests of the picture of the minimap (scripts/ui/hud/minimap_view.gd): the pictures
## it paints from plain data, and what it shows of what it is handed.
##   tests/run_unit_tests.sh minimap_view

const MinimapView = preload("res://scripts/ui/hud/minimap_view.gd")
const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const Layout = preload("res://scripts/ui/hud/minimap_layout.gd")


static func _same(first: Color, second: Color) -> bool:
	return absf(first.r - second.r) < 0.01 and absf(first.g - second.g) < 0.01 and absf(first.b - second.b) < 0.01 and absf(first.a - second.a) < 0.01


func test_map_image_paints_each_kind(test) -> void:
	var image := MinimapView.map_image(Vector2i(3, 2), {Vector2i(0, 0): "road", Vector2i(2, 1): "building", Vector2i(1, 1): "water"})
	test.check(image.get_size() == Vector2i(3, 2), "zo groot als gevraagd")
	test.check(_same(image.get_pixel(0, 0), MapLook.GROUND_COLOURS["road"]), "een weg in zijn kleur")
	test.check(_same(image.get_pixel(2, 1), MapLook.GROUND_COLOURS["building"]) and _same(image.get_pixel(1, 1), MapLook.GROUND_COLOURS["water"]), "een gebouw en water")
	test.check(_same(image.get_pixel(1, 0), MapLook.EMPTY), "de rest leeg")


func test_shroud_image_hides_the_closed_pixels(test) -> void:
	test.check(MinimapView.shroud_image(Vector2i(3, 2), []) == null, "niets verhuld: geen sluier")
	var image := MinimapView.shroud_image(Vector2i(3, 2), [Vector2i(0, 0), Vector2i(2, 1)])
	test.check(image.get_size() == Vector2i(3, 2), "zo groot als de kaart")
	test.check(_same(image.get_pixel(0, 0), Color(MapLook.EMPTY, 1.0)) and _same(image.get_pixel(2, 1), Color(MapLook.EMPTY, 1.0)), "dicht: de kleur van de lege kaart")
	test.check(image.get_pixel(1, 0).a == 0.0, "open: doorzichtig")


func test_shows_the_map_where_it_is_told(test) -> void:
	var view := MinimapView.new()
	test.check(view.size == Layout.frame_size() and view.map_texture() == null, "een lege lijst")
	var texture := ImageTexture.create_from_image(MinimapView.map_image(Vector2i(4, 4), {}))
	view.show_map(texture)
	test.check(view.map_texture() == texture, "de kaart")
	view.place_map(Vector2(-20.0, 30.0), Vector2(400.0, 300.0))
	test.check(view.map_rect() == Rect2(-20.0, 30.0, 400.0, 300.0), "waar en hoe groot (%s)" % view.map_rect())
	view.turn_arrow(1.5)
	test.check(view.arrow_angle() == 1.5, "de pijl gedraaid")
	view.free()


func test_shroud_over_the_map(test) -> void:
	var view := MinimapView.new()
	view.show_shroud_over_map(true)
	test.check(not view.is_shroud_over_map(), "zonder sluier niets te zien")
	view.show_shroud(MinimapView.shroud_image(Vector2i(2, 2), [Vector2i(0, 0)]))
	test.check(view.is_shroud_over_map(), "de sluier over de kaart")
	view.show_shroud(MinimapView.shroud_image(Vector2i(2, 2), [Vector2i(1, 1)]))
	test.check(view.is_shroud_over_map(), "een nieuwe sluier van dezelfde maat")
	view.show_shroud_over_map(false)
	test.check(not view.is_shroud_over_map(), "binnen: niet")
	view.show_shroud_over_map(true)
	view.show_shroud(null)
	test.check(not view.is_shroud_over_map(), "alles open: weg")
	view.free()


func test_marks_of_three_kinds(test) -> void:
	var view := MinimapView.new()
	test.check(view.quest_marks().is_empty() and view.exit_marks().is_empty() and view.waypoint_marks().is_empty(), "eerst geen")
	view.show_quest_marks([Vector2(10.0, 10.0), Vector2(50.0, 5.0)])
	view.show_exit_marks([Vector2(20.0, 20.0)])
	view.show_waypoint_marks([Vector2(30.0, 30.0)])
	test.check(view.quest_marks() == [Vector2(10.0, 10.0), Vector2(50.0, 5.0)], "de plekken van de quest")
	test.check(view.exit_marks() == [Vector2(20.0, 20.0)] and view.waypoint_marks() == [Vector2(30.0, 30.0)], "de uitgangen en de marker")
	view.show_waypoint_marks([])
	test.check(view.waypoint_marks().is_empty() and view.quest_marks().size() == 2, "elk los van de andere")
	view.free()
