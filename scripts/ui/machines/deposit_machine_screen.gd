extends "res://scripts/ui/machines/machine_screen.gd"
## The deposit machine of a supermarket (STATIEGELD, by the entrance of every DERREK and
## ALFRED STEYHN: scripts/world/interiors/supermarket.gd), close up: put in your empty cans (Items
## "blikje", from the waste bins) and bottles ("statiegeld") one by one: each goes into the
## round hole (it slides in, rattles, the belt carries it off) and counts on the display;
## then BON: the machine prints the bon with what you put in and the total, and taking the
## bon pays it out (DepositReturn.pay_out). Leaving with something in it prints the bon too.
## Keys: 1 a can, 2 a bottle, Enter the bon (then Enter takes it), Esc away; the mouse too.
##   DepositMachineScreen.show_for(player, "DERREK")

const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
const Items = preload("res://scripts/player/items.gd")
const SCRIPT_PATH := "res://scripts/ui/machines/deposit_machine_screen.gd"
const NAMES := {"blikje": "BLIKJE", "statiegeld": "FLES"}

## What went in this time: item id -> count, and its worth.
var inserted := {}
var total := 0.0
## "invoeren", "bon" (printed, not taken yet), "klaar".
var state := "invoeren"
var _insert_buttons := {}
var _bon_button: Button
var _hole: Panel
var _flying: Control


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
	return {"mesh": MachineModels.deposit_machine_mesh(), "screen": Rect2(-0.1875, 1.25, 0.375, 0.25), "front": 0.3125,
		"keys": Vector3(0.28, 0.84, 0.3125), "slot": Vector3(0.28, 0.59, 0.3125)}


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


## One can or bottle in: it slides into the hole, the belt takes it, it counts.
func insert_one(item_id: String) -> float:
	if state != "invoeren":
		return 0.0
	var value := DepositReturn.insert_one(player, item_id)
	if value <= 0.0:
		sound("fout")
		show_display("GEEN %s" % String(NAMES.get(item_id, "VERPAKKING")), ["Je hebt er geen bij je."] + _count_lines(), Color("#FFB547"))
		return 0.0
	inserted[item_id] = int(inserted.get(item_id, 0)) + 1
	total = snappedf(total + value, 0.01)
	_busy = true
	_fly_in(item_id)
	sound("blik")
	await pause_for(0.35)
	sound("band", -4.0)
	_show_count()
	refresh_pockets()
	await pause_for(0.3)
	_busy = false
	return value


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
