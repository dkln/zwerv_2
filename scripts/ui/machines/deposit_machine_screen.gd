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
## hole (a can, or a bottle when you have no cans) and its BON key (machine_parts
## "hotspots"). Keys: 1 a can, 2 a bottle, Enter the bon, Esc away.
##   DepositMachineScreen.show_for(player, "DERREK")

const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
const Items = preload("res://scripts/player/items.gd")
const SCRIPT_PATH := "res://scripts/ui/machines/deposit_machine_screen.gd"
const NAMES := {"blikje": "BLIKJE", "statiegeld": "FLES"}
## How often a can or bottle comes back out (not recognised), and the colour of that message.
const REJECT_CHANCE := 0.06
const REFUSED := Color("#FFB547")
## The can or bottle going in: from how far before the hole (m), how far into it, and the
## seconds to the hole, into it, waiting in it and back out (refused).
const INSERT_FROM := 0.32
const INSERT_DEEP := 0.26
const TO_HOLE_SECONDS := 0.22
const INTO_HOLE_SECONDS := 0.28
const WAIT_IN_HOLE_SECONDS := 0.35
const BACK_OUT_SECONDS := 0.3

## What went in this time: item id -> count, and its worth.
var inserted := {}
var total := 0.0
## "invoeren", "bon" (printed, not taken yet), "klaar".
var state := "invoeren"
## The checks: true makes the next can or bottle come back out (else REJECT_CHANCE, and
## never without `animate`).
var force_reject := false
## The text on the display when this machine is out of order (Story.machine_out_of_order: the
## first one tried in the first mission); "" when it works. Out of order it takes nothing.
var out_of_order := ""
## Seconds the out-of-order display shows before the screen closes by itself.
const OUT_OF_ORDER_SECONDS := 2.2


static func show_for(for_player: Node, place := "", with_animation := true, broken := "") -> CanvasLayer:
	var screen: CanvasLayer = (load(SCRIPT_PATH) as GDScript).new()
	screen.set("out_of_order", broken)
	screen.set("brand", "STATIEGELD")
	screen.set("body_colour", Color("#E8ECEA"))
	screen.set("trim_colour", Color("#2E9A48"))
	screen.set("screen_colour", Color("#9CFF7A"))
	screen.set("place_name", place)
	screen.set("backdrop", "supermarkt")
	# a little screen: a few big words
	screen.set("display_title_size", 78)
	screen.set("display_text_size", 64)
	return present(screen, for_player, with_animation)


## The deposit machine of the supermarkets (MachineModels.deposit_machine_mesh, 14 x 30 x
## 10 voxels of 6,25 cm): its little screen, the BON key by it and the slot of the bon, the
## hole; the close-up takes in the screen, the key and the hole (all you use), and the hole
## and the key can be clicked.
func machine_parts() -> Dictionary:
	return {"mesh": MachineModels.deposit_machine_mesh(), "screen": Rect2(-0.125, 1.375, 0.25, 0.1875), "front": 0.3125,
		"screen_sunk": 0.125, "keys": Vector3(0.28, 1.47, 0.3125), "slot": Vector3(0.28, 1.22, 0.3125),
		"hole": Vector3(0.0, 0.97, 0.3125),
		"focus": Rect2(-0.25, 0.72, 0.62, 0.92), "focus_share": 0.95,
		"hotspots": [{"name": "gat", "rect": Rect2(-0.1875, 0.75, 0.375, 0.4375)},
			{"name": "bon", "rect": Rect2(0.2, 1.39, 0.16, 0.16)}]}


func _opened() -> void:
	if out_of_order != "":
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
	var words := out_of_order.split(" ", false)
	show_display(words[0] if words.size() > 0 else "STORING", Array(words.slice(1)), REFUSED)


## A part of the machine clicked: the hole takes a can (or a bottle when you have no cans),
## the BON key prints the bon and pays it out.
func hotspot_pressed(hotspot: String) -> void:
	match hotspot:
		"gat":
			insert_next()
		"bon":
			bon()


## Into the hole what you have: a can first, else a bottle.
func insert_next() -> float:
	if out_of_order != "":
		sound("fout")
		_show_out_of_order()
		return 0.0
	var found := DepositReturn.returnable(_inventory())
	for item_id: String in DepositReturn.ORDER:
		if found.has(item_id):
			return await insert_one(item_id)
	sound("fout")
	show_display("LEEG?", ["NIETS OM IN", "TE LEVEREN"], REFUSED)
	return 0.0


## The BON key: the bon printed and taken at once (the money in your wallet).
func bon() -> void:
	if out_of_order != "":
		sound("fout")
		_show_out_of_order()
		return
	if state != "invoeren":
		return
	await print_bon()
	if state == "bon":
		await pause_for(0.5)
		await take_bon()


func pocket_lines() -> Array:
	var lines: Array = [["GELD  " + MoneyText.euros(_money()), UiStyle.TEXT]]
	var found := DepositReturn.returnable(_inventory())
	for item_id: String in DepositReturn.ORDER:
		var count := int(found.get(item_id, 0))
		lines.append(["%s  %d×  (%s per stuk)" % [String(Items.item(item_id).get("name", item_id)), count,
			MoneyText.euros(float(DepositReturn.DEPOSIT[item_id]))], UiStyle.ACCENT if count > 0 else UiStyle.MUTED])
	if found.is_empty():
		lines.append(["Lege blikjes liggen soms in de prullenbakken op straat.", UiStyle.MUTED])
	return lines


func key_hints() -> String:
	return "[KLIK] GAT / BON-KNOP   [1] BLIKJE   [2] FLES   [ENTER] BON   [ESC] WEG"


func _key(keycode: Key) -> bool:
	if state == "bon":
		if keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE:
			take_bon()
		return true
	match keycode:
		KEY_1, KEY_KP_1:
			insert_one("blikje")
		KEY_2, KEY_KP_2:
			insert_one("statiegeld")
		KEY_ENTER, KEY_KP_ENTER:
			bon()
	return true


## Esc: with something in it the bon first (and taken), then away.
func cancel() -> void:
	if state == "invoeren" and total > 0.0:
		await print_bon()
	if state == "bon":
		await take_bon()
		return
	close()


## One can or bottle in: it slides into the hole, the belt takes it, it counts. Now and then
## it comes back out (_rejected): an error on the display and a buzz, it stays in your pockets.
func insert_one(item_id: String) -> float:
	if state != "invoeren":
		return 0.0
	if out_of_order != "":
		sound("fout")
		_show_out_of_order()
		return 0.0
	if not DepositReturn.DEPOSIT.has(item_id) or int(_inventory().get(item_id, 0)) <= 0:
		sound("fout")
		show_display("GEEN %s" % String(NAMES.get(item_id, "VERPAKKING")), ["HEB JE NIET"], REFUSED)
		return 0.0
	_busy = true
	var rejected := _rejected()
	sound("blik")
	await _into_hole(item_id, rejected)
	if rejected:
		sound("fout")
		show_display("NIET HERKEND", ["PROBEER", "OPNIEUW"], REFUSED)
		_busy = false
		return 0.0
	var value := DepositReturn.insert_one(player, item_id)
	inserted[item_id] = int(inserted.get(item_id, 0)) + 1
	total = snappedf(total + value, 0.01)
	await pause_for(0.15)
	sound("band", -4.0)
	_show_count()
	refresh_pockets()
	await pause_for(0.3)
	_busy = false
	return value


## Whether this can or bottle comes back out: force_reject (the checks), else now and then
## (REJECT_CHANCE), never without `animate`.
func _rejected() -> bool:
	if force_reject:
		force_reject = false
		return true
	return animate and randf() < REJECT_CHANCE


## The can or bottle in the scene: lying, bottom first, it comes from before the hole
## (machine_parts "hole"), slides in and is gone; `rejected`: it waits a moment in the hole
## and slides back out to where it came from. Returns when that is over (at once without
## `animate`).
func _into_hole(item_id: String, rejected: bool) -> void:
	var hole: Variant = _parts.get("hole")
	if not animate or _machine == null or not hole is Vector3:
		return
	var thing := MeshInstance3D.new()
	thing.name = "Verpakking"
	thing.mesh = MachineModels.bottle_mesh() if item_id == "statiegeld" else MachineModels.can_mesh()
	# lying, its bottom (y = 0) towards the machine
	thing.rotation_degrees.x = 90.0
	var mouth: Vector3 = hole
	var before := mouth + Vector3(0.0, -0.04, INSERT_FROM)
	thing.position = before
	(_machine.get_parent() as Node3D).add_child(thing)
	var move := thing.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	move.tween_property(thing, "position", mouth + Vector3(0.0, 0.0, 0.02), TO_HOLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(thing, "position:z", mouth.z - INSERT_DEEP, INTO_HOLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if rejected:
		move.tween_interval(WAIT_IN_HOLE_SECONDS)
		move.tween_property(thing, "position", before, BACK_OUT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		move.tween_interval(0.25)
	move.tween_callback(thing.queue_free)
	await move.finished


## The bon printed: what went in and the total (nothing in: it says so).
func print_bon() -> void:
	if state != "invoeren":
		return
	if total <= 0.0:
		sound("fout")
		show_display("NIETS", ["INGEVOERD"], REFUSED)
		return
	_busy = true
	show_display("EVEN", ["GEDULD..."])
	sound("printer")
	await pause_for(0.7)
	state = "bon"
	var lines: Array = []
	for item_id: String in DepositReturn.ORDER:
		var count := int(inserted.get(item_id, 0))
		if count > 0:
			lines.append("%d × %s   %s" % [count, String(NAMES[item_id]), MoneyText.euros(count * float(DepositReturn.DEPOSIT[item_id]))])
	lines.append("----------------")
	lines.append("TOTAAL   " + MoneyText.euros(total))
	show_tray("STATIEGELDBON", lines, Color("#F2F2EC"))
	show_display("BEDANKT", [MoneyText.euros(total)])
	_busy = false


## The bon taken: its worth in your wallet (cashed at once), then away.
func take_bon() -> void:
	if state != "bon":
		return
	state = "klaar"
	DepositReturn.pay_out(player, total)
	UiSounds.play(self, "munt", -2.0)
	show_tray("UITBETAALD", [MoneyText.euros(total), "", "De bon is verzilverd: het geld zit in je portemonnee."], GOOD)
	refresh_pockets()
	_busy = true
	await pause_for(1.3)
	_busy = false
	close()


func _show_count() -> void:
	show_display("STATIEGELD", _count_lines())


func _count_lines() -> Array:
	var count := 0
	for item_id: String in inserted:
		count += int(inserted[item_id])
	return ["%d STUKS" % count, MoneyText.euros(total)]


