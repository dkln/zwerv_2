extends RefCounted
## The sizes of the action prompts (the layout layer of scripts/ui/action_prompts.gd, which
## is the behaviour; action_prompts_rules.gd has the logic, action_prompts_view.gd builds
## the panels with these sizes): the room between and inside the panels and the key caps,
## and how wide the key caps are. Constants and plain functions, without nodes.
##   const ActionPromptsLayout = preload("res://scripts/ui/screens/action_prompts_layout.gd")

## Pixels between the panels, and between a key cap and its text.
const PANEL_GAP := 8
const KEY_GAP := 10
## The border of a panel and the room inside it.
const PANEL_BORDER := 2
const PANEL_MARGIN_LEFT := 10
const PANEL_MARGIN_RIGHT := 14
const PANEL_MARGIN_TOP := 10
const PANEL_MARGIN_BOTTOM := 10
## The room inside a key cap, and where its hard shadow falls.
const KEY_MARGIN_SIDE := 8
const KEY_MARGIN_TOP := 4
const KEY_MARGIN_BOTTOM := 4
const KEY_SHADOW := Vector2(0, 3)
## A key cap keeps its width when it is this close (pixels) to the one wanted.
const WIDTH_SLACK := 0.5


## How wide a key cap is: its name `label_width` wide plus the edges of the cap.
static func key_cap_width(label_width: float, edges_width: float) -> float:
	return label_width + edges_width


## The width all key caps get: that of the widest of `widths` (0 without key caps).
static func widest(widths: Array) -> float:
	var most := 0.0
	for width: float in widths:
		most = maxf(most, width)
	return most


## Whether a key cap `width_now` wide must be made `wanted` wide (only when it differs: it
## settles at once).
static func needs_width(width_now: float, wanted: float) -> bool:
	return absf(width_now - wanted) > WIDTH_SLACK
