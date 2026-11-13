extends RefCounted
## Unit tests of the plans of the city hall (scripts/world/city_hall_layout.gd): five floors,
## each its own layout, not all the same size, the lift in one place on all of them, and a
## reception by the door on the ground floor.

const Layout = preload("res://scripts/world/city_hall_layout.gd")


## The kinds of tile of a floor plan that make its layout (not the walls, not the lift).
static func _furnishing(plan: Dictionary) -> Array:
	var kinds := {}
	for entry: Array in plan.tiles:
		if String(entry[0]) not in ["muur", "muur_laag", "lift"]:
			kinds[String(entry[0])] = true
	return kinds.keys()


## The city hall has five floors.
func test_five_floors(test) -> void:
	test.check(Layout.floors().size() == 5, "vijf etages")


## No two floors are furnished with the same kinds of tile.
func test_every_floor_has_its_own_layout(test) -> void:
	var layouts := {}
	for plan: Dictionary in Layout.floors():
		layouts[str(_furnishing(plan))] = true
	test.check(layouts.size() == 5, "elke etage een andere inrichting (%d)" % layouts.size())


## The floors come in at least three different sizes.
func test_floors_are_not_all_the_same_size(test) -> void:
	var sizes := {}
	for plan: Dictionary in Layout.floors():
		sizes["%dx%d" % [int(plan.width), int(plan.depth)]] = true
	test.check(sizes.size() >= 3, "niet allemaal even groot (%s)" % [sizes.keys()])


## The lift stands at the same place (across the building) on every floor.
func test_lift_in_the_same_place_on_every_floor(test) -> void:
	var lifts := {}
	for plan: Dictionary in Layout.floors():
		lifts[(plan.lift as Vector3).x] = true
	test.check(lifts.size() == 1, "de lift op elke etage op dezelfde plek")


## The ground floor has the door and a reception.
func test_ground_floor_has_door_and_reception(test) -> void:
	var ground: Dictionary = Layout.floors()[0]
	test.check(ground.has("door") and ground.tiles.any(func(entry: Array) -> bool: return entry[0] == "receptie"), "een receptie op de begane grond")
