extends RefCounted
## The sizes and places of the logo of a bank (layout; docs/CODE_LAGEN.md): the pixel emblem
## and the name beside it, the two together in the middle of the width they get. Drawn by
## bank_logo.gd.
##   const BankLogoLayout = preload("res://scripts/ui/widgets/bank_logo_layout.gd")

## Screen pixels per pixel of the emblem, the size of the name, the space between the two and
## the room over and under the logo together.
const PIXEL := 6.0
const NAME_SIZE := 30
const GAP := 14.0
const ROOM := 4.0


## How big an emblem of these `rows` (strings of equal length) is drawn.
static func emblem_size(rows: Array) -> Vector2:
	var columns := (rows[0] as String).length() if not rows.is_empty() else 0
	return Vector2(columns, rows.size()) * PIXEL


## The least height of a logo whose emblem has `row_count` rows: the higher of the emblem and
## the name, with ROOM.
static func minimum_height(row_count: int) -> float:
	return maxf(row_count * PIXEL, float(NAME_SIZE)) + ROOM


## The top left corner of the emblem in a logo of `size`: the emblem (`emblem`), the gap and
## the name (`name_width` px) together in the middle, the emblem in the middle of the height.
static func emblem_origin(size: Vector2, emblem: Vector2, name_width: float) -> Vector2:
	return Vector2(roundf((size.x - emblem.x - GAP - name_width) * 0.5), roundf((size.y - emblem.y) * 0.5))


## The square of pixel (column, row) of an emblem whose top left corner is `origin`.
static func pixel_rect(origin: Vector2, column: int, row: int) -> Rect2:
	return Rect2(origin.x + column * PIXEL, origin.y + row * PIXEL, PIXEL, PIXEL)


## Where the name starts (its baseline): right of the emblem, in the middle of the height
## for a font whose ascent is `ascent` px.
static func name_position(origin: Vector2, emblem: Vector2, height: float, ascent: float) -> Vector2:
	return Vector2(origin.x + emblem.x + GAP, roundf(height * 0.5 + ascent * 0.5 - 2.0))
