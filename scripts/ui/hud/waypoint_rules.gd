extends RefCounted
## The rules of the marker set on the map (logic; docs/CODE_LAGEN.md): what its chip
## under the minimap says, and when the player is there. Used by waypoint.gd.
##   const WaypointRules = preload("res://scripts/ui/hud/waypoint_rules.gd")

## No marker.
const NONE := Vector2.INF
## How close counts as there (metres).
const ARRIVED := 8.0


## The chip of a marker just set: its name in capitals.
static func chip_text(place_name: String) -> String:
	return place_name.to_upper()


## The chip while under way: the name and how far it is ("DERREK · 70 M").
static func distance_text(place_name: String, distance: float) -> String:
	return "%s · %d M" % [place_name.to_upper(), roundi(distance)]


## Whether the player, `distance` metres from the marker, is there.
static func has_arrived(distance: float) -> bool:
	return distance <= ARRIVED


## What rises over the player on arriving.
static func arrived_text(place_name: String) -> String:
	return "Aangekomen: " + place_name
