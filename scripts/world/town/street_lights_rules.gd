extends RefCounted
## What the street lights decide (logic; docs/CODE_LAGEN.md): how strongly they burn for the
## dark of the day cycle (off by day, fading in at dusk, full at night) and which lamps get
## a real light: only the MAX_LIGHTS nearest the middle of the view within REACH metres,
## chosen again every PICK_INTERVAL seconds. The node: street_lights.gd.
##   const StreetLightsRules = preload("res://scripts/world/town/street_lights_rules.gd")

## The dark (DayCycle.night) at which the lights start to come on, and at which they are full.
const NIGHT_FROM := 0.3
const NIGHT_FULL := 0.8
const MAX_LIGHTS := 64
const REACH := 70.0
const PICK_INTERVAL := 0.4
## Item names of the lamps in the Props layer start with this.
const LAMP_PREFIX := "verlichting/"


## True for the item name of a lamp.
static func is_lamp(item_name: String) -> bool:
	return item_name.begins_with(LAMP_PREFIX)


## How strongly the lights burn (0..1) when it is `night` dark (0 = day, 1 = night).
static func strength(night: float) -> float:
	return clampf((night - NIGHT_FROM) / (NIGHT_FULL - NIGHT_FROM), 0.0, 1.0)


## How many lights there are for `head_count` lamp heads: one each, MAX_LIGHTS at most.
static func light_count(head_count: int) -> int:
	return mini(MAX_LIGHTS, head_count)


## The heads within REACH of `focus` (over the ground), nearest first. `heads`: one Array
## per head with its world position (Vector3) first; the same Arrays come back.
static func nearest(heads: Array, focus: Vector3) -> Array:
	var near: Array = []
	for head: Array in heads:
		var at: Vector3 = head[0]
		var distance := Vector2(at.x - focus.x, at.z - focus.z).length()
		if distance <= REACH:
			near.append([distance, head])
	near.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	var found: Array = []
	for entry: Array in near:
		found.append(entry[1])
	return found
