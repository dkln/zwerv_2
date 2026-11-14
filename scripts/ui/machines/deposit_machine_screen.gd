extends "res://scripts/ui/machines/machine_screen.gd"
## The deposit machine of a supermarket (STATIEGELD, by the entrance of every DERREK and
## ALFRED STEYHN: scripts/world/interiors/supermarket.gd), close up: put in your empty cans (Items
## "blikje", from the waste bins) and bottles ("statiegeld") one by one: each goes into the
## round hole (it slides in, bottom first, rattles, the belt carries it off) and counts on
## the display. Now and then (REJECT_CHANCE) the machine does not take it: it comes back out
## of the hole, the display says so with a buzz, and you can try again; then the BON key on
## the machine: it prints the bon with what you put in and the total and pays it out at once
## (DepositReturn.pay_out). Leaving with something in it does the same.
## Its little screen only shows (a few big words); you use the machine itself: click its
## hole (a can, or a bottle when you have no cans) and its BON key (the view's machine_parts
## "hotspots"). Keys: 1 a can, 2 a bottle, Enter the bon, Esc away.
## This is the behaviour layer: what went in, the steps (one in, the bon printed, paid out)
## and the keys. deposit_machine_screen_rules.gd has the logic (what the screen, the bon and
## the panel say, what a key does), deposit_machine_screen_layout.gd says where its parts
## are, deposit_machine_screen_view.gd builds the machine and shows what it is handed
## (`machine_view`, the `view` of the screen).
##   DepositMachineScreen.show_for(player, "DERREK")

const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
const Items = preload("res://scripts/player/items.gd")
const DepositMachineScreenRules = preload("res://scripts/ui/machines/deposit_machine_screen_rules.gd")
const DepositMachineScreenView = preload("res://scripts/ui/machines/deposit_machine_screen_view.gd")
const SCRIPT_PATH := "res://scripts/ui/machines/deposit_machine_screen.gd"
const NAMES := DepositMachineScreenRules.NAMES
const REJECT_CHANCE := DepositMachineScreenRules.REJECT_CHANCE
## The tones of a refusal on the display and of the bon in the tray.
const REFUSED := MachineScreenRules.TONE_REFUSED
const PAPER := MachineScreenRules.TONE_PAPER
## Seconds the out-of-order display shows before the screen closes by itself.
const OUT_OF_ORDER_SECONDS := DepositMachineScreenRules.OUT_OF_ORDER_SECONDS
## How much softer the belt and the coins sound (dB).
const BELT_SOFTER := -4.0
const COINS_SOFTER := -2.0

## What went in this time: item id -> count, and its worth.
var inserted := {}
var total := 0.0
## "invoeren", "bon" (printed, not taken yet), "klaar".
var state := DepositMachineScreenRules.STATE_INSERTING
## The checks: true makes the next can or bottle come back out (else REJECT_CHANCE, and
## never without `animate`).
var force_reject := false
## The text on the display when this machine is out of order (Story.machine_out_of_order: the
## first one tried in the first mission); "" when it works. Out of order it takes nothing.
var out_of_order := ""
## The view of the screen, as the deposit machine's own.
var machine_view: DepositMachineScreenView


static func show_for(for_player: Node, place := "", with_animation := true, broken := "") -> CanvasLayer:
	var screen: CanvasLayer = (load(SCRIPT_PATH) as GDScript).new()
	screen.set("out_of_order", broken)
	screen.set("brand", DepositMachineScreenRules.BRAND)
	screen.set("place_name", place)
	screen.set("backdrop", DepositMachineScreenRules.BACKDROP)
	return present(screen, for_player, with_animation)


func _init() -> void:
	machine_view = DepositMachineScreenView.new()
	view = machine_view


func _opened() -> void:
	if DepositMachineScreenRules.is_broken(out_of_order):
		_show_out_of_order()
		_close_soon()
		return
	_show_count()


## Out of order: the buzz, a moment to read the display, then the screen closes by itself (the
## story's thought about it comes right after, Story.machine_out_of_order).
func _close_soon() -> void:
	sound("fout")
	await pause_for(OUT_OF_ORDER_SECONDS)
	if is_inside_tree() and not is_closing():
		close()


## Out of order: the text on the display, a buzz when you try.
func _show_out_of_order() -> void:
	show_display(DepositMachineScreenRules.out_of_order_title(out_of_order), DepositMachineScreenRules.out_of_order_lines(out_of_order), REFUSED)


## Out of order: the buzz and the display again; true when it is (nothing else happens then).
func _refuses_broken() -> bool:
	if not DepositMachineScreenRules.is_broken(out_of_order):
		return false
	sound("fout")
	_show_out_of_order()
	return true


## A part of the machine clicked: the hole takes a can (or a bottle when you have no cans),
## the BON key prints the bon and pays it out.
func hotspot_pressed(hotspot: String) -> void:
	match hotspot:
		DepositMachineScreenRules.HOLE:
			insert_next()
		DepositMachineScreenRules.BON_KEY:
			bon()


## Into the hole what you have: a can first, else a bottle.
func insert_next() -> float:
	if _refuses_broken():
		return 0.0
	var item_id := DepositMachineScreenRules.next_item(DepositReturn.returnable(_inventory()))
	if item_id != "":
		return await insert_one(item_id)
	sound("fout")
	show_display("LEEG?", ["NIETS OM IN", "TE LEVEREN"], REFUSED)
	return 0.0


## The BON key: the bon printed and taken at once (the money in your wallet).
func bon() -> void:
	if _refuses_broken():
		return
	if state != DepositMachineScreenRules.STATE_INSERTING:
		return
	await print_bon()
	if state == DepositMachineScreenRules.STATE_BON:
		await pause_for(DepositMachineScreenRules.BON_TAKEN_SECONDS)
		await take_bon()


func pocket_lines() -> Array:
	var item_names := {}
	for item_id: String in DepositReturn.ORDER:
		item_names[item_id] = String(Items.item(item_id).get("name", item_id))
	return DepositMachineScreenRules.pocket_lines(_money(), DepositReturn.returnable(_inventory()), item_names)


func key_hints() -> String:
	return DepositMachineScreenRules.KEY_HINTS


func _key(keycode: Key) -> bool:
	match DepositMachineScreenRules.key_action(state, keycode):
		DepositMachineScreenRules.ACTION_TAKE_BON:
			take_bon()
		DepositMachineScreenRules.ACTION_CAN:
			insert_one(DepositMachineScreenRules.CAN)
		DepositMachineScreenRules.ACTION_BOTTLE:
			insert_one(DepositMachineScreenRules.BOTTLE)
		DepositMachineScreenRules.ACTION_BON:
			bon()
	return true


## Esc: with something in it the bon first (and taken), then away.
func cancel() -> void:
	if state == DepositMachineScreenRules.STATE_INSERTING and total > 0.0:
		await print_bon()
	if state == DepositMachineScreenRules.STATE_BON:
		await take_bon()
		return
	close()


## One can or bottle in: it slides into the hole, the belt takes it, it counts. Now and then
## it comes back out (_rejected): an error on the display and a buzz, it stays in your pockets.
func insert_one(item_id: String) -> float:
	if state != DepositMachineScreenRules.STATE_INSERTING:
		return 0.0
	if _refuses_broken():
		return 0.0
	if not DepositMachineScreenRules.can_insert(item_id, _inventory()):
		sound("fout")
		show_display(DepositMachineScreenRules.missing_title(item_id), ["HEB JE NIET"], REFUSED)
		return 0.0
	busy = true
	var rejected := _rejected()
	sound("blik")
	await machine_view.play_into_hole(item_id == DepositMachineScreenRules.BOTTLE, rejected)
	if rejected:
		sound("fout")
		show_display("NIET HERKEND", ["PROBEER", "OPNIEUW"], REFUSED)
		busy = false
		return 0.0
	var value := DepositReturn.insert_one(player, item_id)
	inserted = DepositMachineScreenRules.inserted_after(inserted, item_id)
	total = DepositMachineScreenRules.total_after(total, value)
	await pause_for(DepositMachineScreenRules.COUNT_SECONDS)
	sound("band", BELT_SOFTER)
	_show_count()
	refresh_pockets()
	await pause_for(DepositMachineScreenRules.BELT_SECONDS)
	busy = false
	return value


## Whether this can or bottle comes back out: force_reject (the checks), else now and then
## (REJECT_CHANCE), never without `animate`.
func _rejected() -> bool:
	if force_reject:
		force_reject = false
		return true
	return animate and DepositMachineScreenRules.comes_back(randf())


## The bon printed: what went in and the total (nothing in: it says so).
func print_bon() -> void:
	if state != DepositMachineScreenRules.STATE_INSERTING:
		return
	if total <= 0.0:
		sound("fout")
		show_display("NIETS", ["INGEVOERD"], REFUSED)
		return
	busy = true
	show_display("EVEN", ["GEDULD..."])
	sound("printer")
	await pause_for(DepositMachineScreenRules.PRINT_SECONDS)
	state = DepositMachineScreenRules.STATE_BON
	show_tray("STATIEGELDBON", DepositMachineScreenRules.bon_lines(inserted, total), PAPER)
	show_display("BEDANKT", [MoneyText.euros(total)])
	busy = false


## The bon taken: its worth in your wallet (cashed at once), then away.
func take_bon() -> void:
	if state != DepositMachineScreenRules.STATE_BON:
		return
	state = DepositMachineScreenRules.STATE_DONE
	DepositReturn.pay_out(player, total)
	UiSounds.play(self, "munt", COINS_SOFTER)
	show_tray("UITBETAALD", DepositMachineScreenRules.paid_lines(total), GOOD)
	refresh_pockets()
	busy = true
	await pause_for(DepositMachineScreenRules.PAID_SECONDS)
	busy = false
	close()


func _show_count() -> void:
	show_display("STATIEGELD", DepositMachineScreenRules.count_lines(inserted, total))
