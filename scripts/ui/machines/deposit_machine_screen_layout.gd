extends RefCounted
## Where the parts of the deposit machine are (the layout layer of
## scripts/ui/machines/deposit_machine_screen.gd, which is the behaviour;
## deposit_machine_screen_rules.gd has the logic, deposit_machine_screen_view.gd builds and
## shows it). On its model (MachineModels.deposit_machine_mesh, 14 x 30 x 10 voxels of 6,25
## cm; metres, the model standing on y = 0, centred, its front facing +z): its little screen,
## the BON key by it and the slot of the bon, the hole; what the camera comes in close on
## (the screen, the key and the hole: all you use) and the parts you can click (the hole and
## the key). And the way of a can or bottle into the hole and back. Constants and plain
## functions, without nodes.
##   const DepositMachineScreenLayout = preload("res://scripts/ui/machines/deposit_machine_screen_layout.gd")

const SCREEN := Rect2(-0.125, 1.375, 0.25, 0.1875)
const FRONT := 0.3125
const SCREEN_SUNK := 0.125
const KEYS := Vector3(0.28, 1.47, 0.3125)
const SLOT := Vector3(0.28, 1.22, 0.3125)
const HOLE := Vector3(0.0, 0.97, 0.3125)
const FOCUS := Rect2(-0.25, 0.72, 0.62, 0.92)
const FOCUS_SHARE := 0.95
## The parts you can click: the hole and the BON key.
const HOLE_RECT := Rect2(-0.1875, 0.75, 0.375, 0.4375)
const BON_KEY_RECT := Rect2(0.2, 1.39, 0.16, 0.16)
## The can or bottle going in: from how far before the hole and how much under its middle
## (m), how far before the mouth it lines up, and how far into the hole it goes.
const INSERT_FROM := 0.32
const INSERT_UNDER := 0.04
const INSERT_AT_MOUTH := 0.02
const INSERT_DEEP := 0.26


## Where the parts of the machine are, without its model (the view's machine_parts adds
## it); its parts to click are called `hole_name` and `bon_key_name`.
static func parts(hole_name: String, bon_key_name: String) -> Dictionary:
	return {"screen": SCREEN, "front": FRONT, "screen_sunk": SCREEN_SUNK, "keys": KEYS, "slot": SLOT, "hole": HOLE,
		"focus": FOCUS, "focus_share": FOCUS_SHARE,
		"hotspots": [{"name": hole_name, "rect": HOLE_RECT}, {"name": bon_key_name, "rect": BON_KEY_RECT}]}


## Where a can or bottle is before it goes in (and when it came back out), `mouth` being
## the hole.
static func insert_before(mouth: Vector3) -> Vector3:
	return mouth + Vector3(0.0, -INSERT_UNDER, INSERT_FROM)


## Where it is at the mouth of the hole.
static func insert_at_mouth(mouth: Vector3) -> Vector3:
	return mouth + Vector3(0.0, 0.0, INSERT_AT_MOUTH)


## How far in (z) it is when the belt has it.
static func insert_deep_z(mouth: Vector3) -> float:
	return mouth.z - INSERT_DEEP
