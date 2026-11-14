extends RefCounted
## Where things stand in the 3D scene of a machine's close-up (the layout of
## scripts/ui/machines/machine_stage_view.gd, which builds the scene; part of the screen of
## scripts/ui/machines/machine_screen.gd). Metres; the machine's front is at the scene's
## origin facing +z, its model stands on y = 0, centred. Here: where a machine has its parts
## when it does not say (the plain box), where you stand and the camera, the close-up on the
## part you use, where the screen's picture, its glow, the light of the keys and what slides
## out of the slot are. Constants and plain functions, without nodes.
##   const MachineStageLayout = preload("res://scripts/ui/machines/machine_stage_layout.gd")

## The plain machine (no model): a box, and where such a machine has its parts.
const BOX_SIZE := Vector3(0.75, 1.75, 0.5)
const DEFAULT_SCREEN := Rect2(-0.25, 1.0, 0.5, 0.32)
const DEFAULT_FRONT := 0.25
const DEFAULT_KEYS := Vector3(-0.15, 0.75, 0.25)
const DEFAULT_SLOT := Vector3(0.0, 0.45, 0.25)
## Where you stand before the machine and how you are turned (to it, -z, a little towards
## its middle).
const STAND_AT := Vector3(-0.42, 0.0, 0.62)
const STAND_TURN := PI + 0.35
## The camera: from a little back to close in over your right shoulder as it opens.
const CAMERA_FROM := Vector3(0.95, 1.7, 2.6)
const CAMERA_AT := Vector3(0.42, 1.45, 1.25)
const LOOK_AT := Vector3(-0.05, 1.05, 0.0)
const CAMERA_FOV := 42.0
## The close-up on the part you use (machine_parts "focus"): its share of the height of the
## view (unless the machine gives "focus_share"), the most of the width it may take, and
## where its middle is across the window (px: right of the panels on the left), in a view of
## VIEW_SIZE (the design of the screen).
const FOCUS_SHARE := 0.6
const FOCUS_WIDTH_SHARE := 0.62
const FOCUS_CENTRE_X := 790.0
const VIEW_SIZE := Vector2(1280, 720)
## The picture of the screen lies this far before its glass; its glow and the light of the
## keys this far before them.
const DISPLAY_LIFT := 0.004
const GLOW_LIFT := 0.25
const PRESS_LIGHT_LIFT := 0.08
## What slides out of the slot (the bon, the notes, the card): its size, how far inside the
## slot it starts and how far out it comes.
const SLIP_SIZE := Vector3(0.16, 0.012, 0.1)
const SLIP_INSIDE := 0.04
const SLIDE_OUT := 0.12
## How the two lights of the scene are turned (degrees).
const KEY_LIGHT_TURN := Vector3(-38.0, 28.0, 0.0)
const FILL_LIGHT_TURN := Vector3(-10.0, -50.0, 0.0)


## The parts of the plain machine, without its model: {"screen", "front", "keys", "slot"}.
static func default_parts() -> Dictionary:
	return {"screen": DEFAULT_SCREEN, "front": DEFAULT_FRONT, "keys": DEFAULT_KEYS, "slot": DEFAULT_SLOT}


## The screen of a machine with `parts` on its front (x and y of its lower left corner, its size).
static func screen_of(parts: Dictionary) -> Rect2:
	return parts.get("screen", DEFAULT_SCREEN)


## How far the front of a machine with `parts` is before the middle of its model.
static func front_of(parts: Dictionary) -> float:
	return float(parts.get("front", DEFAULT_FRONT))


## Where the model of a machine stands: its back to the wall, its front at z = 0.
static func holder_at(parts: Dictionary) -> Vector3:
	return Vector3(0.0, 0.0, -front_of(parts))


## The middle of the picture on the screen, in the model's space: on its glass, sunk into
## the machine as far as its screen is ("screen_sunk").
static func display_at(parts: Dictionary) -> Vector3:
	var screen := screen_of(parts)
	var sunk := float(parts.get("screen_sunk", 0.0))
	return Vector3(screen.position.x + screen.size.x * 0.5, screen.position.y + screen.size.y * 0.5, front_of(parts) - sunk + DISPLAY_LIFT)


## Where the glow of the screen is, in the model's space.
static func glow_at(parts: Dictionary) -> Vector3:
	return display_at(parts) + Vector3(0.0, 0.0, GLOW_LIFT)


## Where the light of a key pressed is, in the model's space: just before its keypad.
static func press_light_at(parts: Dictionary) -> Vector3:
	var keys: Vector3 = parts.get("keys", Vector3(DEFAULT_KEYS.x, DEFAULT_KEYS.y, front_of(parts)))
	return keys + Vector3(0.0, 0.0, PRESS_LIGHT_LIFT)


## Where what comes out of the slot starts (inside it), in the model's space.
static func slip_from(parts: Dictionary) -> Vector3:
	var slot: Vector3 = parts.get("slot", DEFAULT_SLOT)
	return slot + Vector3(0.0, 0.0, -SLIP_INSIDE)


## How far forward (z, the model's space) it has come when it is out.
static func slip_out_z(parts: Dictionary) -> float:
	var slot: Vector3 = parts.get("slot", DEFAULT_SLOT)
	return slot.z + SLIDE_OUT


## The part of a machine the camera comes in close on: its "focus", else its screen.
static func focus_of(parts: Dictionary) -> Rect2:
	return parts.get("focus", screen_of(parts))


## The close-up of a machine with `parts`: [position of the camera, point looked at].
static func close_up(parts: Dictionary) -> Array:
	return close_up_of(focus_of(parts), float(parts.get("focus_share", FOCUS_SHARE)))


## The close-up on `focus` (a rectangle on the machine's front, metres) that takes `share` of
## the height of the view (or FOCUS_WIDTH_SHARE of its width when it is wide), straight before
## it, its middle at FOCUS_CENTRE_X across the window: [position of the camera, point looked at].
static func close_up_of(focus: Rect2, share: float) -> Array:
	var tangent := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var aspect := VIEW_SIZE.x / VIEW_SIZE.y
	var distance := maxf(focus.size.y / (share * 2.0 * tangent), focus.size.x / (FOCUS_WIDTH_SHARE * 2.0 * tangent * aspect))
	var metres_per_pixel := 2.0 * distance * tangent / VIEW_SIZE.y
	var aside := (FOCUS_CENTRE_X - VIEW_SIZE.x * 0.5) * metres_per_pixel
	var middle := Vector3(focus.get_center().x, focus.get_center().y, 0.0)
	var look := middle - Vector3(aside, 0.0, 0.0)
	return [look + Vector3(0.0, 0.0, distance), look]


## The four corners of `rect` (on the front of a machine with `parts`), in the model's space.
static func corners_of(rect: Rect2, parts: Dictionary) -> Array[Vector3]:
	var front := front_of(parts)
	var corners: Array[Vector3] = []
	for corner: Vector2 in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		corners.append(Vector3(corner.x, corner.y, front))
	return corners
