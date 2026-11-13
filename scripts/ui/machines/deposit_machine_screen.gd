extends "res://scripts/ui/machines/machine_screen.gd"
## The deposit machine of a supermarket (STATIEGELD, by the entrance of every DERREK and
## ALFRED STEYHN: scripts/world/interiors/supermarket.gd), close up: put in your empty cans (Items
## "blikje", from the waste bins) and bottles ("statiegeld") one by one: each goes into the
## round hole (it slides in, bottom first, rattles, the belt carries it off) and counts on
## the display. Now and then (REJECT_CHANCE) the machine does not take it: it comes back out
## of the hole, the display says so with a buzz, and you can try again;
## then BON: the machine prints the bon with what you put in and the total, and taking the
## bon pays it out (DepositReturn.pay_out). Leaving with something in it prints the bon too.
## Keys: 1 a can, 2 a bottle, Enter the bon (then Enter takes it), Esc away; the mouse too.
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
var _insert_buttons := {}
var _bon_button: Button
var _hole: Panel
var _flying: Control
## The checks: true makes the next can or bottle come back out (else REJECT_CHANCE, and
## never without `animate`).
var force_reject := false


static func show_for(for_player: Node, place := "", with_animation := true) -> CanvasLayer:
	var screen: CanvasLayer = (load(SCRIPT_PATH) as GDScript).new()
	screen.set("brand", "STATIEGELD")
	screen.set("body_colour", Color("#E8ECEA"))
	screen.set("trim_colour", Color("#2E9A48"))
	screen.set("screen_colour", Color("#9CFF7A"))
	screen.set("place_name", place)
	screen.set("backdrop", "supermarkt")
	return present(screen, for_player, with_animation)


## The deposit machine of the supermarkets (MachineModels.deposit_machine_mesh, 14 x 30 x
## 10 voxels of 6,25 cm): its little screen, the button by it and the slot of the bon.
func machine_parts() -> Dictionary:
	return {"mesh": MachineModels.deposit_machine_mesh(), "screen": Rect2(-0.125, 1.375, 0.25, 0.1875), "front": 0.3125,
		"screen_sunk": 0.125, "keys": Vector3(0.28, 1.47, 0.3125), "slot": Vector3(0.28, 1.22, 0.3125),
		"hole": Vector3(0.0, 0.97, 0.3125)}


func _opened() -> void:
	_show_count()


func build_controls(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	# the round hole: a dark mouth in a steel collar
	var collar := PanelContainer.new()
	collar.add_theme_stylebox_override("panel", UiStyle.box_style(Color("#8C939E"), Color("#5A606A"), 4))
	collar.custom_minimum_size = Vector2(150, 150)
	_hole = Panel.new()
	var mouth := UiStyle.box_style(Color("#0A0B0E"), Color("#2A2C32"), 6)
	mouth.set_corner_radius_all(60)
	mouth.anti_aliasing = false
	_hole.add_theme_stylebox_override("panel", mouth)
	_hole.custom_minimum_size = Vector2(130, 130)
	_hole.clip_contents = true
	collar.add_child(_hole)
	row.add_child(collar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in DepositReturn.ORDER.size():
		var item_id: String = DepositReturn.ORDER[index]
		var insert := button("", insert_one.bind(item_id), 0, Color("#2E7A40"))
		insert.alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(insert)
		_insert_buttons[item_id] = insert
	_bon_button = button("[ENTER] BON", print_bon, 0, Color("#C8A020"))
	column.add_child(_bon_button)
	column.add_child(button("[ESC] WEG", cancel, 0, Color("#7A7E86")))
	row.add_child(column)
	var hint := label("Plaats de verpakking met de bodem eerst in de opening.", font_body, 13, Color("#3A4038"))
	box.add_child(hint)


func pocket_lines() -> Array:
	var lines: Array = [["GELD  " + euros(_money()), UiStyle.TEXT]]
	var found := DepositReturn.returnable(_inventory())
	for item_id: String in DepositReturn.ORDER:
		var count := int(found.get(item_id, 0))
		lines.append(["%s  %d×  (%s per stuk)" % [String(Items.item(item_id).get("name", item_id)), count,
			euros(float(DepositReturn.DEPOSIT[item_id]))], UiStyle.ACCENT if count > 0 else UiStyle.MUTED])
	if found.is_empty():
		lines.append(["Lege blikjes liggen soms in de prullenbakken op straat.", UiStyle.MUTED])
	return lines


func key_hints() -> String:
	return "[1] BLIKJE   [2] FLES   [ENTER] BON   [ESC] WEG"


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
			print_bon()
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
	if not DepositReturn.DEPOSIT.has(item_id) or int(_inventory().get(item_id, 0)) <= 0:
		sound("fout")
		show_display("GEEN %s" % String(NAMES.get(item_id, "VERPAKKING")), ["Je hebt er geen bij je."] + _count_lines(), REFUSED)
		return 0.0
	_busy = true
	var rejected := _rejected()
	_fly_in(item_id)
	sound("blik")
	await _into_hole(item_id, rejected)
	if rejected:
		sound("fout")
		show_display("NIET HERKEND", ["De %s komt terug." % String(NAMES[item_id]).to_lower(), "Probeer het nog een keer."] + _count_lines(), REFUSED)
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
		show_display("NIETS INGEVOERD", ["Plaats eerst een blikje of fles."], Color("#FFB547"))
		return
	_busy = true
	show_display("BON WORDT GEPRINT", ["Even geduld..."])
	sound("printer")
	await pause_for(0.7)
	state = "bon"
	var lines: Array = []
	for item_id: String in DepositReturn.ORDER:
		var count := int(inserted.get(item_id, 0))
		if count > 0:
			lines.append("%d × %s   %s" % [count, String(NAMES[item_id]), euros(count * float(DepositReturn.DEPOSIT[item_id]))])
	lines.append("----------------")
	lines.append("TOTAAL   " + euros(total))
	lines.append("")
	lines.append("[ENTER] Bon pakken")
	show_tray("STATIEGELDBON", lines, Color("#F2F2EC"))
	show_display("NEEM UW BON", ["Totaal: " + euros(total), "", "Bedankt voor het inleveren!"])
	_busy = false


## The bon taken: its worth in your wallet (cashed at once), then away.
func take_bon() -> void:
	if state != "bon":
		return
	state = "klaar"
	DepositReturn.pay_out(player, total)
	UiSounds.play(self, "munt", -2.0)
	show_tray("UITBETAALD", [euros(total), "", "De bon is verzilverd: het geld zit in je portemonnee."], GOOD)
	refresh_pockets()
	_busy = true
	await pause_for(1.3)
	_busy = false
	close()


func _show_count() -> void:
	show_display("STATIEGELD", ["Plaats uw blikjes en flessen", "één voor één in de opening.", ""] + _count_lines())
	for item_id: String in _insert_buttons:
		var count := int(_inventory().get(item_id, 0))
		(_insert_buttons[item_id] as Button).text = "[%d] %s ERIN  (%d)" % [DepositReturn.ORDER.find(item_id) + 1, String(NAMES[item_id]), count]


func _count_lines() -> Array:
	var count := 0
	for item_id: String in inserted:
		count += int(inserted[item_id])
	return ["Ingevoerd: %d   %s" % [count, euros(total)]]


## The can or bottle sliding into the hole and away.
func _fly_in(item_id: String) -> void:
	if not animate or _hole == null:
		return
	if _flying and is_instance_valid(_flying):
		_flying.queue_free()
	# the item's own pixel icon (the game menu's: "blik", "flessen")
	var icon_name := String(Items.item(item_id).get("icon", "blik"))
	var icon := PixelIcon.new()
	icon.pixel = 6.0
	var icons: Dictionary = GameMenu.ITEM_ICONS
	if icons.has(icon_name):
		icon.bitmap = icons[icon_name].rows
		icon.colour = icons[icon_name].colour
	_flying = icon
	_flying.position = Vector2(40, -70)
	_hole.add_child(_flying)
	var slide := _flying.create_tween()
	slide.tween_property(_flying, "position", Vector2(40, 25), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide.tween_property(_flying, "scale", Vector2(0.4, 0.4), 0.3)
	slide.parallel().tween_property(_flying, "modulate:a", 0.0, 0.3)
	slide.tween_callback(_flying.queue_free)
