extends RefCounted
## The sizes of what drifts through space behind the story of the intro (the layout layer
## of scripts/ui/intro/drifter.gd, which is the behaviour; drifter_rules.gd has the logic,
## drifter_view.gd builds and shows it with these sizes): the small picture it is drawn
## in, how big that shows, where the camera stands, and where the parts of a tractor and
## a character are so they tumble round their middle. Constants and plain functions,
## without nodes.
##   const DrifterLayout = preload("res://scripts/ui/intro/drifter_layout.gd")

## The picture it is drawn in (pixels each way) and how big that shows on the screen at most.
const PICTURE := 96
const SIZE := 190.0
## The camera: where it stands (room for the flag as a tractor tumbles) and its lens (degrees).
const CAMERA_AT := Vector3(0.0, 0.0, 8.5)
const CAMERA_FOV := 40.0
## The sun on it (degrees).
const SUN_TURN := Vector3(-35.0, 40.0, 0.0)
## A character shows this many times its size (as big as a tractor).
const CHARACTER_SCALE := 2.2
## A tractor: how high its body stands (the model_lift of scripts/vehicles/tractor.gd), the
## height of its middle, and its wheels: [hub, wheel model, radius], the small front
## wheels and the big rear ones.
const TRACTOR_BODY_AT := Vector3(0.0, 0.25, 0.0)
const TRACTOR_MIDDLE := 1.4
const TRACTOR_WHEELS := [
	[Vector3(-0.5625, 0.375, 1.25), "auto_wiel", 0.375], [Vector3(0.5625, 0.375, 1.25), "auto_wiel", 0.375],
	[Vector3(-0.75, 0.625, -0.875), "tractor_wiel", 0.625], [Vector3(0.75, 0.625, -0.875), "tractor_wiel", 0.625]]


## Where the mesh of a wheel stands (the wheel meshes stand on their lowest point, round
## the axle): `wheel` as an entry of TRACTOR_WHEELS.
static func wheel_position(wheel: Array) -> Vector3:
	return (wheel[0] as Vector3) - Vector3(0.0, float(wheel[2]), 0.0)


## Where a tractor stands in its holder: its middle at the origin, so it tumbles round itself.
static func tractor_position() -> Vector3:
	return Vector3(0.0, -TRACTOR_MIDDLE, 0.0)


## Where a character `height` metres high (before scaling) stands in its holder: its
## middle at the origin, so it tumbles round itself.
static func character_position(height: float) -> Vector3:
	return Vector3(0.0, -height * 0.5 * CHARACTER_SCALE, 0.0)
