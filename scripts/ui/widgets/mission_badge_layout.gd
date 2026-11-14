extends RefCounted
## The shape of the emblem of a new mission (layout; docs/CODE_LAGEN.md): which pixels make
## the diamond and the exclamation mark in it, which of them lie on the lit and the dark
## edge, how it bobs, and where and how big its sparkles are. Drawn by mission_badge.gd.
##   const MissionBadgeLayout = preload("res://scripts/ui/widgets/mission_badge_layout.gd")

## The emblem is DIAMOND_PIXELS wide and high (an odd number), each pixel EMBLEM_PIXEL px.
const DIAMOND_PIXELS := 17
const EMBLEM_PIXEL := 7.0
const SHADOW_PIXELS := 1
## How far (px) and how fast (per second) it bobs.
const BOB_PIXELS := 4.0
const BOB_SPEED := 2.2
## Sparkles: places round the emblem (share of the size, from the middle), how often they
## blink and how big a pixel of one is (px).
const SPARKLES := [Vector2(-0.36, -0.30), Vector2(0.34, -0.22), Vector2(-0.30, 0.32), Vector2(0.38, 0.30)]
const SPARKLE_SECONDS := 1.6
const SPARKLE_PIXEL := 3.0
## The edge of the diamond a pixel lies on (edge_of).
const EDGE_NONE := 0
const EDGE_LIT := 1
const EDGE_DARK := -1


## Whether pixel (column, row) of the emblem lies in the diamond.
static func in_diamond(column: int, row: int) -> bool:
	var half := DIAMOND_PIXELS / 2
	return absi(column - half) + absi(row - half) <= half


## The exclamation mark: a bar three pixels wide and a dot under it.
static func in_mark(column: int, row: int) -> bool:
	var half := DIAMOND_PIXELS / 2
	if absi(column - half) > 1:
		return false
	return (row >= 3 and row <= 9) or (row >= 11 and row <= 12)


## The edge pixel (column, row) of the diamond lies on: EDGE_LIT along the upper left,
## EDGE_DARK along the lower right, EDGE_NONE inside (a bevelled look).
static func edge_of(column: int, row: int) -> int:
	var half := DIAMOND_PIXELS / 2
	var from_edge := half - (absi(column - half) + absi(row - half))
	if from_edge != 0:
		return EDGE_NONE
	return EDGE_LIT if column + row <= DIAMOND_PIXELS - 1 else EDGE_DARK


## How many whole pixels the emblem stands lower (or higher) `clock` seconds in.
static func bob(clock: float) -> float:
	return roundf(sin(clock * BOB_SPEED) * BOB_PIXELS)


## The top left corner of the emblem round `middle`, `bob_pixels` lower.
static func emblem_origin(middle: Vector2, bob_pixels: float) -> Vector2:
	return (middle - Vector2.ONE * DIAMOND_PIXELS * EMBLEM_PIXEL * 0.5 + Vector2(0, bob_pixels)).round()


## The square of pixel (column, row) of an emblem whose top left corner is `origin`.
static func pixel_rect(origin: Vector2, column: int, row: int) -> Rect2:
	return Rect2(origin + Vector2(column, row) * EMBLEM_PIXEL, Vector2.ONE * EMBLEM_PIXEL)


## How far the hard shadow of the emblem lies down and to the right.
static func shadow_offset() -> Vector2:
	return Vector2.ONE * SHADOW_PIXELS * EMBLEM_PIXEL


## How long the arms of sparkle `index` are `clock` seconds in (pixels of the sparkle): 0
## while it is off, 1 as it comes and goes, 2 in between. Each sparkle is on for the first
## 45 % of its own turn of SPARKLE_SECONDS, the turns one after the other.
static func sparkle_arms(clock: float, index: int) -> int:
	var turn := fposmod(clock / SPARKLE_SECONDS - float(index) / SPARKLES.size(), 1.0)
	if turn > 0.45:
		return 0
	return 1 if turn < 0.15 or turn > 0.3 else 2


## The middle of sparkle `index` in a picture of `size` px whose middle is `middle`.
static func sparkle_place(index: int, middle: Vector2, size: Vector2) -> Vector2:
	return (middle + (SPARKLES[index] as Vector2) * size).round()


## The squares of a sparkle at `at` whose arms are `arms` pixels long: its middle first, then
## each arm outwards (up, down, left, right).
static func sparkle_rects(at: Vector2, arms: int) -> Array[Rect2]:
	var corner := at - Vector2.ONE * SPARKLE_PIXEL * 0.5
	var rects: Array[Rect2] = [Rect2(corner, Vector2.ONE * SPARKLE_PIXEL)]
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for step in arms:
			rects.append(Rect2(corner + direction * SPARKLE_PIXEL * (step + 1.0), Vector2.ONE * SPARKLE_PIXEL))
	return rects
