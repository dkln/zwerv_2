extends "res://scripts/ui/machines/machine_screen.gd"
## The cash machine (a PINPUNT on a facade in the town, scripts/world/things/street_machines.gd),
## close up: put in a bank card you found (Items "pinpas", BankCards: each card its own
## account), type its PIN on the keypad (4 digits; the riddle on the back in the inventory
## gives it), choose an amount and the money comes out, up to the balance. Three wrong PINs
## in a row and the machine keeps the card (BankCards.MOST_TRIES). Without a card it can do
## nothing for you. Sounds (MachineSounds): the keys, the card in and out, the error buzz,
## the card swallowed, the whirr and the notes counted out.
## Keys: 0-9 the keypad (or the options 1-4 in the menu), Backspace CORR, Enter OK, Esc STOP
## (the card comes back); the mouse too.
## Every machine belongs to a bank (Banks: Brabobank, OG Bank, Bonk Bank); its welcome
## screen shows that bank's logo (BankLogo).
## This is the behaviour layer: the steps (the card in, the PIN, the amounts, the money out,
## the card back or kept) and the keys. cash_machine_screen_rules.gd has the logic (what
## each step says, what a key does), cash_machine_screen_layout.gd says where its parts
## are, cash_machine_screen_view.gd builds the machine and its touch screen and shows what
## it is handed (`machine_view`, the `view` of the screen).
##   CashMachineScreen.show_for(player, "", true, "og_bank")

const BankCards = preload("res://scripts/player/bank_cards.gd")
const CashMachineScreenRules = preload("res://scripts/ui/machines/cash_machine_screen_rules.gd")
const CashMachineScreenLayout = preload("res://scripts/ui/machines/cash_machine_screen_layout.gd")
const CashMachineScreenView = preload("res://scripts/ui/machines/cash_machine_screen_view.gd")
const SCRIPT_PATH := "res://scripts/ui/machines/cash_machine_screen.gd"
const AMOUNTS := CashMachineScreenRules.AMOUNTS
const OPTION_COUNT := CashMachineScreenLayout.OPTION_COUNT

## "start" (no card in), "pin", "menu", "bezig" (counting out), "klaar".
var state := CashMachineScreenRules.STATE_START
var card: Dictionary = {}
var entered := ""
## What came out this time (euros), for the checks.
var paid_out := 0.0
## The bank of this machine (Banks), its logo on the welcome screen.
var bank := ""
## The view of the screen, as the cash machine's own.
var machine_view: CashMachineScreenView


static func show_for(for_player: Node, place := "", with_animation := true, bank_id := "") -> CanvasLayer:
	var screen: CanvasLayer = (load(SCRIPT_PATH) as GDScript).new()
	screen.set("bank", CashMachineScreenRules.bank_of(bank_id))
	screen.set("brand", CashMachineScreenRules.BRAND)
	screen.set("place_name", place)
	screen.set("backdrop", CashMachineScreenRules.BACKDROP)
	return present(screen, for_player, with_animation)


func _init() -> void:
	machine_view = CashMachineScreenView.new()
	machine_view.keypad_pressed.connect(_keypad)
	machine_view.stop_pressed.connect(cancel)
	view = machine_view


func _opened() -> void:
	# the bank's logo over the welcome on the screen
	machine_view.add_logo(bank)
	_show_start()


## The display, the bank's logo over it only on the welcome screen; the touch screen: its
## keypad while the PIN is asked, its choices otherwise.
func show_display(title: String, lines: Array, tone := "") -> void:
	super(title, lines, tone)
	machine_view.show_logo(state == CashMachineScreenRules.STATE_START)
	machine_view.show_keypad(state == CashMachineScreenRules.STATE_PIN)


func pocket_lines() -> Array:
	return CashMachineScreenRules.pocket_lines(_money(), BankCards.cards_of(player))


func key_hints() -> String:
	return CashMachineScreenRules.KEY_HINTS


func _key(keycode: Key) -> bool:
	if state == CashMachineScreenRules.STATE_PIN:
		var key_text := CashMachineScreenRules.keypad_key(keycode)
		if key_text != "":
			_keypad(key_text)
		return true
	var option := CashMachineScreenRules.option_of_key(keycode, OPTION_COUNT)
	if option >= 0:
		choose_option(option)
	return true


## Esc / STOP: the card back (if one is in), then away.
func cancel() -> void:
	if not card.is_empty() and state != CashMachineScreenRules.STATE_BUSY:
		sound("kaart")
		show_display("NEEM UW PAS", ["Tot ziens."])
		show_tray(CashMachineScreenRules.card_back_title(card), ["Je pas komt terug uit de gleuf."])
		card = {}
		busy = true
		await machine_view.play_card(true)
		busy = false
	close()


# ------------------------------------------------------------------ the steps

func _show_start() -> void:
	state = CashMachineScreenRules.STATE_START
	entered = ""
	card = {}
	var cards := BankCards.cards_of(player)
	show_display("WELKOM", CashMachineScreenRules.start_lines(cards.size(), OPTION_COUNT))
	var choices: Array = []
	for index in mini(cards.size(), OPTION_COUNT):
		var each_card: Dictionary = cards[index]
		choices.append([CashMachineScreenRules.card_choice(index, each_card), insert_card.bind(each_card)])
	set_options(choices)


## A card in the slot: the PIN next.
func insert_card(chosen: Dictionary) -> void:
	card = chosen
	entered = ""
	clear_tray()
	set_options([])
	busy = true
	# the card slides into the reader, then it is read
	await machine_view.play_card(false)
	sound("kaart")
	show_display("EEN MOMENT...", ["Uw pas wordt gelezen."])
	await pause_for(CashMachineScreenRules.READ_SECONDS)
	busy = false
	_show_pin()


func _show_pin(note := "", note_tone := "") -> void:
	state = CashMachineScreenRules.STATE_PIN
	show_display("TOETS UW PINCODE", CashMachineScreenRules.pin_lines(entered.length(), note, BankCards.tries_left(card)), note_tone)
	set_options([])


## A key of the keypad: a digit, CORR (one back) or OK (the PIN tried).
func _keypad(key_text: String) -> void:
	if state != CashMachineScreenRules.STATE_PIN:
		var option := CashMachineScreenRules.option_of_keypad(key_text, OPTION_COUNT)
		if option >= 0:
			choose_option(option)
		return
	sound("toets")
	if key_text == CashMachineScreenRules.KEY_OK:
		enter_pin(entered)
		return
	entered = CashMachineScreenRules.typed_after(entered, key_text)
	_show_pin()


## The PIN tried (the keypad's OK): right, wrong, or the card kept.
func enter_pin(pin: String) -> String:
	if state != CashMachineScreenRules.STATE_PIN:
		return ""
	if not CashMachineScreenRules.is_whole_pin(pin):
		sound("fout")
		_show_pin("Toets 4 cijfers.", WARNING)
		return "kort"
	var result := BankCards.try_pin(player, card, pin)
	entered = ""
	match result:
		"goed":
			sound("goed")
			_show_menu()
		"fout":
			sound("fout")
			_show_pin("PINCODE ONJUIST", WARNING)
		"ingeslikt":
			state = CashMachineScreenRules.STATE_DONE
			busy = true
			sound("fout")
			show_display("PINCODE ONJUIST", ["3 keer fout.", "", "UW PAS IS INGEHOUDEN.", "Neem contact op met uw bank."], WARNING)
			await pause_for(CashMachineScreenRules.KEPT_SECONDS)
			sound("inslikken")
			show_tray("INGESLIKT", CashMachineScreenRules.swallowed_lines(card), WARNING)
			card = {}
			refresh_pockets()
			await pause_for(CashMachineScreenRules.SWALLOWED_SECONDS)
			busy = false
			_show_start()
	return result


func _show_menu() -> void:
	state = CashMachineScreenRules.STATE_MENU
	var balance := float(card.get("saldo", 0.0))
	show_display("KIES EEN BEDRAG", CashMachineScreenRules.menu_lines(balance))
	var choices: Array = []
	for index in AMOUNTS.size():
		var amount: float = AMOUNTS[index]
		choices.append([CashMachineScreenRules.amount_choice(index, amount, balance), withdraw.bind(amount)])
	set_options(choices)


## The money out (if the balance allows): the whirr, the notes, the card back first.
func withdraw(amount: float) -> bool:
	if state != CashMachineScreenRules.STATE_MENU:
		return false
	if not CashMachineScreenRules.can_pay(amount, float(card.get("saldo", 0.0))):
		sound("fout")
		show_display("SALDO ONTOEREIKEND", CashMachineScreenRules.refused_lines(float(card.saldo)), WARNING)
		await pause_for(CashMachineScreenRules.REFUSED_SECONDS)
		if state == CashMachineScreenRules.STATE_MENU:
			_show_menu()
		return false
	state = CashMachineScreenRules.STATE_BUSY
	busy = true
	set_options([])
	show_display("EEN MOMENT...", ["Uw geld wordt geteld."])
	BankCards.withdraw(player, card, amount)
	paid_out += amount
	sound("geld")
	await pause_for(CashMachineScreenRules.COUNT_SECONDS)
	# (the balance is on the machine's screen, not in the panel too)
	show_tray("NEEM UW GELD", CashMachineScreenRules.money_lines(amount), GOOD)
	refresh_pockets()
	await pause_for(CashMachineScreenRules.TAKE_SECONDS)
	busy = false
	state = CashMachineScreenRules.STATE_MENU
	_show_menu()
	return true
