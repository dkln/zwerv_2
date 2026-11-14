@tool
extends RefCounted
## The logic of the lane arrows in the editor (the rules layer of scripts/traffic/lane_arrows.gd,
## the behaviour; lane_arrows_layout.gd places the arrows, lane_arrows_view.gd draws them):
## which kind of arrow a lane gets, by where its direction comes from.
##   const LaneArrowsRules = preload("res://scripts/traffic/lane_arrows_rules.gd")

## The direction the tile itself gives (a lane tile, turned as placed).
const FIXED := "fixed"
## A tile without a direction of its own, its direction decided from the road around it.
const CONTEXT := "context"
## Still both ways (nothing around it decides it): an arrow each way.
const OPEN := "open"
## Lanes, road users or speed limit chosen for this one placed tile (Build dock).
const CHOSEN := "chosen"
## Seconds between checks whether the ground tiles changed.
const CHECK_INTERVAL := 1.0


## The kind of arrow of a lane: CHOSEN when anything was chosen for its placed tile, else
## OPEN when the cell also has the lane the other way, else CONTEXT when its direction came
## from the road around it (`from_context`), else FIXED.
static func arrow_kind(from_context: bool, chosen: bool, both_ways: bool) -> String:
	if chosen:
		return CHOSEN
	if both_ways:
		return OPEN
	return CONTEXT if from_context else FIXED


## True when it is time to look again whether the ground changed.
static func check_due(since_check: float) -> bool:
	return since_check >= CHECK_INTERVAL
