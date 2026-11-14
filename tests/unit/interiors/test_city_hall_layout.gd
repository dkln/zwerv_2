extends RefCounted
## Unit tests of the plans of the city hall (scripts/world/interiors/city_hall_layout.gd): five floors,
## each its own layout, not all the same size, the lift in one place on all of them, and a
## reception by the door on the ground floor.

const Layout = preload("res://scripts/world/interiors/city_hall_layout.gd")


## The kinds of tile of a floor plan that make its layout (not the walls, not the lift).
static func _furnishing(plan: Dictionary) -> Array:
	var kinds := {}
	for entry: Array in plan.tiles + plan.wall_tiles:
		if String(entry[0]) not in ["muur", "muur_laag", "lift"]:
			kinds[String(entry[0])] = true
	return kinds.keys()


## The city hall has five floors and a basement (the last in the list, level -1).
func test_five_floors_and_a_basement(test) -> void:
	test.check(Layout.floors().size() == 6, "vijf etages en een kelder")
	test.check(Layout.level_of(Layout.BASEMENT) == -1 and Layout.level_of(0) == 0 and Layout.level_of(4) == 4, "de kelder ligt onder de begane grond")
	var basement: Dictionary = Layout.floors()[Layout.BASEMENT]
	var racks: int = (basement.tiles as Array).filter(func(entry: Array) -> bool: return entry[0] == "stelling").size()
	test.check(racks >= 20, "opslag: %d stellingen" % racks)
	test.check((basement.people as Array).any(func(person: Dictionary) -> bool: return person.role == "concierge"), "een conciërge")


## No two floors are furnished with the same kinds of tile.
func test_every_floor_has_its_own_layout(test) -> void:
	var layouts := {}
	for plan: Dictionary in Layout.floors():
		layouts[str(_furnishing(plan))] = true
	test.check(layouts.size() == Layout.floors().size(), "elke etage een andere inrichting (%d)" % layouts.size())


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
