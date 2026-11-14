extends RefCounted
## Where the things of the intro stand and how big they are (the layout layer of
## scripts/ui/intro.gd, which is the behaviour; intro_rules.gd has the logic,
## intro_view.gd builds and shows it with these sizes): the stars, the logo and its
## subtitle, the picture of the story, the twinkle where the logo vanishes and the texts
## in the corners. The design is ScreenLayout.DESIGN_SIZE (scripts/ui/menu/screen_layout.gd).
## Constants and plain functions, without nodes.
##   const IntroLayout = preload("res://scripts/ui/intro/intro_layout.gd")

const ScreenLayout = preload("res://scripts/ui/menu/screen_layout.gd")

const DESIGN_SIZE := ScreenLayout.DESIGN_SIZE
## The stars: how many, the seed of where they stand, how big the big and the small ones
## are (the big ones: BIG_STARS_FROM of the draws), how fast they twinkle (from .. to,
## radians a second) and how deep the big and the small ones dim.
const STAR_COUNT := 140
const STAR_SEED := 11
const BIG_STARS_FROM := 0.88
const BIG_STAR := 3.0
const SMALL_STAR := 2.0
const TWINKLE_PACE := Vector2(1.2, 4.5)
const BIG_STAR_DIMS := 0.35
const SMALL_STAR_DIMS := 0.6
## The subtitle under the logo: how high its line is and how far under the middle.
const SUBTITLE_HEIGHT := 40.0
const SUBTITLE_UNDER_MIDDLE := 130.0
## The crawl picture: the size the text is drawn in (pixels), the
## width of its far top edge on the screen (share of the bottom edge) and how much of the
## screen it takes from the bottom up.
const CRAWL_PICTURE := Vector2i(900, 1400)
const CRAWL_FAR_WIDTH := 0.22
const CRAWL_SCREEN_TOP := 0.08
## Where the last paragraph comes to rest far off (share of the picture's height from the top).
const CRAWL_REST := 0.35
## Pixels between the paragraphs of the story (in its picture) and between its lines.
const PARAGRAPH_GAP := 26
const LINE_SPACING := 4
## The twinkle: a four-pointed flash of pixels (SPARKLE_ARM long, its rays RAY_THIN and
## RAY_THICK wide, a core of CORE pixels) that turns an eighth round, sparks (SPARKLE_SPARKS
## of SPARK pixels) flying off it out to SPARKLE_REACH pixels.
const SPARKLE_ARM := 34.0
const RAY_THIN := 4.0
const RAY_THICK := 8.0
const CORE := 10.0
const SPARKLE_SPARKS := 8
const SPARK := 3.0
const SPARKLE_REACH := 90.0
## The smallest the twinkle gets (at no flare), and how far it turns over its time.
const SPARKLE_SMALLEST := 0.2
const SPARKLE_TURN := PI * 0.25
## The texts in the corners: this far in from the side and up from the bottom; the size of
## the line bottom right.
const PROMPT_MARGIN := 48
const FOOTER_SIZE := Vector2(600, 16)


## The stars (`random` decides, seeded with STAR_SEED: the same every time), per star
## {"position", "size", "big", "pace" (rad/s), "phase", "depth" (how deep it dims)}.
static func stars(random: RandomNumberGenerator) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for _star_index in STAR_COUNT:
		var big := random.randf() > BIG_STARS_FROM
		var position := Vector2(random.randi_range(0, int(DESIGN_SIZE.x) - 1), random.randi_range(0, int(DESIGN_SIZE.y) - 1))
		# each its own pace and moment of twinkling
		var pace := random.randf_range(TWINKLE_PACE.x, TWINKLE_PACE.y)
		made.append({"position": position, "size": Vector2.ONE * (BIG_STAR if big else SMALL_STAR), "big": big,
			"pace": pace, "phase": random.randf() * TAU, "depth": BIG_STAR_DIMS if big else SMALL_STAR_DIMS})
	return made


## The sizes of the bars of the twinkle: two long thin rays crossing, two short thick ones.
static func sparkle_rays() -> Array[Vector2]:
	return [Vector2(RAY_THIN, SPARKLE_ARM * 2.0), Vector2(SPARKLE_ARM * 2.0, RAY_THIN),
		Vector2(RAY_THICK, SPARKLE_ARM), Vector2(SPARKLE_ARM, RAY_THICK)]


## How big the twinkle is at `flare` (0 .. 1: how bright).
static func sparkle_scale(flare: float) -> float:
	return SPARKLE_SMALLEST + (1.0 - SPARKLE_SMALLEST) * sqrt(flare)


## How far the twinkle has turned (radians) at `twinkling` (0 .. 1 of its time).
static func sparkle_rotation(twinkling: float) -> float:
	return twinkling * SPARKLE_TURN


## Where spark `spark_index` of `count` (`spark_size` big) is at `twinkling` (0 .. 1 of the
## twinkle's time): flying out from the middle of the screen, each its own way, slowing
## down towards SPARKLE_REACH.
static func spark_position(spark_index: int, count: int, twinkling: float, spark_size: Vector2) -> Vector2:
	var direction := Vector2.RIGHT.rotated(TAU * (spark_index + 0.5) / count)
	return DESIGN_SIZE * 0.5 + direction * SPARKLE_REACH * (1.0 - pow(1.0 - twinkling, 2.0)) - spark_size * 0.5


## Where the subtitle under the logo stands.
static func subtitle_position() -> Vector2:
	return Vector2(0, DESIGN_SIZE.y * 0.5 + SUBTITLE_UNDER_MIDDLE)


## Where the line bottom right stands (its right edge PROMPT_MARGIN in from the side).
static func footer_position() -> Vector2:
	return Vector2(DESIGN_SIZE.x - PROMPT_MARGIN - FOOTER_SIZE.x, DESIGN_SIZE.y - PROMPT_MARGIN)
