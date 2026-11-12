extends RefCounted
## The bank cards a zwerver finds (Items "pinpas"): every card its own account, with a
## modest balance (BALANCE_RANGE), a PIN of four digits and a riddle or a sum scribbled on
## the back whose answer is the PIN (shown in the inventory: description). The cards are
## kept on the player, as the metadata CARDS_META (an Array of Dictionaries, the order they
## were found in), and the inventory counts them as "pinpas" (one slot however many).
## Used by the lost cards in the town (scripts/world/lost_bank_cards.gd), the cash machines
## (scripts/ui/machines/cash_machine_screen.gd) and a conversation that gives one.
##   const BankCards = preload("res://scripts/player/bank_cards.gd")
##   BankCards.give_found_bank_card(player)          # true: a new card in the pockets
##   BankCards.check_pin(card, "4232")
##   BankCards.withdraw(player, card, 20.0)
## A card: {"pin": "4232", "saldo": 23.45, "raadsel": "...", "houder": "M. JANSEN",
## "nummer": 3, "pogingen": 0 (wrong PINs in a row)}.

const ITEM := "pinpas"
const CARDS_META := "pinpassen"
## The balance of a found card, euros (it never is much).
const BALANCE_RANGE := Vector2(8.0, 60.0)
## Wrong PINs in a row before a cash machine keeps the card.
const MOST_TRIES := 3
## What the digits 0..9 are in the riddles of the kind "cijfers".
const DIGIT_RIDDLES := [
	["het aantal wielen van een slak", "de hoeken van een cirkel"],
	["het aantal neuzen op je gezicht", "hoeveel Hofvijvers Den Haag heeft"],
	["het aantal ogen van een meeuw", "de wielen van een fiets"],
	["de hoeken van een driehoek", "de kleuren van een stoplicht"],
	["de poten van een hond", "de seizoenen van een jaar"],
	["de vingers aan één hand", "de punten van een zeester"],
	["de poten van een mier", "de zijden van een dobbelsteen"],
	["de dagen van een week", "de levens van een kat"],
	["de poten van een spin", "de armen van een octopus"],
	["de kegels bij het kegelen", "de planeten toen opa op school zat"],
]
const OWNERS := ["M. JANSEN", "A. DE VRIES", "P. BAKKER", "S. VISSER", "K. SMIT", "R. DE BOER",
	"L. MULDER", "J. VAN DIJK", "F. BOS", "H. MEIJER", "E. EL AMRANI", "T. NGUYEN", "D. HOEKSTRA"]


## A new card with its own account, from `random`.
static func make_card(random: RandomNumberGenerator) -> Dictionary:
	var kind := random.randi() % 3
	var puzzle := {}
	match kind:
		0:
			puzzle = _sum_puzzle(random)
		1:
			puzzle = _digit_puzzle(random)
		_:
			puzzle = _halves_puzzle(random)
	var cents := random.randi_range(int(BALANCE_RANGE.x * 100.0), int(BALANCE_RANGE.y * 100.0))
	return {"pin": String(puzzle.pin), "saldo": cents / 100.0, "raadsel": String(puzzle.text),
		"houder": String(OWNERS[random.randi() % OWNERS.size()]), "nummer": 0, "pogingen": 0}


## Gives `player` a new found card (its own balance, PIN and riddle): in the pockets as one
## more "pinpas" and kept on the player. False (nothing given) if the pockets are full.
## `random`: where the card comes from (null: a fresh, randomised one).
static func give_found_bank_card(player: Node, random: RandomNumberGenerator = null) -> bool:
	if player == null or not player.has_method("add_item"):
		return false
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	var card := make_card(random)
	var cards := cards_of(player)
	# stored before the item is added, so whoever hears inventory_changed sees the card
	card["nummer"] = _next_number(player)
	cards.append(card)
	player.set_meta(CARDS_META, cards)
	if not bool(player.call("add_item", ITEM)):
		cards.erase(card)
		player.set_meta(CARDS_META, cards)
		return false
	return true


## The cards `player` carries (the same Array: changes stick).
static func cards_of(player: Node) -> Array:
	if player == null:
		return []
	if not player.has_meta(CARDS_META):
		player.set_meta(CARDS_META, [])
	return player.get_meta(CARDS_META)


static func check_pin(card: Dictionary, entered: String) -> bool:
	return entered.length() == 4 and entered == String(card.get("pin", ""))


## A PIN tried at a cash machine: "goed" (and the tries start again), "fout" (wrong, tries
## left) or "ingeslikt" (the third wrong one: the card is taken, swallow).
static func try_pin(player: Node, card: Dictionary, entered: String) -> String:
	if check_pin(card, entered):
		card["pogingen"] = 0
		return "goed"
	card["pogingen"] = int(card.get("pogingen", 0)) + 1
	if int(card.pogingen) >= MOST_TRIES:
		swallow(player, card)
		return "ingeslikt"
	return "fout"


static func tries_left(card: Dictionary) -> int:
	return MOST_TRIES - int(card.get("pogingen", 0))


## Takes `amount` euros off the card's account into the player's wallet; false (nothing
## happens) if the balance is too low or the amount not more than nothing.
static func withdraw(player: Node, card: Dictionary, amount: float) -> bool:
	if amount <= 0.0 or amount > float(card.get("saldo", 0.0)) + 0.001:
		return false
	card["saldo"] = snappedf(float(card.saldo) - amount, 0.01)
	if player and player.has_method("add_money"):
		player.call("add_money", amount)
	return true


## The machine keeps the card: gone from the pockets and the account with it.
static func swallow(player: Node, card: Dictionary) -> void:
	var cards := cards_of(player)
	if not cards.has(card):
		return
	cards.erase(card)
	if player.has_method("drop_item"):
		player.call("drop_item", ITEM)


## The text of the "pinpas" in the inventory: the item's own line, then the back of every
## card it carries (its holder and the riddle).
static func description(player: Node, base_text: String) -> String:
	var cards := cards_of(player)
	if cards.is_empty():
		return base_text
	var lines: Array[String] = [base_text]
	for card: Dictionary in cards:
		lines.append("PAS %d (T.N.V. %s): %s" % [int(card.nummer), String(card.houder), String(card.raadsel)])
	return "\n".join(lines)


static func _next_number(player: Node) -> int:
	var highest := 0
	for card: Dictionary in cards_of(player):
		highest = maxi(highest, int(card.get("nummer", 0)))
	return highest + 1


## "a × b + c" with the PIN as the answer.
static func _sum_puzzle(random: RandomNumberGenerator) -> Dictionary:
	var first := random.randi_range(12, 89)
	var second := random.randi_range(21, 99)
	while first * second < 1000 or first * second > 9000:
		first = random.randi_range(12, 89)
		second = random.randi_range(21, 99)
	var added := random.randi_range(1, mini(999, 9999 - first * second))
	var pin := first * second + added
	var texts := [
		"Mijn code? Reken maar uit: %d × %d + %d." % [first, second, added],
		"Niet vergeten: %d keer %d, en dan %d erbij." % [first, second, added],
		"Code = %d × %d + %d. Zo onthoudt niemand hem." % [first, second, added],
	]
	return {"pin": str(pin), "text": String(texts[random.randi() % texts.size()])}


## Each digit a little riddle ("de poten van een spin").
static func _digit_puzzle(random: RandomNumberGenerator) -> Dictionary:
	var digits: Array[int] = [random.randi_range(1, 9), random.randi_range(0, 9), random.randi_range(0, 9), random.randi_range(0, 9)]
	var parts: Array[String] = []
	for digit in digits:
		var riddles: Array = DIGIT_RIDDLES[digit]
		parts.append(String(riddles[random.randi() % riddles.size()]))
	var pin := ""
	for digit in digits:
		pin += str(digit)
	return {"pin": pin, "text": "Eerst %s, dan %s, dan %s en als laatste %s." % parts}


## Two halves of two digits, each a sum of its own.
static func _halves_puzzle(random: RandomNumberGenerator) -> Dictionary:
	var first_half := random.randi_range(10, 99)
	var second_half := random.randi_range(10, 99)
	var factor := 2
	for candidate in [9, 8, 7, 6, 5, 4, 3]:
		if first_half % candidate == 0:
			factor = candidate
			break
	var first_text := "%d × %d" % [factor, first_half / factor] if first_half % factor == 0 else "%d + %d" % [first_half - 7, 7]
	var second_text := "de helft van %d" % (second_half * 2)
	return {"pin": "%02d%02d" % [first_half, second_half],
		"text": "Eerste twee cijfers: %s. Laatste twee: %s." % [first_text, second_text]}
