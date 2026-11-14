extends RefCounted
## Unit tests of the picture of the location over the minimap (scripts/ui/hud/location_view.gd).
##   tests/run_unit_tests.sh location_view

const LocationView = preload("res://scripts/ui/hud/location_view.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_three_lines_in_a_box_as_wide_as_the_minimap(test) -> void:
	var view := LocationView.new()
	tree.root.add_child(view)
	test.check(view.size == HudLayout.location_size() and view.area_text() == "DEN HAAG", "een vak zo breed als de minimap, eerst Den Haag")
	test.check(view.street_text() == "" and view.place_text() == "", "nog geen straat of plek")
	view.show_location("CENTRUM", "Spui", "Het Plein", true)
	test.check(view.area_text() == "CENTRUM" and view.street_text() == "Spui" and view.place_text() == "Het Plein", "wijk, straat en plek")
	view.show_location("CENTRUM", "", "Het Plein", false)
	test.check(view.street_text() == "" and view.place_text() == "", "geen straat, en de plek verborgen")
	view.free()


func test_font_size_of_the_area(test) -> void:
	var view := LocationView.new()
	tree.root.add_child(view)
	test.check(view.area_font_size() == 11, "de gewone maat")
	view.show_area_font_size(8)
	test.check(view.area_font_size() == 8, "kleiner voor een lange naam")
	test.check(view.area_width("STATION DEN HAAG CENTRAAL", 11) > view.area_width("STATION DEN HAAG CENTRAAL", 8), "een kleinere letter is smaller")
	test.check(view.area_width("CENTRUM", 11) < view.area_width("STATION DEN HAAG CENTRAAL", 11) and view.area_room() >= 0.0, "een korte naam is smaller")
	view.free()
