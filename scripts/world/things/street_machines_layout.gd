extends RefCounted
## Where the machines in the streets and their [E] spots stand (layout; docs/CODE_LAGEN.md;
## street_machines.gd): the spot before the front of a machine, the ray that settles a
## machine on the ground, and where the beep and the text of an OV post come from.
##   const StreetMachinesLayout = preload("res://scripts/world/things/street_machines_layout.gd")

## How far before the front of a machine (its +z) its [E] spot lies, how much further for a
## cash machine (it stands out of its wall), and from how far the spot is used (metres).
const SPOT_AHEAD := 0.75
const CASH_EXTRA := 0.25
const SPOT_REACH := 1.1
## How far above and below its marker the ground is looked for (metres).
const GROUND_ABOVE := 3.0
const GROUND_BELOW := 3.0
## How high on an OV post its beep sounds and its text floats (metres), and the size of
## that text.
const BEEP_HEIGHT := 1.1
const TEXT_HEIGHT := 1.6
const TEXT_SIZE := 14


## Where the [E] spot of a cash machine lies, from the machine.
static func cash_spot() -> Vector3:
	return Vector3(0.0, 0.0, SPOT_AHEAD + CASH_EXTRA)


## Where the [E] spot of an OV post lies, from the post.
static func post_spot() -> Vector3:
	return Vector3(0.0, 0.0, SPOT_AHEAD)


## The ray that looks for the ground under a marker at `at`: [from, to].
static func ground_ray(at: Vector3) -> Array[Vector3]:
	return [at + Vector3.UP * GROUND_ABOVE, at + Vector3.DOWN * GROUND_BELOW]


## Where the beep of a post sounds, from the post.
static func beep_place() -> Vector3:
	return Vector3.UP * BEEP_HEIGHT


## Where the text of a post at `at` floats.
static func text_place(at: Vector3) -> Vector3:
	return at + Vector3.UP * TEXT_HEIGHT
