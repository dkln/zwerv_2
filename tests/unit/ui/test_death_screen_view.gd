extends RefCounted
## Unit tests of how the death screen looks (scripts/ui/screens/death_screen_view.gd): what
## it builds and what it shows when told, without the behaviour around it.
##   tests/run_unit_tests.sh death_screen_view

const DeathScreenView = preload("res://scripts/ui/screens/death_screen_view.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> DeathScreenView:
	var view := DeathScreenView.new()
	tree.root.add_child(view)
	return view


func test_view_has_the_veil_the_title_and_the_keys(test) -> void:
	var view := _view()
	var veils := view.get_children().filter(func(child: Node) -> bool: return child is ColorRect)
	test.check(veils.size() == 1 and (veils[0] as ColorRect).color == DeathScreenView.VEIL_COLOUR, "de donkerrode sluier")
	test.check(view.title_text() == DeathScreenView.TITLE and view.title_text() == "JE BENT DOOD", "de titel")
	test.check(view.keys_text().contains("ENTER") and view.keys_text().contains("ESC"), "de regel met de toetsen (%s)" % view.keys_text())
	test.check(view.reason_text() == "", "nog geen regel met hoe het gebeurde")
	test.check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "de muis gaat erdoorheen")
	view.free()


func test_show_reason_writes_the_line(test) -> void:
	var view := _view()
	view.show_reason("Sjaan is van de honger omgekomen.")
	test.check(view.reason_text() == "Sjaan is van de honger omgekomen.", "de regel staat er")
	view.show_reason("Kees heeft het niet gered.")
	test.check(view.reason_text() == "Kees heeft het niet gered.", "een nieuwe regel vervangt de oude")
	view.free()


func test_fade_in_starts_from_nothing(test) -> void:
	var view := _view()
	test.check(view.modulate.a == 1.0 and view.keys_shown() == 1.0, "eerst gewoon te zien")
	view.fade_in(1.2)
	test.check(view.modulate.a == 0.0, "het komt op vanuit niets")
	test.check(view.keys_shown() == 0.0, "de toetsen ook, die komen later")
	view.free()
