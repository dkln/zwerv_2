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
##   CashMachineScreen.show_for(player, "", true, "og_bank")

const BankCards = preload("res://scripts/player/bank_cards.gd")
const Banks = preload("res://scripts/world/things/banks.gd")
const BankLogo = preload("res://scripts/ui/widgets/bank_logo.gd")
const SCRIPT_PATH := "res://scripts/ui/machines/cash_machine_screen.gd"
const AMOUNTS := [5.0, 10.0, 20.0, 50.0]
const OPTION_COUNT := 4
## The card in the scene (_card_motion): its size against the model of a found card
## (MachineModels.bank_card_mesh, 30 x 20 cm: so about 9 x 6 cm), and the seconds it takes to
## the slot, into it, and the time it sticks out before it is taken back.
const CARD_SCALE := 0.3
const CARD_TO_SLOT := 0.3
const CARD_IN := 0.35
const CARD_TAKEN_AFTER := 0.6

## "start" (no card in), "pin", "menu", "bezig" (counting out), "klaar".
var state := "start"
var card: Dictionary = {}
var entered := ""
## What came out this time (euros), for the checks.
var paid_out := 0.0
## The bank of this machine (Banks), its logo on the welcome screen.
var bank := ""
var _logo: Control
var _options: Array[Button] = []
var _keypad_grid: GridContainer
var _option_actions: Array[Callable] = []


static func show_for(for_player: Node, place := "", with_animation := true, bank_id := "") -> CanvasLayer:
	var screen: CanvasLayer = (load(SCRIPT_PATH) as GDScript).new()
	screen.set("bank", bank_id if Banks.BANKS.has(bank_id) else Banks.ORDER[0])
	screen.set("brand", "PINPUNT")
	screen.set("body_colour", Color("#3A4250"))
	screen.set("trim_colour", Color("#F2B705"))
	screen.set("screen_colour", Color("#5FE0FF"))
	screen.set("place_name", place)
	screen.set("backdrop", "straat")
	return present(screen, for_player, with_animation)


func _opened() -> void:
	# the bank's logo over the welcome on the screen
	_logo = BankLogo.new()
	_logo.name = "Banklogo"
	_logo.show_bank(bank, UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	var column := _display_title.get_parent()
	column.add_child(_logo)
	column.move_child(_logo, 0)
	_show_start()


## The display, the bank's logo over it only on the welcome screen.
func show_display(title: String, lines: Array, colour := Color(0, 0, 0, 0)) -> void:
	super(title, lines, colour)
	if _logo:
		_logo.visible = state == "start"
	# the touch screen: its keypad while the PIN is asked, its choices otherwise
	if _keypad_grid:
		_keypad_grid.visible = state == "pin"


## The cash machine of the town (MachineModels.cash_machine_mesh, voxels of 6,25 cm, 12 x 28
## x 8): its screen, keypad and the slot the money comes out of.
func machine_parts() -> Dictionary:
	return {"mesh": MachineModels.cash_machine_mesh(), "screen": Rect2(-0.25, 1.0, 0.5, 0.3125), "front": 0.25,
		"screen_sunk": 0.125, "keys": Vector3(-0.09, 0.66, 0.25), "slot": Vector3(0.0, 0.28, 0.25),
		"card": Vector3(0.25, 0.78, 0.25),
		# the close-up takes in the screen and, under it, the card reader (you see your card go in)
		"focus": Rect2(-0.3, 0.72, 0.6, 0.62), "focus_share": 0.75}


## On the touch screen: the keypad (while the PIN is asked), the choices and STOP.
func build_controls(box: VBoxContainer) -> void:
	var keypad := GridContainer.new()
	keypad.columns = 3
	keypad.add_theme_constant_override("h_separation", 6)
	keypad.add_theme_constant_override("v_separation", 6)
	for key_text in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CORR", "0", "OK"]:
		var colour := Color(0, 0, 0, 0)
		if key_text == "CORR":
			colour = Color("#C8A020")
		elif key_text == "OK":
			colour = Color("#2E9A48")
		var key_button := button(key_text, _keypad.bind(key_text), 92, colour)
		keypad.add_child(key_button)
	keypad.visible = false
	box.add_child(keypad)
	_keypad_grid = keypad
	for option_index in OPTION_COUNT:
		var option := button("", _option.bind(option_index), 0)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(option)
		_options.append(option)
		_option_actions.append(Callable())
	box.add_child(button("STOP", cancel, 0, Color("#B8302A")))


func pocket_lines() -> Array:
	var lines: Array = [["GELD  " + euros(_money()), UiStyle.TEXT]]
	var cards := BankCards.cards_of(player)
	if cards.is_empty():
		lines.append(["Geen pinpas", UiStyle.MUTED])
	for each_card: Dictionary in cards:
		lines.append(["PINPAS %d · %s" % [int(each_card.nummer), String(each_card.houder)], UiStyle.ACCENT])
	lines.append(["De pincode staat als raadsel bij de pas in je inventaris (Tab).", UiStyle.MUTED])
	return lines


func key_hints() -> String:
	return "[0-9] TOETSEN   [BACKSPACE] CORR   [ENTER] OK   [ESC] STOP"


func _key(keycode: Key) -> bool:
	var digit := _digit_of(keycode)
	if state == "pin":
		if digit != "":
			_keypad(digit)
		elif keycode == KEY_BACKSPACE:
			_keypad("CORR")
		elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
			_keypad("OK")
		return true
	if digit != "" and int(digit) >= 1 and int(digit) <= OPTION_COUNT:
		_option(int(digit) - 1)
	elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		_option(0)
	return true


## Esc / STOP: the card back (if one is in), then away.
func cancel() -> void:
	if not card.is_empty() and state != "bezig":
		sound("kaart")
		show_display("NEEM UW PAS", ["Tot ziens."])
		show_tray("PINPAS %d" % int(card.nummer), ["Je pas komt terug uit de gleuf."])
		card = {}
		_busy = true
		await _card_motion(true)
		_busy = false
	close()


# ------------------------------------------------------------------ the steps

func _show_start() -> void:
	state = "start"
	entered = ""
	card = {}
	var cards := BankCards.cards_of(player)
	if cards.is_empty():
		show_display("WELKOM", ["Steek uw pas in.", "", "(Je hebt geen pinpas.", "Zonder pas kan deze automaat", "niks voor je doen.)"])
		_set_options([])
		return
	show_display("WELKOM", ["Steek uw pas in.", "", "Kies een pas: [1]-[%d]" % mini(cards.size(), OPTION_COUNT)])
	var choices: Array = []
	for index in mini(cards.size(), OPTION_COUNT):
		var each_card: Dictionary = cards[index]
		choices.append(["[%d] PAS %d · %s" % [index + 1, int(each_card.nummer), String(each_card.houder)], insert_card.bind(each_card)])
	_set_options(choices)


## A card in the slot: the PIN next.
func insert_card(chosen: Dictionary) -> void:
	card = chosen
	entered = ""
	clear_tray()
	_set_options([])
	_busy = true
	# the card slides into the reader, then it is read
	await _card_motion(false)
	sound("kaart")
	show_display("EEN MOMENT...", ["Uw pas wordt gelezen."])
	await pause_for(0.6)
	_busy = false
	_show_pin()


func _show_pin(note := "", note_colour := Color(0, 0, 0, 0)) -> void:
	state = "pin"
	var stars := ""
	for index in 4:
		stars += ("* " if index < entered.length() else "_ ")
	var lines: Array = ["", "      " + stars.strip_edges(), ""]
	if note != "":
		lines.append(note)
	lines.append("Nog %d poging%s." % [BankCards.tries_left(card), "" if BankCards.tries_left(card) == 1 else "en"])
	show_display("TOETS UW PINCODE", lines, note_colour)
	_set_options([])


## A key of the keypad: a digit, CORR (one back) or OK (the PIN tried).
func _keypad(key_text: String) -> void:
	if state != "pin":
		if key_text != "CORR" and key_text != "OK" and int(key_text) >= 1 and int(key_text) <= OPTION_COUNT:
			_option(int(key_text) - 1)
		elif key_text == "OK":
			_option(0)
		return
	sound("toets")
	match key_text:
		"CORR":
			entered = entered.substr(0, maxi(entered.length() - 1, 0))
			_show_pin()
		"OK":
			enter_pin(entered)
		_:
			if entered.length() < 4:
				entered += key_text
			_show_pin()


## The PIN tried (the keypad's OK): right, wrong, or the card kept.
func enter_pin(pin: String) -> String:
	if state != "pin":
		return ""
	if pin.length() < 4:
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
			state = "klaar"
			_busy = true
			sound("fout")
			show_display("PINCODE ONJUIST", ["3 keer fout.", "", "UW PAS IS INGEHOUDEN.", "Neem contact op met uw bank."], WARNING)
			await pause_for(0.5)
			sound("inslikken")
			show_tray("INGESLIKT", ["De automaat houdt de pas.", "Weg is pas %d." % int(card.nummer)], WARNING)
			card = {}
			refresh_pockets()
			await pause_for(2.2)
			_busy = false
			_show_start()
	return result


func _show_menu() -> void:
	state = "menu"
	var balance := float(card.get("saldo", 0.0))
	show_display("KIES EEN BEDRAG", ["Saldo: " + euros(balance), "", "[1]-[4] bedrag   [ESC] stoppen"])
	var choices: Array = []
	for index in AMOUNTS.size():
		var amount: float = AMOUNTS[index]
		var text := "[%d] %s" % [index + 1, euros(amount)]
		if amount > balance + 0.001:
			text += "  (te weinig)"
		choices.append([text, withdraw.bind(amount)])
	_set_options(choices)


## The money out (if the balance allows): the whirr, the notes, the card back first.
func withdraw(amount: float) -> bool:
	if state != "menu":
		return false
	if amount > float(card.get("saldo", 0.0)) + 0.001:
		sound("fout")
		show_display("SALDO ONTOEREIKEND", ["Saldo: " + euros(float(card.saldo)), "", "Kies een lager bedrag."], WARNING)
		await pause_for(1.4)
		if state == "menu":
			_show_menu()
		return false
	state = "bezig"
	_busy = true
	_set_options([])
	show_display("EEN MOMENT...", ["Uw geld wordt geteld."])
	BankCards.withdraw(player, card, amount)
	paid_out += amount
	sound("geld")
	await pause_for(1.1)
	var notes := _notes_for(amount)
	show_tray("NEEM UW GELD", [euros(amount)] + notes + ["", "Nieuw saldo: " + euros(float(card.saldo))], GOOD)
	refresh_pockets()
	await pause_for(0.8)
	_busy = false
	state = "menu"
	_show_menu()
	return true


## The notes of `amount`, as "1 × € 20" lines.
static func _notes_for(amount: float) -> Array:
	var left := roundi(amount)
	var lines: Array = []
	for note: int in [50, 20, 10, 5]:
		if left >= note:
			lines.append("%d × biljet van € %d" % [left / note, note])
			left %= note
	return lines


func _set_options(choices: Array) -> void:
	for index in _options.size():
		var shown := index < choices.size()
		_options[index].visible = shown
		_options[index].text = String(choices[index][0]) if shown else ""
		_option_actions[index] = choices[index][1] if shown else Callable()


func _option(index: int) -> void:
	if index < _option_actions.size() and _option_actions[index].is_valid() and _options[index].visible:
		sound("toets")
		_option_actions[index].call()


static func _digit_of(keycode: Key) -> String:
	if keycode >= KEY_0 and keycode <= KEY_9:
		return str(keycode - KEY_0)
	if keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		return str(keycode - KEY_KP_0)
	return ""


## The card in the scene, lying flat with its chip first: into the slit of the reader
## (machine_parts "card") and gone; `back`: out of it again, sticking out a moment, then taken.
## Returns when that is over (at once without `animate`).
func _card_motion(back: bool) -> void:
	var slit: Variant = _parts.get("card")
	if not animate or _machine == null or not slit is Vector3:
		return
	var piece := MeshInstance3D.new()
	piece.name = "Pinpas"
	piece.mesh = MachineModels.bank_card_mesh()
	piece.scale = Vector3.ONE * CARD_SCALE
	# flat, its far edge (the chip end) towards the machine
	piece.rotation_degrees.x = -90.0
	var length := 0.2 * CARD_SCALE
	var at_slit: Vector3 = slit
	var before := at_slit + Vector3(0.0, 0.0, length + 0.22)
	var at_mouth := at_slit + Vector3(0.0, 0.0, length)
	var inside := at_slit + Vector3(0.0, 0.0, -0.01)
	(_machine.get_parent() as Node3D).add_child(piece)
	var move := piece.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if back:
		piece.position = inside
		move.tween_property(piece, "position", at_mouth, CARD_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		move.tween_interval(CARD_TAKEN_AFTER)
		move.tween_property(piece, "position", before, CARD_TO_SLOT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		piece.position = before
		move.tween_property(piece, "position", at_mouth, CARD_TO_SLOT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		move.tween_property(piece, "position", inside, CARD_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move.tween_callback(piece.queue_free)
	await move.finished
