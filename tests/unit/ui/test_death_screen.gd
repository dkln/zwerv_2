extends RefCounted
## Unit tests of the death screen (scripts/ui/screens/death_screen.gd) on its own, without
## the HUD or the town.
##   tests/run_unit_tests.sh death_screen

const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_death_reason_names_who_and_how(test) -> void:
	test.check(DeathScreen.reason("honger", "Sjaan") == "Sjaan is van de honger omgekomen.", "van de honger")
	test.check(DeathScreen.reason("verdronken", "Kees").begins_with("Kees is in het water gevallen"), "verdronken")
	test.check(DeathScreen.reason("", "Kees") == "Kees heeft het niet gered.", "geen oorzaak: een algemene regel")
	test.check(DeathScreen.reason("onbekend", "Kees") == "Kees heeft het niet gered.", "een onbekende oorzaak: ook")
	for cause: String in DeathScreen.CAUSES:
		test.check(String(DeathScreen.CAUSES[cause]).count("%s") == 1, "%s: één plek voor de naam" % cause)


func test_death_screen_opens_once_and_keys_wait(test) -> void:
	var screen := DeathScreen.new()
	tree.root.add_child(screen)
	test.check(not screen.is_open() and not screen.keys_ready(), "eerst niet te zien")
	test.check(screen.open("aangereden", "Sjaan"), "het scherm gaat open")
	test.check(screen.is_open() and screen._reason.text == "Sjaan is aangereden en niet meer opgestaan.", "met hoe het gebeurde")
	test.check(screen.modulate.a == 0.0, "het komt op vanuit niets")
	test.check(not screen.open("honger", "Sjaan") and screen._reason.text.contains("aangereden"), "een tweede keer: het blijft zoals het is")
	test.check(not screen.keys_ready(), "de toetsen werken nog niet meteen")
	# (a little more than the wait: the clock is a float, exactly KEYS_AFTER back can round to just under it)
	screen._since -= DeathScreen.KEYS_AFTER + 0.01
	test.check(screen.keys_ready(), "na de wachttijd wel")
	screen.free()
