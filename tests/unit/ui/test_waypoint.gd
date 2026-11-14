extends RefCounted
## Unit tests of the marker set on the map (scripts/ui/hud/waypoint.gd): set and cleared,
## its beam in the town, its chip while under way, and arriving.
##   tests/run_unit_tests.sh test_waypoint.gd

const Waypoint = preload("res://scripts/ui/hud/waypoint.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Keeps the arrivals the marker tells of.
class Listener:
	var arrivals: Array = []

	func on_arrived(place_name: String, focus: Vector3) -> void:
		arrivals.append([place_name, focus])


## A marker in a town of its own (the beam goes into the town).
func _marker(listener: Listener) -> Waypoint:
	var town := Node3D.new()
	tree.root.add_child(town)
	var marker := Waypoint.new()
	marker.town = town
	marker.arrived.connect(listener.on_arrived)
	town.add_child(marker)
	return marker


func test_set_and_cleared(test) -> void:
	var marker := _marker(Listener.new())
	test.check(marker.name == "Marker" and not marker.is_set() and marker.at() == Vector2.INF and marker.place_name() == "" and not marker.visible, "eerst geen marker")
	test.check(marker.beacon() == null, "en geen baken")
	marker.set_at(Vector2(120.0, -40.0), "Het Plein")
	test.check(marker.is_set() and marker.at() == Vector2(120.0, -40.0) and marker.place_name() == "Het Plein", "een marker gezet")
	test.check(marker.visible and marker.view.shown_text() == "HET PLEIN", "met zijn naam in beeld")
	var beacon := marker.beacon()
	test.check(beacon != null and beacon.get_parent() == marker.town and beacon.global_position == Vector3(120.0, 0.0, -40.0), "zijn baken in de stad, op de grond")
	marker.set_at(Vector2(5.0, 6.0), "Station")
	test.check(marker.beacon() == beacon and beacon.global_position == Vector3(5.0, 0.0, 6.0) and marker.view.shown_text() == "STATION", "een nieuwe plek: hetzelfde baken verzet")
	marker.clear()
	test.check(not marker.is_set() and marker.place_name() == "" and not marker.visible and marker.beacon() == null, "en weer weg")
	test.check(beacon.is_queued_for_deletion(), "het baken wordt opgeruimd")
	marker.town.free()


func test_distance_while_under_way(test) -> void:
	var listener := Listener.new()
	var marker := _marker(listener)
	marker.follow(Vector3.ZERO, true)
	test.check(marker.view.shown_text() == "", "zonder marker gebeurt er niets")
	marker.set_at(Vector2(150.0, 170.0), "Derrek")
	marker.follow(Vector3(150.0, 0.0, 100.0), true)
	test.check(marker.view.shown_text() == "DERREK · 70 M" and marker.beacon().visible, "de afstand onder het kaartje")
	marker.follow(Vector3(150.0, 0.0, 20.0), false)
	test.check(marker.view.shown_text() == "DERREK · 70 M" and not marker.beacon().visible and marker.is_set(), "binnen wacht hij, zijn baken verborgen")
	marker.follow(Vector3(150.0, 0.0, 168.0), false)
	test.check(marker.is_set() and listener.arrivals.is_empty(), "binnen kom je niet aan")
	marker.town.free()


func test_arriving_takes_the_marker_away(test) -> void:
	var listener := Listener.new()
	var marker := _marker(listener)
	marker.set_at(Vector2(150.0, 170.0), "Derrek")
	marker.follow(Vector3(150.0, 3.0, 165.0), true)
	test.check(not marker.is_set() and not marker.visible and marker.beacon() == null, "aangekomen: de marker is weg")
	test.check(listener.arrivals == [["Derrek", Vector3(150.0, 3.0, 165.0)]], "en het wordt gemeld, met waar de speler staat (%s)" % [listener.arrivals])
	marker.follow(Vector3(150.0, 3.0, 165.0), true)
	test.check(listener.arrivals.size() == 1, "een keer")
	marker.town.free()


func test_without_a_town_the_beam_stands_nowhere(test) -> void:
	var marker := Waypoint.new()
	marker.set_at(Vector2(1.0, 2.0), "Nergens")
	test.check(marker.is_set() and marker.beacon() != null and not marker.beacon().is_inside_tree(), "een marker zonder stad: het baken staat nergens")
	var beacon := marker.beacon()
	marker.clear()
	beacon.free()
	marker.free()
