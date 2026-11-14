extends RefCounted
## How the stats of the player look wherever they are shown (the player frame of the HUD,
## the game menu, the character choice, the level-up screen): their order, colours, bars and
## icons, and the look of the experience bar (graphics, only data; docs/CODE_LAGEN.md).
## Their arithmetic: stat_rules.gd.
##   const StatLook = preload("res://scripts/ui/hud/stat_look.gd")

## The stats in the order they are shown: colour of a full and of an empty segment, number
## of segments, segment height and the icon (PIXEL_ICONS).
const STATS := {
	"gezondheid": {"colour": Color("#FF5D73"), "empty": Color("#3A2340"), "segments": 20, "height": 12, "icon": "heart"},
	"uithoudingsvermogen": {"colour": Color("#8BE36B"), "empty": Color("#22352A"), "segments": 20, "height": 8, "icon": "bolt"},
	"honger": {"colour": Color("#FFB547"), "empty": Color("#3D2E14"), "segments": 20, "height": 8, "icon": "chomp"},
	"overprikkeldheid": {"colour": Color("#C08BFF"), "empty": Color("#2E2340"), "segments": 20, "height": 8, "icon": "burst"},
}
## The experience bar: a segment bar as the stats (their segments, the height of the
## slimmer ones), its colours (teal: the purple of the design is taken by overprikkeldheid).
const XP_COLOUR := Color("#47D6C2")
const XP_EMPTY_COLOUR := Color("#173733")
const XP_SEGMENTS := 20
const XP_SEGMENT_HEIGHT := 8
## The value of a stat lights up for a moment after a jump: this bright when it went up,
## this reddish when it went down, back to white in FLASH_SECONDS.
const GAINED_FLASH := Color(1.7, 1.7, 1.7)
const LOST_FLASH := Color(1.6, 0.45, 0.4)
const FLASH_SECONDS := 0.6
## Icons of 7 x 7 pixels ("#" = coloured), drawn at 2 x 2 screen pixels per pixel.
const PIXEL_ICONS := {
	"heart": [".##.##.", "#######", "#######", ".#####.", "..###..", "...#...", "......."],
	"bolt": ["....##.", "...##..", "..##...", ".######", "...##..", "..##...", ".##...."],
	"chomp": ["..###..", ".#####.", "####...", "###....", "####...", ".#####.", "..###.."],
	"burst": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	"person": ["..###..", ".#####.", ".#####.", "..###..", ".......", ".#####.", "#######"],
}

