extends RefCounted
## Unit tests of the cash machine (scripts/ui/machines/cash_machine_screen.gd) on its own,
## without the swipe (animate off) and with a stand-in player that carries bank cards
## (BankCards): the welcome with and without a card, the card in, the PIN on the keypad and
## the keys, wrong PINs and the card kept, the amounts and what comes out, STOP giving the
## card back, and the pure calculations (the notes of an amount, the digit of a key, the
## stars of the PIN).
##   tests/run_unit_tests.sh cash_machine

const CashMachineScreen = preload("res://scripts/ui/machines/cash_machine_screen.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const Banks = preload("res://scripts/world/things/banks.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A wallet and pockets that take and lose items, as BankCards asks of the player.
class TestPlayer:
	extends Node
	var money := 1.0
	var inventory := {}

	func add_item(item_id: String, count := 1, _quiet := false) -> bool:
		inventory[item_id] = int(inventory.get(item_id, 0)) + count
		return true

	func drop_item(item_id: String) -> void:
		inventory[item_id] = int(inventory.get(item_id, 0)) - 1
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)

	func add_money(amount: float) -> void:
		money += amount


## Counts `finished`.
class Listener:
	var finished_calls := 0

	func on_finished() -> void:
		finished_calls += 1


## A player in the tree with `card_count` cards of their own (PIN 1234, 2234, ...; € 23 each).
func _player(card_count := 1) -> TestPlayer:
	var player := TestPlayer.new()
	tree.root.add_child(player)
	for card_index in card_count:
		BankCards.give_own_card(player, {"pin": "%d234" % (card_index + 1), "saldo": 23.0, "houder": "S. TEST"})
	return player


## The screen gone at once (close only queues it; a next machine needs its name free), the
## pause back and the player gone.
func _tidy(screen: Node, player: Node, was_paused: bool) -> void:
	if is_instance_valid(screen):
		screen.free()
	tree.paused = was_paused
	player.free()


static func _option_texts(screen: Node) -> Array:
	var texts := []
	for option: Button in screen._options:
		if option.visible:
			texts.append(option.text)
	return texts


func test_notes_for_an_amount(test) -> void:
	test.check(CashMachineScreen._notes_for(5.0) == ["1 × biljet van € 5"], "€ 5: een briefje van vijf")
	test.check(CashMachineScreen._notes_for(50.0) == ["1 × biljet van € 50"], "€ 50: een van vijftig")
	test.check(CashMachineScreen._notes_for(85.0) == ["1 × biljet van € 50", "1 × biljet van € 20", "1 × biljet van € 10", "1 × biljet van € 5"], "€ 85: van elk een")
	test.check(CashMachineScreen._notes_for(140.0) == ["2 × biljet van € 50", "2 × biljet van € 20"], "€ 140: twee van vijftig, twee van twintig")
	test.check(CashMachineScreen._notes_for(0.0).is_empty() and CashMachineScreen._notes_for(3.0).is_empty(), "niets of minder dan vijf: geen briefjes")


func test_digit_of_a_key(test) -> void:
	test.check(CashMachineScreen._digit_of(KEY_0) == "0" and CashMachineScreen._digit_of(KEY_9) == "9", "de cijfers bovenaan")
	test.check(CashMachineScreen._digit_of(KEY_KP_0) == "0" and CashMachineScreen._digit_of(KEY_KP_7) == "7", "en die van het numerieke blok")
	test.check(CashMachineScreen._digit_of(KEY_A) == "" and CashMachineScreen._digit_of(KEY_ENTER) == "", "een andere toets: geen cijfer")


func test_pin_mask(test) -> void:
	test.check(CashMachineScreen.pin_mask(0) == "_ _ _ _", "nog niets getypt")
	test.check(CashMachineScreen.pin_mask(2) == "* * _ _", "twee cijfers")
	test.check(CashMachineScreen.pin_mask(4) == "* * * *" and CashMachineScreen.pin_mask(9) == "* * * *", "vier (of meer): alles sterren")


func test_the_bank_and_the_parts_of_the_machine(test) -> void:
	var player := _player(0)
	var was_paused := tree.paused
	var screen: Node = CashMachineScreen.show_for(player, "Spui", false, "og_bank")
	test.check(screen != null and screen.bank == "og_bank" and screen.brand == "PINPUNT" and screen.place_name == "Spui" and screen.backdrop == "straat",
		"de automaat van de OG Bank aan het Spui, op straat")
	test.check(screen._logo != null and screen._logo.bank_id == "og_bank" and screen._logo.visible, "het logo van de bank op het welkomstscherm")
	var parts: Dictionary = screen.machine_parts()
	test.check(parts.mesh == MachineModels.cash_machine_mesh() and parts.card is Vector3 and (parts.focus as Rect2).encloses(parts.screen),
		"het model van de geldautomaat, de kaartlezer, de close-up om het scherm heen")
	test.check(screen.key_hints().contains("[ENTER] OK") and screen.key_hints().contains("[ESC] STOP"), "de toetsen onderaan")
	screen.close()
	screen.free()
	var unknown: Node = CashMachineScreen.show_for(player, "", false, "bestaat_niet")
	test.check(unknown.bank == Banks.ORDER[0], "een onbekende bank: de eerste")
	unknown.close()
	_tidy(unknown, player, was_paused)


func test_without_a_card_it_can_do_nothing(test) -> void:
	var player := _player(0)
	var was_paused := tree.paused
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	test.check(screen.state == "start" and screen._display_title.text == "WELKOM" and screen._display_text.text.contains("geen pinpas"), "welkom, maar je hebt geen pas")
	test.check(_option_texts(screen).is_empty() and not screen._keypad_grid.visible, "geen keuzes, geen toetsenbord")
	test.check(screen.pocket_lines().any(func(line: Array) -> bool: return line[0] == "Geen pinpas"), "in je zakken: geen pinpas")
	screen._key(KEY_1)
	screen._key(KEY_ENTER)
	screen._keypad("1")
	screen._keypad("OK")
	test.check(screen.state == "start" and screen.card.is_empty(), "toetsen doen niets")
	test.check(screen.enter_pin("1234") == "" and not screen.withdraw(5.0), "een pincode of geld opnemen kan niet zonder pas erin")
	screen.close()
	_tidy(screen, player, was_paused)


func test_choosing_a_card_and_typing_the_pin(test) -> void:
	var player := _player(2)
	var was_paused := tree.paused
	var cards := BankCards.cards_of(player)
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	test.check(_option_texts(screen) == ["[1] PAS 1 · S. TEST", "[2] PAS 2 · S. TEST"], "een keuze per pas (%s)" % [_option_texts(screen)])
	test.check(screen._display_text.text.contains("Kies een pas: [1]-[2]"), "het scherm vraagt welke")
	test.check(screen.pocket_lines().filter(func(line: Array) -> bool: return String(line[0]).begins_with("PINPAS")).size() == 2, "beide passen in je zakken")
	screen._key(KEY_3)
	test.check(screen.state == "start", "een pas die er niet is: niets")
	test.check(screen._key(KEY_2) and screen.state == "pin" and screen.card == cards[1], "2: de tweede pas erin, nu de pincode")
	test.check(screen._keypad_grid.visible and not screen._logo.visible and _option_texts(screen).is_empty(), "het toetsenbord in plaats van de keuzes en het logo")
	test.check(screen._display_title.text == "TOETS UW PINCODE" and screen._display_text.text.contains("_ _ _ _") and screen._display_text.text.contains("Nog 3 pogingen."),
		"vier lege plekken, drie pogingen")
	screen._key(KEY_2)
	screen._key(KEY_KP_2)
	test.check(screen.entered == "22" and screen._display_text.text.contains("* * _ _"), "twee cijfers: twee sterren")
	screen._key(KEY_BACKSPACE)
	test.check(screen.entered == "2", "Backspace: een terug")
	screen._keypad("CORR")
	screen._keypad("CORR")
	test.check(screen.entered == "", "CORR op leeg: blijft leeg")
	for digit in "22349":
		screen._keypad(digit)
	test.check(screen.entered == "2234", "niet meer dan vier cijfers (%s)" % screen.entered)
	screen._key(KEY_ENTER)
	test.check(screen.state == "menu" and screen.entered == "" and BankCards.tries_left(cards[1]) == 3, "Enter met de goede pincode: het menu")
	test.check(not screen._keypad_grid.visible, "het toetsenbord weer weg")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_wrong_pins_and_the_card_kept(test) -> void:
	var player := _player(1)
	var was_paused := tree.paused
	var card: Dictionary = BankCards.cards_of(player)[0]
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	screen.insert_card(card)
	test.check(screen.enter_pin("12") == "kort" and screen._display_text.text.contains("Toets 4 cijfers.") and BankCards.tries_left(card) == 3,
		"te kort: geen poging kwijt")
	test.check(screen.enter_pin("9999") == "fout" and screen.state == "pin" and screen._display_text.text.contains("PINCODE ONJUIST"), "verkeerd: geweigerd")
	test.check(screen._display_text.text.contains("Nog 2 pogingen."), "nog twee")
	test.check(screen.enter_pin("9999") == "fout" and screen._display_text.text.contains("Nog 1 poging."), "nog een (enkelvoud)")
	test.check(screen.enter_pin("9999") == "ingeslikt", "de derde keer: ingeslikt")
	test.check(BankCards.cards_of(player).is_empty() and not player.inventory.has("pinpas"), "de pas is weg uit je zakken")
	test.check(screen.state == "start" and screen.card.is_empty() and screen._display_text.text.contains("geen pinpas"), "terug bij welkom, zonder pas")
	test.check(screen._tray_title.text == "INGESLIKT", "in het bakje staat wat er gebeurde")
	screen.close()
	_tidy(screen, player, was_paused)


func test_the_right_pin_resets_the_tries(test) -> void:
	var player := _player(1)
	var was_paused := tree.paused
	var card: Dictionary = BankCards.cards_of(player)[0]
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	screen.insert_card(card)
	screen.enter_pin("0000")
	screen.enter_pin("0000")
	test.check(screen.enter_pin("1234") == "goed" and BankCards.tries_left(card) == 3 and screen.state == "menu", "na twee keer fout toch goed: weer drie pogingen")
	test.check(screen.enter_pin("1234") == "", "in het menu vraagt hij geen pincode meer")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_withdrawing_no_more_than_the_balance(test) -> void:
	var player := _player(1)
	var was_paused := tree.paused
	var card: Dictionary = BankCards.cards_of(player)[0]
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	screen.insert_card(card)
	screen.enter_pin("1234")
	test.check(screen._display_title.text == "KIES EEN BEDRAG" and screen._display_text.text.contains("Saldo: € 23,00"), "het saldo op het scherm")
	test.check(_option_texts(screen) == ["[1] € 5,00", "[2] € 10,00", "[3] € 20,00", "[4] € 50,00  (te weinig)"], "de bedragen, te veel gemerkt (%s)" % [_option_texts(screen)])
	test.check(not screen.withdraw(50.0) and player.money == 1.0 and float(card.saldo) == 23.0 and screen.state == "menu", "€ 50 kan niet bij € 23")
	screen._key(KEY_4)
	test.check(player.money == 1.0 and screen.paid_out == 0.0, "ook niet met de toets")
	test.check(screen.withdraw(20.0), "€ 20 kan")
	test.check(is_equal_approx(player.money, 21.0) and is_equal_approx(float(card.saldo), 3.0) and screen.paid_out == 20.0, "in je portemonnee, van de rekening af")
	test.check(screen._tray_title.text == "NEEM UW GELD" and (screen.stage_parts().came_out as Array).size() == 1, "het geld komt uit de gleuf")
	test.check(screen.state == "menu" and screen._display_text.text.contains("Saldo: € 3,00"), "weer het menu met het nieuwe saldo")
	test.check(_option_texts(screen)[0] == "[1] € 5,00  (te weinig)", "nu is ook € 5 te veel")
	screen._key(KEY_ENTER)
	test.check(is_equal_approx(player.money, 21.0), "Enter (de eerste keuze) geeft dan niets")
	card["saldo"] = 30.0
	screen._show_menu()
	screen._keypad("2")
	test.check(is_equal_approx(player.money, 31.0) and is_equal_approx(screen.paid_out, 30.0), "het toetsenbord kiest in het menu een bedrag (2: € 10)")
	screen._keypad("OK")
	test.check(is_equal_approx(player.money, 36.0), "OK is de eerste keuze (€ 5)")
	screen._keypad("CORR")
	screen._keypad("9")
	test.check(is_equal_approx(player.money, 36.0), "CORR en een cijfer zonder keuze doen niets")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_stop_gives_the_card_back_and_leaves(test) -> void:
	var player := _player(1)
	var was_paused := tree.paused
	var card: Dictionary = BankCards.cards_of(player)[0]
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	var listener := Listener.new()
	screen.finished.connect(listener.on_finished)
	screen._options[0].pressed.emit()
	test.check(screen.state == "pin" and screen.card == card, "een klik op de pas: erin")
	var stop := (screen._controls.get_children().back() as Button)
	test.check(stop.text == "STOP", "de laatste knop is STOP")
	stop.pressed.emit()
	test.check(screen.card.is_empty() and screen._tray_title.text == "PINPAS 1" and screen._display_title.text == "NEEM UW PAS", "STOP: de pas komt terug")
	test.check(screen.is_closing() and listener.finished_calls == 1 and tree.paused == was_paused, "en de automaat sluit")
	test.check(BankCards.cards_of(player).size() == 1 and int(player.inventory.get("pinpas", 0)) == 1, "de pas zit nog in je zakken")
	_tidy(screen, player, was_paused)


func test_the_keypad_buttons_type_the_pin(test) -> void:
	var player := _player(1)
	var was_paused := tree.paused
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	screen.insert_card(BankCards.cards_of(player)[0])
	var keys := {}
	for key_button: Button in screen._keypad_grid.get_children():
		keys[key_button.text] = key_button
	test.check(keys.size() == 12 and keys.has("CORR") and keys.has("OK") and keys.has("0"), "twaalf toetsen: de cijfers, CORR en OK")
	for digit in "1299":
		(keys[digit] as Button).pressed.emit()
	(keys["CORR"] as Button).pressed.emit()
	(keys["CORR"] as Button).pressed.emit()
	(keys["3"] as Button).pressed.emit()
	(keys["4"] as Button).pressed.emit()
	test.check(screen.entered == "1234", "getypt en verbeterd op het scherm (%s)" % screen.entered)
	(keys["OK"] as Button).pressed.emit()
	test.check(screen.state == "menu", "OK: het menu")
	screen.cancel()
	_tidy(screen, player, was_paused)


func test_the_cursor_goes_to_the_first_button_and_uses_it(test) -> void:
	var player := _player(1)
	var was_paused := tree.paused
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	var labels: Array = screen.cursor_targets().map(func(target: Dictionary) -> String: return (target.button as Button).text)
	test.check(labels == ["[1] PAS 1 · S. TEST", "STOP"], "de cursor kan op de knoppen die te zien zijn (%s)" % [labels])
	test.check(screen.cursor_label() == "", "eerst is er geen cursor")
	screen.use_cursor()
	test.check(screen.cursor_label() == "[1] PAS 1 · S. TEST" and screen.state == "start", "gebruiken zonder cursor: hij verschijnt op de eerste knop")
	screen.use_cursor()
	test.check(screen.state == "pin", "nog een keer: de knop ingedrukt, de pas erin")
	screen._process(0.016)
	test.check(screen.cursor_label() != "[1] PAS 1 · S. TEST" and screen.cursor_label() != "", "die knop is weg: de cursor naar een knop die er nog is (%s)" % screen.cursor_label())
	screen._show_cursor({})
	test.check(screen.cursor_label() == "", "de muis neemt het over: de cursor weg")
	screen.cancel()
	_tidy(screen, player, was_paused)
