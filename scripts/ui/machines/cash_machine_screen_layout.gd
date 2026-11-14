extends RefCounted
## Where the parts of the cash machine are (the layout layer of
## scripts/ui/machines/cash_machine_screen.gd, which is the behaviour;
## cash_machine_screen_rules.gd has the logic, cash_machine_screen_view.gd builds and shows
## it). On its model (MachineModels.cash_machine_mesh, voxels of 6,25 cm, 12 x 28 x 8;
## metres, the model standing on y = 0, centred, its front facing +z): its screen, keypad,
## the slot the money comes out of, the slit of the card reader, and what the camera comes
## in close on. On its touch screen: the keypad and the choices. And the way of the card
## into the reader and back. Constants and plain functions, without nodes.
##   const CashMachineScreenLayout = preload("res://scripts/ui/machines/cash_machine_screen_layout.gd")

const SCREEN := Rect2(-0.25, 1.0, 0.5, 0.3125)
const FRONT := 0.25
const SCREEN_SUNK := 0.125
const KEYS := Vector3(-0.09, 0.66, 0.25)
const SLOT := Vector3(0.0, 0.28, 0.25)
const CARD_SLIT := Vector3(0.25, 0.78, 0.25)
## The close-up takes in the screen and, under it, the card reader (you see your card go in).
const FOCUS := Rect2(-0.3, 0.72, 0.6, 0.62)
const FOCUS_SHARE := 0.75
## The keypad on the touch screen: its keys row by row, how many in a row, the room between
## them and how wide a key is (px).
const KEYPAD_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CORR", "0", "OK"]
const KEYPAD_COLUMNS := 3
const KEYPAD_SEPARATION := 6
const KEYPAD_KEY_WIDTH := 92.0
## How many choices the touch screen has (a card, an amount).
const OPTION_COUNT := 4
## The card in the scene: its size against the model of a found card
## (MachineModels.bank_card_mesh, 30 x 20 cm: so about 9 x 6 cm), how long that model is
## (m), how far before the slit it starts and how far into it it goes.
const CARD_SCALE := 0.3
const CARD_MODEL_LENGTH := 0.2
const CARD_FROM := 0.22
const CARD_DEEP := 0.01


## Where the parts of the machine are, without its model (the view's machine_parts adds it).
static func parts() -> Dictionary:
	return {"screen": SCREEN, "front": FRONT, "screen_sunk": SCREEN_SUNK, "keys": KEYS, "slot": SLOT, "card": CARD_SLIT,
		"focus": FOCUS, "focus_share": FOCUS_SHARE}


## How long the card is in the scene (m).
static func card_length() -> float:
	return CARD_MODEL_LENGTH * CARD_SCALE


## Where the card is before it goes in (and after it was taken), `slit` being the slit of
## the reader.
static func card_before(slit: Vector3) -> Vector3:
	return slit + Vector3(0.0, 0.0, card_length() + CARD_FROM)


## Where the card is with its far edge at the mouth of the slit (sticking out whole).
static func card_at_mouth(slit: Vector3) -> Vector3:
	return slit + Vector3(0.0, 0.0, card_length())


## Where the card is when it is in the reader.
static func card_inside(slit: Vector3) -> Vector3:
	return slit + Vector3(0.0, 0.0, -CARD_DEEP)
