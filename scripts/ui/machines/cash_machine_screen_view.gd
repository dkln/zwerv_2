extends "res://scripts/ui/machines/machine_screen_view.gd"
## How the cash machine looks (the graphics layer of
## scripts/ui/machines/cash_machine_screen.gd, which is the behaviour and has this as its
## view; cash_machine_screen_rules.gd has the logic, cash_machine_screen_layout.gd says where
## its parts are): the view of a machine (machine_screen_view.gd) with the model of the cash
## machine of the town, its colours, on its touch screen the keypad (shown while the PIN is
## asked: show_keypad), the choices and STOP, the logo of its bank over the welcome
## (add_logo, show_logo) and your card going into the reader and coming back (play_card).
## It decides nothing: a key of the keypad and STOP it only passes on (keypad_pressed,
## stop_pressed; the choices: option_pressed).
##   const CashMachineScreenView = preload("res://scripts/ui/machines/cash_machine_screen_view.gd")

const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const BankLogo = preload("res://scripts/ui/widgets/bank_logo.gd")
const CashMachineScreenLayout = preload("res://scripts/ui/machines/cash_machine_screen_layout.gd")
const BODY := Color("#3A4250")
const TRIM := Color("#F2B705")
const SCREEN := Color("#5FE0FF")
const CORRECT_KEY := Color("#C8A020")
const OK_KEY := Color("#2E9A48")
const STOP_KEY := Color("#B8302A")
const STOP_TEXT := "STOP"
const LOGO_NAME := "Banklogo"
const CARD_NAME := "Pinpas"
## The seconds the card takes to the slot, into it, and the time it sticks out before it is
## taken back.
const CARD_TO_SLOT := 0.3
const CARD_IN := 0.35
const CARD_TAKEN_AFTER := 0.6

## A key of the keypad on the screen was used: a digit, "CORR" or "OK".
signal keypad_pressed(key_text: String)
## STOP on the screen was used.
signal stop_pressed

var _logo: Control
var _keypad: GridContainer


func _init() -> void:
	body_colour = BODY
	trim_colour = TRIM
	screen_colour = SCREEN


## The cash machine of the town (MachineModels.cash_machine_mesh): its model and where its
## screen, keypad, slot and card reader are.
func machine_parts() -> Dictionary:
	var made := CashMachineScreenLayout.parts()
	made["mesh"] = MachineModels.cash_machine_mesh()
	return made


## On the touch screen: the keypad (hidden until the PIN is asked), the choices and STOP.
func build_controls(box: VBoxContainer) -> void:
	_keypad = GridContainer.new()
	_keypad.columns = CashMachineScreenLayout.KEYPAD_COLUMNS
	_keypad.add_theme_constant_override("h_separation", CashMachineScreenLayout.KEYPAD_SEPARATION)
	_keypad.add_theme_constant_override("v_separation", CashMachineScreenLayout.KEYPAD_SEPARATION)
	for key_text: String in CashMachineScreenLayout.KEYPAD_KEYS:
		_keypad.add_child(button(key_text, keypad_pressed.emit.bind(key_text), CashMachineScreenLayout.KEYPAD_KEY_WIDTH, _key_colour(key_text)))
	_keypad.visible = false
	box.add_child(_keypad)
	add_options(box, CashMachineScreenLayout.OPTION_COUNT)
	box.add_child(button(STOP_TEXT, stop_pressed.emit, 0.0, STOP_KEY))


static func _key_colour(key_text: String) -> Color:
	match key_text:
		"CORR":
			return CORRECT_KEY
		"OK":
			return OK_KEY
	return NO_COLOUR


## Puts the logo of bank `bank` over what the screen says.
func add_logo(bank: String) -> void:
	_logo = BankLogo.new()
	_logo.name = LOGO_NAME
	_logo.show_bank(bank, UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	var column := display().column()
	column.add_child(_logo)
	column.move_child(_logo, 0)


## The bank's logo shows (the welcome) or not.
func show_logo(on: bool) -> void:
	if _logo:
		_logo.visible = on


## The keypad shows (the PIN is asked) or not.
func show_keypad(on: bool) -> void:
	if _keypad:
		_keypad.visible = on


func logo() -> Control:
	return _logo


func keypad() -> GridContainer:
	return _keypad


## The card in the scene, lying flat with its chip first: into the slit of the reader
## (machine_parts "card") and gone; `back`: out of it again, sticking out a moment, then taken.
## Returns when that is over (at once without `animate`).
func play_card(back: bool) -> void:
	var slit: Variant = parts().get("card")
	if not animate or not slit is Vector3:
		return
	var piece := MeshInstance3D.new()
	piece.name = CARD_NAME
	piece.mesh = MachineModels.bank_card_mesh()
	piece.scale = Vector3.ONE * CashMachineScreenLayout.CARD_SCALE
	# flat, its far edge (the chip end) towards the machine
	piece.rotation_degrees.x = -90.0
	var before := CashMachineScreenLayout.card_before(slit)
	var at_mouth := CashMachineScreenLayout.card_at_mouth(slit)
	var inside := CashMachineScreenLayout.card_inside(slit)
	if not stage().add_piece(piece):
		piece.free()
		return
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
