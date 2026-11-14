extends RefCounted
## The logic of the cash machine (the rules layer of
## scripts/ui/machines/cash_machine_screen.gd, which is the behaviour;
## cash_machine_screen_layout.gd says where its parts are, cash_machine_screen_view.gd builds
## and shows it): its states, the amounts, what the display and the panel say at each step,
## what a key of the keyboard or of the keypad does, the PIN as it is typed and the notes of
## an amount. Plain functions, without nodes: the cards themselves are BankCards
## (scripts/player/bank_cards.gd), the banks Banks (scripts/world/things/banks.gd).
##   const CashMachineScreenRules = preload("res://scripts/ui/machines/cash_machine_screen_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")
const Banks = preload("res://scripts/world/things/banks.gd")

const BRAND := "PINPUNT"
const BACKDROP := "straat"
## The states: no card in, the PIN asked, the amounts, counting out, done (the card kept).
const STATE_START := "start"
const STATE_PIN := "pin"
const STATE_MENU := "menu"
const STATE_BUSY := "bezig"
const STATE_DONE := "klaar"
const AMOUNTS := [5.0, 10.0, 20.0, 50.0]
const PIN_LENGTH := 4
## The keys of the keypad that are not digits.
const KEY_CORRECT := "CORR"
const KEY_OK := "OK"
## The notes the machine has, biggest first (euros).
const NOTES := [50, 20, 10, 5]
## The seconds the machine takes: reading a card, an amount refused, counting out, the money
## lying there, the PIN wrong for the last time, the card swallowed.
const READ_SECONDS := 0.6
const REFUSED_SECONDS := 1.4
const COUNT_SECONDS := 1.1
const TAKE_SECONDS := 0.8
const KEPT_SECONDS := 0.5
const SWALLOWED_SECONDS := 2.2
const KEY_HINTS := "[0-9] TOETSEN   [BACKSPACE] CORR   [ENTER] OK   [ESC] STOP"
## The tones of the lines of the panel (as MachineScreenRules.TONE_*).
const TONE_TEXT := "tekst"
const TONE_ACCENT := "accent"
const TONE_MUTED := "gedempt"


## The bank of a machine asked for `bank_id`: that bank, or the first one when it is not known.
static func bank_of(bank_id: String) -> String:
	return bank_id if Banks.BANKS.has(bank_id) else Banks.ORDER[0]


# ------------------------------------------------------------------ the keys

## The digit of a key of the keyboard (the row or the numpad), or "".
static func digit_of(keycode: Key) -> String:
	if keycode >= KEY_0 and keycode <= KEY_9:
		return str(keycode - KEY_0)
	if keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		return str(keycode - KEY_KP_0)
	return ""


static func is_enter(keycode: Key) -> bool:
	return keycode == KEY_ENTER or keycode == KEY_KP_ENTER


## The key of the keypad a key of the keyboard stands for while the PIN is asked: a digit,
## Backspace CORR, Enter OK; "" for any other.
static func keypad_key(keycode: Key) -> String:
	var digit := digit_of(keycode)
	if digit != "":
		return digit
	if keycode == KEY_BACKSPACE:
		return KEY_CORRECT
	if is_enter(keycode):
		return KEY_OK
	return ""


## The choice (0 = the first) a key of the keyboard stands for outside the PIN: 1 to
## `option_count`, Enter the first; -1 for any other.
static func option_of_key(keycode: Key, option_count: int) -> int:
	if is_enter(keycode):
		return 0
	return option_of_keypad(digit_of(keycode), option_count)


## The choice (0 = the first) a key of the keypad stands for outside the PIN: "1" to
## `option_count`, OK the first; -1 for any other.
static func option_of_keypad(key_text: String, option_count: int) -> int:
	if key_text == KEY_OK:
		return 0
	if key_text == KEY_CORRECT or not key_text.is_valid_int():
		return -1
	var number := int(key_text)
	return number - 1 if number >= 1 and number <= option_count else -1


## The PIN typed so far after the key `key_text` of the keypad: a digit more (up to
## PIN_LENGTH), or CORR one back.
static func typed_after(entered: String, key_text: String) -> String:
	if key_text == KEY_CORRECT:
		return entered.substr(0, maxi(entered.length() - 1, 0))
	return entered + key_text if entered.length() < PIN_LENGTH else entered


## Whether `pin` is a whole PIN (PIN_LENGTH digits typed).
static func is_whole_pin(pin: String) -> bool:
	return pin.length() >= PIN_LENGTH


## The places of the PIN on the display: a star for each of the `typed` digits, a dash for
## the rest ("* * _ _").
static func pin_mask(typed: int) -> String:
	var stars := ""
	for index in PIN_LENGTH:
		stars += ("* " if index < typed else "_ ")
	return stars.strip_edges()


# ------------------------------------------------------------------ the display

## The welcome: with `card_count` cards to choose from (shown as `option_count` choices at
## most), or what it says without one.
static func start_lines(card_count: int, option_count: int) -> Array:
	if card_count <= 0:
		return ["Steek uw pas in.", "", "(Je hebt geen pinpas.", "Zonder pas kan deze automaat", "niks voor je doen.)"]
	return ["Steek uw pas in.", "", "Kies een pas: [1]-[%d]" % mini(card_count, option_count)]


## What the choice of card `index` (0 = the first) says.
static func card_choice(index: int, card: Dictionary) -> String:
	return "[%d] PAS %d · %s" % [index + 1, int(card.nummer), String(card.houder)]


## The lines under "TOETS UW PINCODE": the PIN as typed, a note (wrong, too short) if there
## is one, and the tries left.
static func pin_lines(typed: int, note: String, tries_left: int) -> Array:
	var lines: Array = ["", "      " + pin_mask(typed), ""]
	if note != "":
		lines.append(note)
	lines.append("Nog %d poging%s." % [tries_left, "" if tries_left == 1 else "en"])
	return lines


## The lines under "KIES EEN BEDRAG".
static func menu_lines(balance: float) -> Array:
	return ["Saldo: " + MoneyText.euros(balance), "", "[1]-[4] bedrag   [ESC] stoppen"]


## Whether `amount` can be paid out of `balance`.
static func can_pay(amount: float, balance: float) -> bool:
	return amount <= balance + 0.001


## What the choice of amount `index` (0 = the first) says; more than the balance: too little.
static func amount_choice(index: int, amount: float, balance: float) -> String:
	var text := "[%d] %s" % [index + 1, MoneyText.euros(amount)]
	if not can_pay(amount, balance):
		text += "  (te weinig)"
	return text


## The lines under "SALDO ONTOEREIKEND".
static func refused_lines(balance: float) -> Array:
	return ["Saldo: " + MoneyText.euros(balance), "", "Kies een lager bedrag."]


## The notes of `amount`, as "1 × biljet van € 20" lines, biggest first.
static func notes_for(amount: float) -> Array:
	var left := roundi(amount)
	var lines: Array = []
	for note: int in NOTES:
		if left >= note:
			lines.append("%d × biljet van € %d" % [left / note, note])
			left %= note
	return lines


## What lies in the tray under "NEEM UW GELD": the amount and its notes.
static func money_lines(amount: float) -> Array:
	return [MoneyText.euros(amount)] + notes_for(amount)


## What the tray says of the card that came back.
static func card_back_title(card: Dictionary) -> String:
	return "PINPAS %d" % int(card.nummer)


## What the tray says of the card the machine kept.
static func swallowed_lines(card: Dictionary) -> Array:
	return ["De automaat houdt de pas.", "Weg is pas %d." % int(card.nummer)]


# ------------------------------------------------------------------ the panel

## What the panel lists of your pockets: your money, your cards (`cards`: BankCards.cards_of)
## and where the PIN is; [text, tone] each.
static func pocket_lines(money: float, cards: Array) -> Array:
	var lines: Array = [["GELD  " + MoneyText.euros(money), TONE_TEXT]]
	if cards.is_empty():
		lines.append(["Geen pinpas", TONE_MUTED])
	for each_card: Dictionary in cards:
		lines.append(["PINPAS %d · %s" % [int(each_card.nummer), String(each_card.houder)], TONE_ACCENT])
	lines.append(["De pincode staat als raadsel bij de pas in je inventaris (Tab).", TONE_MUTED])
	return lines
