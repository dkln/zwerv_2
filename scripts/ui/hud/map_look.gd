extends RefCounted
## How the maps of the HUD look wherever they are shown (the minimap, its marks, the chip
## of the marker, the big map of the game menu): the colour per kind of ground, of a
## building and of an empty cell, and the colours of the marks (graphics, only data;
## docs/CODE_LAGEN.md). Which kind a tile is: minimap_rules.gd.
##   const MapLook = preload("res://scripts/ui/hud/map_look.gd")

## Colour per kind of ground (MinimapRules.KINDS, by the folder of the Grond tile) and of
## a building.
const GROUND_COLOURS := {
	"road": Color("#6B6A8E"),
	"cycle_path": Color("#7E5A72"),
	"water": Color("#24306A"),
	"grass": Color("#3E6150"),
	"pavement": Color("#4A5378"),
	"rail": Color("#555170"),
	"land": Color("#3A4A6E"),
	"building": Color("#141729"),
}
## An empty cell of the map, and what the story has not opened yet (the shroud).
const EMPTY := Color("#0B0D1A")
## The ways out on the floor plan of an interior.
const EXIT_MARK_COLOUR := Color("#5BE37A")
## The marker you set on the map (the game menu's KAART: Enter on a place): on the minimap,
## its chip and the big map.
const WAYPOINT_COLOUR := Color("#FF5ACD")
