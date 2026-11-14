extends RefCounted
## Unit tests of the rules of the marker set on the map (scripts/ui/hud/waypoint_rules.gd).
##   tests/run_unit_tests.sh waypoint_rules

const WaypointRules = preload("res://scripts/ui/hud/waypoint_rules.gd")


func test_texts_of_the_chip(test) -> void:
	test.check(WaypointRules.chip_text("Het Plein") == "HET PLEIN", "net gezet: de naam in hoofdletters")
	test.check(WaypointRules.distance_text("Derrek", 69.6) == "DERREK · 70 M", "onderweg: met de afstand, afgerond")
	test.check(WaypointRules.distance_text("Derrek", 0.2) == "DERREK · 0 M", "vlakbij")
	test.check(WaypointRules.arrived_text("Het Plein") == "Aangekomen: Het Plein", "aangekomen: de naam zoals hij is")


func test_arrived_within_eight_metres(test) -> void:
	test.check(WaypointRules.has_arrived(0.0) and WaypointRules.has_arrived(WaypointRules.ARRIVED), "tot en met acht meter: er")
	test.check(not WaypointRules.has_arrived(WaypointRules.ARRIVED + 0.1), "verder: nog niet")
	test.check(WaypointRules.NONE == Vector2.INF, "geen marker is nergens")
