extends RefCounted
## Unit tests of the picture of the notice of the HUD (scripts/ui/hud/notice_banner_view.gd).
##   tests/run_unit_tests.sh notice_banner_view

const NoticeBannerView = preload("res://scripts/ui/hud/notice_banner_view.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Counts the times a notice has gone.
class Counter:
	var count := 0

	func add() -> void:
		count += 1


func test_shows_a_heading_over_a_name(test) -> void:
	var view := NoticeBannerView.new()
	tree.root.add_child(view)
	var gone := Counter.new()
	test.check(view.size.x == HudLayout.NOTICE_WIDTH and view.heading_text() == "" and view.name_text() == "", "leeg, zo breed als de HUD ervoor vrijhoudt")
	view.show_notice("— NIEUW GEBIED ONTDEKT —", "Centrum", 4.0, gone.add)
	test.check(view.heading_text() == "— NIEUW GEBIED ONTDEKT —" and view.name_text() == "Centrum", "kop en naam")
	test.check(view.modulate.a == 0.0 and gone.count == 0, "ze komt op vanuit niets en is nog niet weg")
	view.show_notice("— NIEUWE MISSIE —", "Lege maag", 4.5, gone.add)
	test.check(view.name_text() == "Lege maag" and gone.count == 0, "een nieuwe breekt de vorige af zonder dat die 'weg' meldt")
	view.stop()
	view.stop()
	test.check(view.name_text() == "Lege maag", "stoppen laat de tekst staan (ook twee keer)")
	view.free()


func test_outside_the_tree_it_only_shows_the_texts(test) -> void:
	var view := NoticeBannerView.new()
	var gone := Counter.new()
	view.show_notice("KOP", "Naam", 1.0, gone.add)
	test.check(view.heading_text() == "KOP" and view.name_text() == "Naam" and gone.count == 0, "de teksten staan er, zonder fade")
	view.free()
