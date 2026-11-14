extends RefCounted
## Unit tests of the rules of where the player is (scripts/ui/hud/location_rules.gd): the
## neighbourhood, the street and the nearest place of a spot, from plain tables.
##   tests/run_unit_tests.sh location_rules

const LocationRules = preload("res://scripts/ui/hud/location_rules.gd")

const AREAS := [["Centrum", 0, 0, 9, 9], ["Centraal Station", 10, 0, 19, 9], ["Den Haag", 0, 0, 49, 49]]
## Spui runs along z (its lanes x 4..5, z 0..9); Kalvermarkt along x (its lanes z 7..7, x 0..9).
const STREETS := [["Spui", "x", 4, 5, 0, 9], ["Kalvermarkt", "z", 7, 7, 0, 9]]
const PLACES := {"het_plein": Vector2(20.0, 20.0), "ministerie_van_financien": Vector2(60.0, 20.0),
	"verkeerslichten_test": Vector2(21.0, 20.0), "derrek_3": Vector2(100.0, 100.0)}


func test_cell_of_a_world_point(test) -> void:
	test.check(LocationRules.cell_of(Vector2(8.0, 22.0)) == Vector2(2.0, 5.5), "cellen van 4 m")


func test_area_at_a_cell(test) -> void:
	test.check(LocationRules.area_at(AREAS, Vector2(3.0, 3.0)) == "Centrum", "in het Centrum")
	test.check(LocationRules.area_at(AREAS, Vector2(9.9, 9.9)) == "Centrum", "tot en met de laatste cel")
	test.check(LocationRules.area_at(AREAS, Vector2(10.0, 3.0)) == "Centraal Station", "de volgende wijk")
	test.check(LocationRules.area_at(AREAS, Vector2(30.0, 30.0)) == "Den Haag", "de eerste wijk waar het in ligt")
	test.check(LocationRules.area_at(AREAS, Vector2(-5.0, 3.0)) == LocationRules.WHOLE_CITY and LocationRules.area_at([], Vector2.ZERO) == "Den Haag", "in geen wijk: Den Haag")


func test_area_display_name(test) -> void:
	test.check(LocationRules.area_display_name("Centraal Station") == "Station Den Haag Centraal", "het station onder zijn eigen naam")
	test.check(LocationRules.area_display_name("Centrum") == "Centrum", "een gewone wijk onder zijn sleutel")


func test_street_at_a_cell(test) -> void:
	test.check(LocationRules.street_at(STREETS, Vector2(4.5, 2.0)) == "Spui", "op de rijbaan")
	test.check(LocationRules.street_at(STREETS, Vector2(3.5, 2.0)) == "Spui" and LocationRules.street_at(STREETS, Vector2(6.5, 2.0)) == "Spui", "op de stoep ernaast")
	test.check(LocationRules.street_at(STREETS, Vector2(2.5, 2.0)) == "", "verder weg: geen straat")
	test.check(LocationRules.street_at(STREETS, Vector2(4.5, 10.5)) == "", "voorbij het eind van de straat")
	test.check(LocationRules.street_at(STREETS, Vector2(1.0, 7.5)) == "Kalvermarkt", "een straat langs de andere as")
	test.check(LocationRules.street_at(STREETS, Vector2(3.5, 7.5)) == "Kalvermarkt", "de rijbaan van de ene gaat voor de stoep van de andere")
	test.check(LocationRules.street_at(STREETS, Vector2(4.5, 7.5)) == "Spui", "op een kruising: de eerste in de lijst")
	test.check(LocationRules.street_at([], Vector2(4.5, 2.0)) == "", "geen straten: niets")


func test_place_name_from_its_key(test) -> void:
	test.check(LocationRules.place_name("ministerie_van_financien") == "Ministerie van Financien", "kleine woorden blijven klein")
	test.check(LocationRules.place_name("a12_koningskade") == "A12 Koningskade", "een cijfer in een woord blijft")
	test.check(LocationRules.place_name("derrek_3") == "Derrek", "de derde van een keten is gewoon zijn naam")
	test.check(LocationRules.place_name("de_passage") == "De Passage", "het eerste woord krijgt altijd een hoofdletter")
	test.check(LocationRules.place_name("7") == "7" and LocationRules.place_name("") == "", "een los cijfer en niets")


func test_nearest_place(test) -> void:
	test.check(LocationRules.nearest_place(PLACES, Vector2(22.0, 20.0), 45.0) == "Het Plein", "de dichtste plek, geen proefplek van de bouwer")
	test.check(LocationRules.nearest_place(PLACES, Vector2(50.0, 20.0), 45.0) == "Ministerie van Financien", "verderop een andere")
	test.check(LocationRules.nearest_place(PLACES, Vector2(300.0, 300.0), 45.0) == "", "niets in de buurt")
	test.check(LocationRules.nearest_place(PLACES, Vector2(65.0, 20.0), 5.0) == "", "precies op de grens telt niet")
	test.check(LocationRules.nearest_place({}, Vector2.ZERO, 45.0) == "", "geen plekken")


func test_where_the_player_is(test) -> void:
	var outside := LocationRules.where(AREAS, STREETS, PLACES, Vector2(18.0, 20.0), 45.0)
	test.check(outside == {"wijk": "Centrum", "shown_name": "Centrum", "street": "Spui", "place": "Het Plein"}, "wijk, straat en plek (%s)" % outside)
	var station := LocationRules.where(AREAS, STREETS, PLACES, Vector2(60.0, 20.0), 45.0)
	test.check(station.wijk == "Centraal Station" and station.shown_name == "Station Den Haag Centraal", "een wijk met een eigen naam in beeld")
	var inside := LocationRules.where(AREAS, STREETS, PLACES, Vector2(18.0, 20.0), 45.0, "Centraal Station")
	test.check(inside == {"wijk": "Centraal Station", "shown_name": "Station Den Haag Centraal", "street": "", "place": ""}, "binnen: de wijk van het gebouw, geen straat of plek (%s)" % inside)


func test_place_line_only_when_it_says_something_new(test) -> void:
	test.check(LocationRules.is_place_shown("Het Plein", "Centrum", "Centrum", "Spui"), "een plek met een eigen naam")
	test.check(not LocationRules.is_place_shown("", "Centrum", "Centrum", "Spui"), "geen plek")
	test.check(not LocationRules.is_place_shown("centrum", "Centrum", "Centrum", ""), "dezelfde naam als de wijk")
	test.check(not LocationRules.is_place_shown("Station Den Haag Centraal", "Centraal Station", "Station Den Haag Centraal", ""), "dezelfde naam als de wijk in beeld")
	test.check(not LocationRules.is_place_shown("Spui", "Centrum", "Centrum", "SPUI"), "dezelfde naam als de straat")


func test_new_area_only_the_first_time(test) -> void:
	test.check(LocationRules.is_new_area("Laak", "Centrum", ["Centrum"]), "een wijk voor het eerst")
	test.check(not LocationRules.is_new_area("Laak", "Centrum", ["Centrum", "Laak"]), "al eens geweest")
	test.check(not LocationRules.is_new_area("Centrum", "", []), "de wijk waar het spel begint")
	test.check(not LocationRules.is_new_area("Centrum", "Centrum", []), "dezelfde wijk")


func test_fitting_font_size(test) -> void:
	# a text ten times as wide as its font size
	var width_at := func(font_size: int) -> float: return font_size * 10.0
	test.check(LocationRules.fitting_font_size(200.0, width_at) == LocationRules.AREA_FONT_SIZE, "het past: de gewone maat")
	test.check(LocationRules.fitting_font_size(95.0, width_at) == 9, "te lang: de grootste maat die past")
	test.check(LocationRules.fitting_font_size(10.0, width_at) == LocationRules.AREA_SMALLEST_FONT_SIZE, "past nooit: de kleinste")
