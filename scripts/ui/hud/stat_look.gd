extends RefCounted
## How the stats of the player look wherever they are shown (the player frame of the HUD,
## the game menu, the character choice, the level-up screen): their order, colours, bars and
## icons, and the look of the experience bar.
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
## Icons of 7 x 7 pixels ("#" = coloured), drawn at 2 x 2 screen pixels per pixel.
const PIXEL_ICONS := {
	"heart": [".##.##.", "#######", "#######", ".#####.", "..###..", "...#...", "......."],
	"bolt": ["....##.", "...##..", "..##...", ".######", "...##..", "..##...", ".##...."],
	"chomp": ["..###..", ".#####.", "####...", "###....", "####...", ".#####.", "..###.."],
	"burst": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	"person": ["..###..", ".#####.", ".#####.", "..###..", ".......", ".#####.", "#######"],
}


## A stat's value within 0..its maximum: Vector2(value, maximum). `maximum` <= 0 keeps
## `previous_maximum`.
static func clamped(value: float, maximum: float, previous_maximum: float) -> Vector2:
	var top := maximum if maximum > 0.0 else previous_maximum
	return Vector2(clampf(value, 0.0, top), top)


## A stat as its bar writes it: "35/80".
static func value_text(stat: Vector2) -> String:
	return "%d/%d" % [roundi(stat.x), roundi(stat.y)]


## The share (0..1) of a stat's bar that is full.
static func fill(stat: Vector2) -> float:
	return stat.x / stat.y if stat.y > 0.0 else 0.0


## The experience within this level: Vector2(points, points the level takes), the points
## within 0..that, the level at least 1 point long.
static func experience(points: float, points_for_level: float) -> Vector2:
	var top := maxf(points_for_level, 1.0)
	return Vector2(clampf(points, 0.0, top), top)
