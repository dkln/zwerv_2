extends RefCounted
## Unit tests of the death screen (scripts/ui/screens/death_screen.gd, the behaviour) on its
## own, without the HUD or the town: it opens once and its keys wait. The line with how it
## happened: test_death_screen_rules.gd; how it looks: test_death_screen_view.gd.
##   tests/run_unit_tests.sh death_screen

const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")
const DeathScreenRules = preload("res://scripts/ui/screens/death_screen_rules.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


static func _key(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_death_screen_opens_once_and_keys_wait(test) -> void:
	var screen := DeathScreen.new()
	tree.root.add_child(screen)
	test.check(screen.name == "Dood" and not screen.is_open() and not screen.keys_ready(), "eerst niet te zien")
	test.check(screen.reason_text() == "", "nog geen regel")
	test.check(screen.open("aangereden", "Sjaan"), "het scherm gaat open")
	test.check(screen.is_open() and screen.reason_text() == "Sjaan is aangereden en niet meer opgestaan.", "met hoe het gebeurde")
	test.check(screen._view.modulate.a == 0.0, "het komt op vanuit niets")
	test.check(not screen.open("honger", "Sjaan") and screen.reason_text().contains("aangereden"), "een tweede keer: het blijft zoals het is")
	test.check(not screen.keys_ready(), "de toetsen werken nog niet meteen")
	# (a little more than the wait: the clock is a float, exactly KEYS_AFTER back can round to just under it)
	screen._since -= DeathScreenRules.KEYS_AFTER + 0.01
	test.check(screen.keys_ready(), "na de wachttijd wel")
	screen.free()


func test_reason_and_causes_are_the_rules(test) -> void:
	test.check(DeathScreen.reason("honger", "Sjaan") == DeathScreenRules.reason("honger", "Sjaan"), "dezelfde regel als de logica")
	test.check(DeathScreen.CAUSES == DeathScreenRules.CAUSES and DeathScreen.CAUSES.has("verdronken"), "dezelfde oorzaken")


func test_keys_do_nothing_before_the_wait_and_other_keys_never(test) -> void:
	var screen := DeathScreen.new()
	tree.root.add_child(screen)
	screen.handle_input(_key("ui_accept"))
	test.check(not screen.is_open(), "dicht: een toets doet niets")
	screen.open("honger", "Sjaan")
	screen.handle_input(_key("ui_accept"))
	test.check(screen.is_open() and screen.is_inside_tree() and screen.get_child_count() == 1, "Enter tijdens de wachttijd: het scherm blijft staan")
	screen._since -= DeathScreenRules.KEYS_AFTER + 0.01
	screen.handle_input(_key("ui_left"))
	test.check(screen.is_open() and screen.get_child_count() == 1, "een andere toets na de wachttijd: ook niets")
	screen.free()
