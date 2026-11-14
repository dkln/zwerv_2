extends RefCounted
## Unit tests of the deposit machine (scripts/ui/machines/deposit_machine_screen.gd) on its
## own, without the swipe (animate off) and with a stand-in player with cans and bottles:
## one in at a time (the count, the pockets), what you do not have, one that comes back out,
## the hole and the BON key (hotspots, the keys, the cursor), the bon printed and paid out,
## leaving with something in it, a machine out of order, and the lines of the bon.
##   tests/run_unit_tests.sh deposit_machine

const DepositMachineScreen = preload("res://scripts/ui/machines/deposit_machine_screen.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A wallet and pockets with cans and bottles, as DepositReturn asks of the player.
class TestPlayer:
	extends Node
	signal deposited(amount: float)
	var money := 1.0
	var inventory := {"blikje": 2, "statiegeld": 1, "kroket": 1}

	func drop_item(item_id: String) -> void:
		inventory[item_id] = int(inventory.get(item_id, 0)) - 1
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)

	func add_money(amount: float) -> void:
		money += amount


## Counts `finished` and what was paid out.
class Listener:
	var finished_calls := 0
	var paid: Array = []

	func on_finished() -> void:
		finished_calls += 1

	func on_deposited(amount: float) -> void:
		paid.append(amount)


func _player() -> TestPlayer:
	var player := TestPlayer.new()
	tree.root.add_child(player)
	return player


## The screen gone at once (close only queues it; a next machine needs its name free), the
## pause back and the player gone.
func _tidy(screen: Node, player: Node, was_paused: bool) -> void:
	if is_instance_valid(screen):
		screen.free()
	tree.paused = was_paused
	player.free()


func test_bon_lines(test) -> void:
	test.check(DepositMachineScreen.bon_lines({"blikje": 2, "statiegeld": 1}, 0.95)
		== ["2 × BLIKJE   € 0,80", "1 × FLES   € 0,15", "----------------", "TOTAAL   € 0,95"], "blikjes eerst, dan flessen, een streep, het totaal")
	test.check(DepositMachineScreen.bon_lines({"statiegeld": 3}, 0.45) == ["3 × FLES   € 0,45", "----------------", "TOTAAL   € 0,45"], "alleen flessen: geen regel voor blikjes")
	test.check(DepositMachineScreen.bon_lines({"blikje": 0}, 0.0) == ["----------------", "TOTAAL   € 0,00"], "niets: alleen het totaal")


func test_the_machine_of_a_supermarket(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "DERREK", false)
	test.check(screen != null and screen.brand == "STATIEGELD" and screen.place_name == "DERREK" and screen.backdrop == "supermarkt", "de statiegeldautomaat van de DERREK")
	test.check(screen.state == "invoeren" and screen._display_title.text == "STATIEGELD" and screen._display_text.text == "0 STUKS\n€ 0,00", "leeg: nul stuks")
	test.check(screen.display_title_size > 60 and screen.get_node("Automaat") != null and not screen._controls.visible, "een klein scherm met grote woorden, zonder knoppen")
	var parts: Dictionary = screen.machine_parts()
	test.check(parts.mesh == MachineModels.deposit_machine_mesh() and parts.hole is Vector3, "zijn eigen model, met het gat")
	var names: Array = (parts.hotspots as Array).map(func(hotspot: Dictionary) -> String: return String(hotspot.name))
	test.check(names == ["gat", "bon"], "het gat en de BON-knop zijn aan te klikken")
	for hotspot: Dictionary in parts.hotspots:
		test.check((parts.focus as Rect2).encloses(hotspot.rect), "%s valt binnen de close-up" % hotspot.name)
	test.check(screen.key_hints().contains("[1] BLIKJE") and screen.key_hints().contains("[ENTER] BON"), "de toetsen onderaan")
	var lines: Array = screen.pocket_lines()
	test.check(lines.size() == 3 and String(lines[1][0]).contains("2×") and String(lines[1][0]).contains("€ 0,40") and lines[1][1] == UiStyle.ACCENT,
		"in je zakken: twee blikjes van 40 cent (%s)" % [lines])
	player.inventory = {}
	lines = screen.pocket_lines()
	test.check(lines.size() == 4 and lines[1][1] == UiStyle.MUTED and String(lines[3][0]).contains("prullenbakken"), "niets bij je: gedimd, met een tip")
	screen.close()
	_tidy(screen, player, was_paused)


func test_one_in_at_a_time(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	test.check(is_equal_approx(screen.insert_one("blikje"), 0.4), "een blikje: 40 cent")
	test.check(int(player.inventory.blikje) == 1 and screen.inserted == {"blikje": 1} and is_equal_approx(screen.total, 0.4), "uit je zakken, geteld")
	test.check(screen._display_text.text == "1 STUKS\n€ 0,40" and player.money == 1.0, "op het scherm; nog niets uitbetaald")
	test.check(is_equal_approx(screen.insert_one("statiegeld"), 0.15) and is_equal_approx(screen.total, 0.55), "een fles: 15 cent erbij")
	test.check(screen.insert_one("statiegeld") == 0.0 and screen._display_title.text == "GEEN FLES" and is_equal_approx(screen.total, 0.55), "geen fles meer: geweigerd")
	test.check(screen.insert_one("kroket") == 0.0 and screen._display_title.text == "GEEN VERPAKKING" and int(player.inventory.kroket) == 1, "een kroket is geen statiegeld")
	test.check(is_equal_approx(screen.insert_one("blikje"), 0.4) and not player.inventory.has("blikje"), "het laatste blikje")
	test.check(screen.insert_one("blikje") == 0.0 and screen._display_title.text == "GEEN BLIKJE", "blikjes op")
	test.check(screen.inserted == {"blikje": 2, "statiegeld": 1} and is_equal_approx(screen.total, 0.95), "samen 95 cent (%s)" % screen.total)
	test.check(not screen._busy, "de automaat is weer vrij")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_the_hole_takes_cans_first_then_bottles(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	test.check(is_equal_approx(screen.insert_next(), 0.4) and is_equal_approx(screen.insert_next(), 0.4), "eerst de blikjes")
	screen.hotspot_pressed("gat")
	test.check(not player.inventory.has("statiegeld") and screen.inserted == {"blikje": 2, "statiegeld": 1}, "dan de fles (een klik op het gat)")
	test.check(screen.insert_next() == 0.0 and screen._display_title.text == "LEEG?", "niets meer: LEEG?")
	screen.hotspot_pressed("bestaat_niet")
	test.check(screen.state == "invoeren", "een onbekend onderdeel doet niets")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_one_that_comes_back_out_stays_in_your_pockets(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	test.check(not screen._rejected(), "zonder animatie komt er nooit een terug")
	screen.force_reject = true
	test.check(screen.insert_one("blikje") == 0.0 and int(player.inventory.blikje) == 2 and screen.total == 0.0, "niet herkend: het blikje blijft van jou")
	test.check(screen._display_title.text == "NIET HERKEND" and not screen._busy, "het scherm zegt het")
	test.check(not screen.force_reject and is_equal_approx(screen.insert_one("blikje"), 0.4), "de volgende keer gaat het goed")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_the_bon_is_printed_and_paid_out(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var listener := Listener.new()
	player.deposited.connect(listener.on_deposited)
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	screen.finished.connect(listener.on_finished)
	screen.print_bon()
	test.check(screen.state == "invoeren" and screen._display_title.text == "NIETS" and not screen._tray_section.visible, "niets ingevoerd: geen bon")
	screen.take_bon()
	test.check(screen.state == "invoeren" and player.money == 1.0, "een bon die er niet is kun je niet pakken")
	screen.insert_one("blikje")
	screen.insert_one("statiegeld")
	screen.print_bon()
	test.check(screen.state == "bon" and screen._tray_title.text == "STATIEGELDBON" and screen._display_title.text == "BEDANKT" and screen._display_text.text == "€ 0,55",
		"de bon geprint, het totaal op het scherm")
	test.check(player.money == 1.0 and not screen.is_closing(), "nog niet uitbetaald")
	test.check(screen.insert_one("blikje") == 0.0 and int(player.inventory.blikje) == 1, "na de bon gaat er niets meer in")
	screen.print_bon()
	test.check(screen.state == "bon", "nog een keer printen doet niets")
	screen.take_bon()
	test.check(screen.state == "klaar" and is_equal_approx(player.money, 1.55) and listener.paid == [0.55], "de bon gepakt: het geld in je portemonnee (%s)" % [listener.paid])
	test.check(screen._tray_title.text == "UITBETAALD" and screen.is_closing() and listener.finished_calls == 1, "uitbetaald en weg")
	screen.take_bon()
	test.check(is_equal_approx(player.money, 1.55), "nog een keer pakken betaalt niet nog eens")
	_tidy(screen, player, was_paused)


func test_the_bon_key_prints_and_pays_at_once(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	screen.hotspot_pressed("bon")
	test.check(screen.state == "invoeren" and screen._display_title.text == "NIETS" and not screen.is_closing(), "de BON-knop zonder iets erin: niets")
	screen.insert_next()
	screen.insert_next()
	screen.hotspot_pressed("bon")
	test.check(screen.state == "klaar" and is_equal_approx(player.money, 1.8) and screen.is_closing(), "de BON-knop: geprint, uitbetaald, weg")
	screen.bon()
	test.check(is_equal_approx(player.money, 1.8), "daarna doet de knop niets meer")
	_tidy(screen, player, was_paused)


func test_the_keys(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	test.check(screen._key(KEY_1) and screen.inserted == {"blikje": 1}, "1: een blikje")
	test.check(screen._key(KEY_KP_2) and screen.inserted == {"blikje": 1, "statiegeld": 1}, "2: een fles")
	test.check(screen._key(KEY_Q) and is_equal_approx(screen.total, 0.55), "een andere toets is van de automaat maar doet niets")
	screen.print_bon()
	screen._key(KEY_1)
	test.check(screen.inserted == {"blikje": 1, "statiegeld": 1} and screen.state == "bon", "met de bon eruit: 1 doet niets meer")
	screen._key(KEY_SPACE)
	test.check(screen.state == "klaar" and is_equal_approx(player.money, 1.55), "Spatie pakt de bon")
	_tidy(screen, player, was_paused)
	var second_player := _player()
	var second: Node = DepositMachineScreen.show_for(second_player, "", false)
	second._key(KEY_1)
	second._key(KEY_ENTER)
	test.check(second.state == "klaar" and is_equal_approx(second_player.money, 1.4), "Enter: de bon geprint en uitbetaald")
	_tidy(second, second_player, was_paused)


func test_leaving_with_something_in_it_pays_out(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var listener := Listener.new()
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	screen.finished.connect(listener.on_finished)
	screen.insert_one("blikje")
	screen.cancel()
	test.check(screen.state == "klaar" and is_equal_approx(player.money, 1.4), "Escape met iets erin: eerst de bon, uitbetaald")
	test.check(screen.is_closing() and listener.finished_calls == 1 and tree.paused == was_paused, "dan weg")
	_tidy(screen, player, was_paused)
	var empty_player := _player()
	var empty: Node = DepositMachineScreen.show_for(empty_player, "", false)
	empty.cancel()
	test.check(empty.is_closing() and empty.state == "invoeren" and empty_player.money == 1.0, "Escape zonder iets erin: gewoon weg")
	_tidy(empty, empty_player, was_paused)


func test_a_machine_out_of_order_takes_nothing(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false, "BUITEN GEBRUIK SORRY")
	test.check(screen != null and screen._display_title.text == "BUITEN" and screen._display_text.text == "GEBRUIK\nSORRY", "het eerste woord groot, de rest eronder")
	test.check(screen._display_title.get_theme_color("font_color") == DepositMachineScreen.REFUSED, "in de kleur van een weigering")
	test.check(screen.is_closing() and tree.paused == was_paused, "zonder animatie sluit hij meteen weer")
	test.check(screen.insert_next() == 0.0 and screen.insert_one("blikje") == 0.0 and int(player.inventory.blikje) == 2, "hij neemt niets aan")
	screen.bon()
	test.check(screen.state == "invoeren" and player.money == 1.0, "en geeft geen bon")
	_tidy(screen, player, was_paused)


func test_the_cursor_goes_over_the_hole_and_the_bon_key(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = DepositMachineScreen.show_for(player, "", false)
	test.check(screen.cursor_targets().size() == 2 and screen.cursor_label() == "", "twee onderdelen, eerst geen cursor")
	screen.move_cursor(Vector2.DOWN)
	test.check(screen.cursor_label() == "gat", "de eerste keer: op het gat")
	test.check(screen._cursor_frame != null and screen._cursor_frame.visible, "met een kader eromheen")
	screen.move_cursor(Vector2.DOWN)
	test.check(screen.cursor_label() == "gat", "eronder is niets: hij blijft")
	screen.move_cursor(Vector2.UP)
	test.check(screen.cursor_label() == "bon", "omhoog: de BON-knop")
	screen.use_cursor()
	test.check(screen._display_title.text == "NIETS", "gebruiken: de BON-knop ingedrukt (er zit niets in)")
	screen.move_cursor(Vector2.LEFT)
	test.check(screen.cursor_label() == "gat", "naar links: terug naar het gat")
	screen.use_cursor()
	test.check(screen.inserted == {"blikje": 1}, "gebruiken: een blikje erin")
	screen._process(0.016)
	test.check(screen.cursor_label() == "gat" and screen._cursor_frame.visible, "het kader blijft om het gat")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	screen._input(accept)
	test.check(screen.inserted == {"blikje": 2}, "ui_accept met de cursor in beeld gebruikt hem")
	screen._show_cursor({})
	test.check(screen.cursor_label() == "" and not screen._cursor_frame.visible, "de cursor weg: ook het kader")
	screen.cancel()
	_tidy(screen, player, was_paused)
