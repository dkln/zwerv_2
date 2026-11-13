extends RefCounted
## Unit tests of the found bank cards (scripts/player/bank_cards.gd, BankCards.make_card): a
## PIN of four digits, a modest balance, and a riddle whose answer is that PIN (worked out
## again from its text, as a player would, for many cards of every kind of riddle).

const BankCards = preload("res://scripts/player/bank_cards.gd")
const CARDS_TRIED := 400


## CARDS_TRIED cards, the same every run.
static func _cards() -> Array[Dictionary]:
	var random := RandomNumberGenerator.new()
	random.seed = 12345
	var cards: Array[Dictionary] = []
	for card_index in CARDS_TRIED:
		cards.append(BankCards.make_card(random))
	return cards


## The PIN of a riddle, worked out as a player would.
static func _solve(text: String) -> String:
	var numbers := RegEx.create_from_string("\\d+").search_all(text).map(func(found: RegExMatch) -> int: return int(found.get_string()))
	if numbers.size() == 3 and not text.begins_with("Eerste"):
		return str(numbers[0] * numbers[1] + numbers[2])
	if text.begins_with("Eerste"):
		var first_half: int = numbers[0] * numbers[1] if text.contains("×") else numbers[0] + numbers[1]
		var second_half: int = numbers[numbers.size() - 1] / 2
		return "%02d%02d" % [first_half, second_half]
	# the digits: each phrase of BankCards.DIGIT_RIDDLES in the order they come
	var found := []
	for digit in BankCards.DIGIT_RIDDLES.size():
		for phrase: String in BankCards.DIGIT_RIDDLES[digit]:
			var at := text.find(phrase)
			while at >= 0:
				found.append([at, digit, phrase.length()])
				at = text.find(phrase, at + 1)
	found.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	var pin := ""
	for entry: Array in found:
		pin += str(entry[1])
	return pin


## Every card's PIN is four digits and its riddle, solved from the text, gives that PIN.
func test_riddle_gives_the_pin(test) -> void:
	var wrong := 0
	var first_wrong := ""
	for card: Dictionary in _cards():
		var pin := String(card.pin)
		var solved := _solve(String(card.raadsel))
		if pin.length() != 4 or not pin.is_valid_int() or solved != pin:
			wrong += 1
			if first_wrong == "":
				first_wrong = "%s -> %s (pin %s)" % [card.raadsel, solved, pin]
	test.check(wrong == 0, "%d passen: pincode van 4 cijfers, het raadsel geeft hem (%d fout) %s" % [CARDS_TRIED, wrong, first_wrong])


## The balance of a found card stays within BankCards.BALANCE_RANGE.
func test_balance_is_modest(test) -> void:
	var lowest := INF
	var highest := 0.0
	for card: Dictionary in _cards():
		lowest = minf(lowest, float(card.saldo))
		highest = maxf(highest, float(card.saldo))
	test.check(lowest >= BankCards.BALANCE_RANGE.x and highest <= BankCards.BALANCE_RANGE.y,
		"saldo bescheiden: € %.2f .. € %.2f" % [lowest, highest])


## The riddles come in at least three kinds.
func test_riddles_come_in_several_kinds(test) -> void:
	var kinds := {}
	for card: Dictionary in _cards():
		kinds[String(card.raadsel).substr(0, 6)] = true
	test.check(kinds.size() >= 3, "verschillende soorten raadsels (%d)" % kinds.size())
