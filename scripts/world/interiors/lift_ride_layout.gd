extends RefCounted
## Where things stand in the cabin of a lift (layout, docs/CODE_LAGEN.md): the plan of the
## cabin (the builder tools/build/build_interiors.gd lays its tiles from it), and where the
## camera of the ride stands and looks. Its behaviour: lift_ride.gd; its picture:
## lift_ride_view.gd; its logic: lift_ride_rules.gd.
##   const LiftRideLayout = preload("res://scripts/world/interiors/lift_ride_layout.gd")

## The camera: in the cabin's space, at the doors looking in at the player (from the front,
## close in), and how far the view dips as the cabin starts and stops (metres).
const CAMERA_AT := Vector3(0.0, 1.45, -1.9)
const LOOK_AT := Vector3(0.0, 1.45, 0.6)
const JOLT := 0.035


## The cabin, 3 x 2 m: the doors at the front (-z, where the camera looks in from), the
## button panel on the left wall, the floor display on the back wall over the head of whoever
## stands in it. {"tiles": [[tile, at, turn]] (library binnen, without its folder), "floor",
## "stand", "panel_mesh": [at, turn], "display": [at, turn]}.
static func cabin_plan() -> Dictionary:
	var plan := {"floor": "cabine_vloer", "tiles": [
		["cabine_achterwand", Vector3(0.0, 0.0, 1.0), PI],
		["cabine_zijwand", Vector3(-1.5, 0.0, 0.0), PI * 0.5],
		["cabine_zijwand", Vector3(1.5, 0.0, 0.0), -PI * 0.5],
		["cabine_voorwand_laag", Vector3(-1.0, 0.0, -1.0), 0.0],
		["cabine_voorwand_laag", Vector3(1.0, 0.0, -1.0), 0.0],
	]}
	plan["stand"] = Vector3(0.0, 0.0, 0.25)
	plan["panel_mesh"] = [Vector3(-1.44, 0.0, -0.35), PI * 0.5]
	plan["display"] = [Vector3(0.0, 2.32, 0.93), PI]
	return plan


## Where the camera stands at the low point of the dip as the cabin starts or stops.
static func camera_dipped() -> Vector3:
	return CAMERA_AT - Vector3.UP * JOLT
