extends RefCounted
## Unit tests of where the player is, over the minimap (scripts/ui/hud/location.gd): the
## half-second clock, what it shows of a spot, the areas visited and the new ones.
##   tests/run_unit_tests.sh test_location.gd

const Location = preload("res://scripts/ui/hud/location.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Keeps the new areas the location announces.
class Listener:
	var areas: Array = []

	func on_new_area(shown_name: String) -> void:
		areas.append(shown_name)


## A world with two neighbourhoods (cells of 4 m), a street and two places.
static func _world() -> Node:
	var world := Node.new()
	world.set_meta("wijken", [["Centrum", 0, 0, 9, 9], ["Centraal Station", 10, 0, 19, 9]])
	world.set_meta("straten", [["Spui", "x", 4, 5, 0, 9]])
	world.set_meta("places", {"het_plein": Vector2(20.0, 20.0), "centrum": Vector2(4.0, 30.0)})
	return world


func _location(listener: Listener) -> Location:
	var location := Location.new()
	location.new_area_entered.connect(listener.on_new_area)
	tree.root.add_child(location)
	return location


func test_looks_every_half_second(test) -> void:
	var location := _location(Listener.new())
	test.check(location.name == "Locatie" and location.seconds_to_look() == 0.0, "eerst meteen kijken")
	test.check(location.tick(0.1), "de eerste keer: kijken")
	test.check(is_equal_approx(location.seconds_to_look(), Location.INTERVAL), "dan een halve seconde wachten")
	test.check(not location.tick(0.2) and not location.tick(0.2), "nog niet")
	test.check(location.tick(0.2), "na een halve seconde weer")
	location.free()


func test_shows_area_street_and_place(test) -> void:
	var location := _location(Listener.new())
	var world := _world()
	location.look(world, Vector2(18.0, 20.0))
	test.check(location.view.area_text() == "CENTRUM" and location.view.street_text() == "Spui" and location.view.place_text() == "Het Plein", "wijk, straat en plek")
	test.check(location.current_area() == "Centrum", "de wijk waar de speler is")
	location.look(world, Vector2(4.0, 30.0))
	test.check(location.view.place_text() == "", "een plek die heet als de wijk staat er niet nog eens")
	location.place_near = 1.0
	location.look(world, Vector2(18.0, 20.0))
	test.check(location.view.place_text() == "", "de plek te ver weg")
	location.look(null, Vector2(60.0, 20.0))
	test.check(location.view.area_text() == "CENTRUM", "zonder wereld blijft het staan")
	world.free()
	location.free()


func test_a_new_area_is_announced_once(test) -> void:
	var listener := Listener.new()
	var location := _location(listener)
	var world := _world()
	test.check(location.visited_areas().is_empty() and location.current_area() == "", "nog nergens geweest")
	location.look(world, Vector2(18.0, 20.0))
	test.check(listener.areas.is_empty() and location.visited_areas() == ["Centrum"], "de wijk waar het begint is geen nieuw gebied")
	location.look(world, Vector2(60.0, 20.0))
	test.check(listener.areas == ["Station Den Haag Centraal"], "een nieuwe wijk, onder de naam in beeld (%s)" % [listener.areas])
	test.check(location.view.area_text() == "STATION DEN HAAG CENTRAAL" and location.visited_areas() == ["Centrum", "Centraal Station"], "bezocht onder zijn sleutel")
	location.look(world, Vector2(18.0, 20.0))
	location.look(world, Vector2(60.0, 20.0))
	test.check(listener.areas.size() == 1, "terugkomen is geen nieuw gebied")
	location.look(world, Vector2(500.0, 500.0))
	test.check(listener.areas == ["Station Den Haag Centraal", "Den Haag"], "buiten elke wijk: Den Haag")
	world.free()
	location.free()


func test_a_visited_area_is_not_new(test) -> void:
	var listener := Listener.new()
	var location := _location(listener)
	var world := _world()
	location.mark_visited("Centraal Station")
	test.check(location.visited_areas() == ["Centraal Station"], "als bezocht geteld")
	location.look(world, Vector2(18.0, 20.0))
	location.look(world, Vector2(60.0, 20.0))
	test.check(listener.areas.is_empty(), "een wijk die al bezocht was wordt niet gemeld")
	world.free()
	location.free()


func test_inside_a_building(test) -> void:
	var location := _location(Listener.new())
	var world := _world()
	location.tick(0.1)
	test.check(location.indoor_area() == "", "buiten")
	location.set_indoor("Centraal Station")
	test.check(location.indoor_area() == "Centraal Station" and location.seconds_to_look() == 0.0, "binnen: meteen kijken")
	test.check(location.tick(0.016), "bij de volgende stap")
	location.look(world, Vector2(18.0, 20.0))
	test.check(location.view.area_text() == "STATION DEN HAAG CENTRAAL" and location.view.street_text() == "" and location.view.place_text() == "", "de wijk van het gebouw, geen straat of plek")
	location.set_indoor("")
	location.look(world, Vector2(18.0, 20.0))
	test.check(location.view.area_text() == "CENTRUM" and location.view.street_text() == "Spui", "weer buiten")
	world.free()
	location.free()
