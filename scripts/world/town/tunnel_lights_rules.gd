extends RefCounted
## What the lights in the tunnels decide (logic; docs/CODE_LAGEN.md): which ground tiles are
## a covered tunnel, and when the lamps are on. Where they hang: tunnel_lights_layout.gd;
## the node: tunnel_lights.gd.
##   const TunnelLightsRules = preload("res://scripts/world/town/tunnel_lights_rules.gd")


## True for the item name of a covered tunnel tile (not an open trough or a ramp).
static func is_covered_tile(item_name: String) -> bool:
	return item_name.begins_with("tunnel/") and not "toerit" in item_name and not "tunnelbak" in item_name


## True while the lamps are on: with the camera lower than `off_above` metres (above it you
## only see the roof).
static func is_lit(camera_height: float, off_above: float) -> bool:
	return camera_height < off_above
