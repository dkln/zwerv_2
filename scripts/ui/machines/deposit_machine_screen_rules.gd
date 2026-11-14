extends RefCounted
## The logic of the deposit machine (the rules layer of
## scripts/ui/machines/deposit_machine_screen.gd, which is the behaviour;
## deposit_machine_screen_layout.gd says where its parts are, deposit_machine_screen_view.gd
## builds and shows it): its states, what its little screen, the bon and the panel say, what
## a key does, what goes into the hole next, and how often it gives one back. Plain
## functions, without nodes: what a can or bottle is worth is DepositReturn
## (scripts/world/things/deposit_return.gd).
##   const DepositMachineScreenRules = preload("res://scripts/ui/machines/deposit_machine_screen_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")
const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")

const BRAND := "STATIEGELD"
const BACKDROP := "supermarkt"
## The states: putting in, the bon printed (not taken yet), done.
const STATE_INSERTING := "invoeren"
const STATE_BON := "bon"
const STATE_DONE := "klaar"
## What the machine calls a can and a bottle.
const NAMES := {"blikje": "BLIKJE", "statiegeld": "FLES"}
const CAN := "blikje"
const BOTTLE := "statiegeld"
## The parts of the machine you can click (the view's machine_parts "hotspots").
const HOLE := "gat"
const BON_KEY := "bon"
## How often a can or bottle comes back out (not recognised).
const REJECT_CHANCE := 0.06
## The seconds the machine takes: the out-of-order display before the screen closes by
## itself, counting one in, the belt, printing, between the bon and its money, the money shown.
const OUT_OF_ORDER_SECONDS := 2.2
const COUNT_SECONDS := 0.15
const BELT_SECONDS := 0.3
const PRINT_SECONDS := 0.7
const BON_TAKEN_SECONDS := 0.5
const PAID_SECONDS := 1.3
const KEY_HINTS := "[KLIK] GAT / BON-KNOP   [1] BLIKJE   [2] FLES   [ENTER] BON   [ESC] WEG"
## What the keys do (key_action).
const ACTION_NONE := ""
const ACTION_CAN := "blikje"
const ACTION_BOTTLE := "fles"
const ACTION_BON := "bon"
const ACTION_TAKE_BON := "bon_nemen"
## The tones of the lines of the panel (as MachineScreenRules.TONE_*).
const TONE_TEXT := "tekst"
const TONE_ACCENT := "accent"
const TONE_MUTED := "gedempt"


## What a key does in `state`: with the bon printed Enter or Space takes it; before that 1 a
## can, 2 a bottle, Enter the bon.
static func key_action(state: String, keycode: Key) -> String:
	if state == STATE_BON:
		return ACTION_TAKE_BON if keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE else ACTION_NONE
	match keycode:
		KEY_1, KEY_KP_1:
			return ACTION_CAN
		KEY_2, KEY_KP_2:
			return ACTION_BOTTLE
		KEY_ENTER, KEY_KP_ENTER:
			return ACTION_BON
	return ACTION_NONE


## What goes into the hole of what you have (`found`: DepositReturn.returnable): a can
## first, else a bottle; "" when you have neither.
static func next_item(found: Dictionary) -> String:
	for item_id: String in DepositReturn.ORDER:
		if found.has(item_id):
			return item_id
	return ""


## Whether the machine takes `item_id` of `inventory`: it has a deposit and you have one.
static func can_insert(item_id: String, inventory: Dictionary) -> bool:
	return DepositReturn.DEPOSIT.has(item_id) and int(inventory.get(item_id, 0)) > 0


## Whether the can or bottle comes back out, `roll` being a throw of 0..1.
static func comes_back(roll: float) -> bool:
	return roll < REJECT_CHANCE


## The total after `value` more went in (whole cents).
static func total_after(total: float, value: float) -> float:
	return snappedf(total + value, 0.01)


## What went in so far after one more `item_id`: item id -> count.
static func inserted_after(inserted: Dictionary, item_id: String) -> Dictionary:
	var counts := inserted.duplicate()
	counts[item_id] = int(counts.get(item_id, 0)) + 1
	return counts


## Whether the machine is out of order (`out_of_order`: the text for its display, "" when
## it works).
static func is_broken(out_of_order: String) -> bool:
	return out_of_order != ""


# ------------------------------------------------------------------ the display

## The title of the out-of-order display: the first word of its text.
static func out_of_order_title(out_of_order: String) -> String:
	var words := out_of_order.split(" ", false)
	return words[0] if words.size() > 0 else "STORING"


## The lines of the out-of-order display: a word each, after the first.
static func out_of_order_lines(out_of_order: String) -> Array:
	return Array(out_of_order.split(" ", false).slice(1))


## The title when you have no `item_id` to put in.
static func missing_title(item_id: String) -> String:
	return "GEEN %s" % String(NAMES.get(item_id, "VERPAKKING"))


## The lines under "STATIEGELD": how many went in and what they are worth.
static func count_lines(inserted: Dictionary, total: float) -> Array:
	var count := 0
	for item_id: String in inserted:
		count += int(inserted[item_id])
	return ["%d STUKS" % count, MoneyText.euros(total)]


## The lines of the bon: what went in (`inserted_counts`: item id -> count, cans first) with
## its worth, a line, and the total.
static func bon_lines(inserted_counts: Dictionary, total_worth: float) -> Array:
	var lines: Array = []
	for item_id: String in DepositReturn.ORDER:
		var count := int(inserted_counts.get(item_id, 0))
		if count > 0:
			lines.append("%d × %s   %s" % [count, String(NAMES[item_id]), MoneyText.euros(count * float(DepositReturn.DEPOSIT[item_id]))])
	lines.append("----------------")
	lines.append("TOTAAL   " + MoneyText.euros(total_worth))
	return lines


## What the tray says when the bon is paid out.
static func paid_lines(total: float) -> Array:
	return [MoneyText.euros(total), "", "De bon is verzilverd: het geld zit in je portemonnee."]


# ------------------------------------------------------------------ the panel

## What the panel lists of your pockets: your money, your cans and bottles (`found`:
## DepositReturn.returnable; `item_names`: item id -> its name) with what each is worth, and
## where to find them when you have none; [text, tone] each.
static func pocket_lines(money: float, found: Dictionary, item_names: Dictionary) -> Array:
	var lines: Array = [["GELD  " + MoneyText.euros(money), TONE_TEXT]]
	for item_id: String in DepositReturn.ORDER:
		var count := int(found.get(item_id, 0))
		lines.append(["%s  %d×  (%s per stuk)" % [String(item_names.get(item_id, item_id)), count,
			MoneyText.euros(float(DepositReturn.DEPOSIT[item_id]))], TONE_ACCENT if count > 0 else TONE_MUTED])
	if found.is_empty():
		lines.append(["Lege blikjes liggen soms in de prullenbakken op straat.", TONE_MUTED])
	return lines
