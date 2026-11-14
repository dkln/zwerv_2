extends RefCounted
## Unit tests of the tint map (scripts/world/town/tint_map.gd): the visible areas under it are
## rasterised into the map, later ones on top, hidden ones not.

const TintMapView = preload("res://scripts/world/town/tint_map_view.gd")


## True for a pixel without tint (grey, no strength), as 8 bits store it.
func _is_no_tint(pixel: Color) -> bool:
	return absf(pixel.r - TintMapView.NO_TINT.r) < 0.01 and absf(pixel.g - TintMapView.NO_TINT.g) < 0.01 \
			and absf(pixel.b - TintMapView.NO_TINT.b) < 0.01 and pixel.a < 0.01

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _area(at: Vector3, size: Vector2i, colour: Color) -> TintArea:
	var area := TintArea.new()
	area.position = at
	area.size = size
	area.color = colour
	return area


## The areas are in the map when the node comes into the tree.
func test_the_areas_are_rasterised(test) -> void:
	var map := TintMap.new()
	map.area_cells = Vector2i(8, 8)
	map.add_child(_area(Vector3(8.0, 0.0, 6.0), Vector2i(2, 1), Color(1.0, 0.0, 0.0)))
	var hidden := _area(Vector3(22.0, 0.0, 22.0), Vector2i(1, 1), Color(0.0, 1.0, 0.0))
	hidden.visible = false
	map.add_child(hidden)
	map.add_child(_area(Vector3(10.0, 0.0, 6.0), Vector2i(1, 1), Color(0.0, 0.0, 1.0)))
	tree.root.add_child(map)
	test.check(map.view.map_size() == Vector2i(8, 8), "de kaart zo groot als area_cells")
	test.check(map.view.tint_at(Vector2i(1, 1)).r > 0.45, "het eerste gebied: rood")
	test.check(map.view.tint_at(Vector2i(2, 1)).b > 0.45 and map.view.tint_at(Vector2i(2, 1)).r < 0.05, "het latere gebied ligt erbovenop: blauw")
	test.check(_is_no_tint(map.view.tint_at(Vector2i(5, 5))), "een verborgen gebied telt niet")
	test.check(TintMap.CELL == 4.0, "een cel is 4 m")
	map.free()


## In the game the map is baked once: a frame later it is as it was.
func test_in_the_game_the_map_is_baked_once(test) -> void:
	var map := TintMap.new()
	map.area_cells = Vector2i(4, 4)
	var area := _area(Vector3(2.0, 0.0, 2.0), Vector2i(1, 1), Color(1.0, 0.0, 0.0))
	map.add_child(area)
	tree.root.add_child(map)
	area.position = Vector3(10.0, 0.0, 10.0)
	map._process(1.0)
	test.check(map.view.tint_at(Vector2i(0, 0)).r > 0.45 and _is_no_tint(map.view.tint_at(Vector2i(2, 2))),
		"niet opnieuw gebakken in het spel")
	map.variation = 0.5
	test.check(is_equal_approx(map.variation, 0.5), "de variatie is in te stellen")
	map.free()
