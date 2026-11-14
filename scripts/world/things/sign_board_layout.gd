extends RefCounted
## The sizes of a board with a text on it (layout; docs/CODE_LAGEN.md; sign_board.gd): how
## big a letter is, how wide and high the plate is for its text and where the text stands on
## its front and its back.
##   const SignBoardLayout = preload("res://scripts/world/things/sign_board_layout.gd")

## Metres per letter of the text at font size 1 (the pixel font is square), and the room
## round the text on the plate.
const LETTER := 0.19
const MARGIN := 0.18
const THICKNESS := 0.05
## The size (pixels) the text is drawn at before it is scaled to its letters.
const FONT_PIXELS := 64
## How far before the plate the text stands, so it never flickers with it.
const TEXT_PROUD := 0.005
## The sides of a board: its front (+z) and its back.
const FRONT := 1.0
const BACK := -1.0


## Metres per letter: `letter`, or the default when it is 0.
static func letter_size(letter: float) -> float:
	return letter if letter > 0.0 else LETTER


## The size of the plate for a text of `letters` letters of `size` metres each;
## `fixed_width` metres wide when that is more than 0.
static func plate_size(letters: int, size: float, fixed_width := 0.0) -> Vector3:
	var width := fixed_width if fixed_width > 0.0 else letters * size + MARGIN * 2.0
	return Vector3(width, size * 1.2 + MARGIN, THICKNESS)


## The sides a board has text on: the front, and the back when `both_sides`.
static func sides(both_sides: bool) -> Array:
	return [FRONT, BACK] if both_sides else [FRONT]


## How big a pixel of the text is (metres) for letters of `size` metres.
static func pixel_size(size: float) -> float:
	return size / FONT_PIXELS


## Where the text stands on `side` (FRONT or BACK): just before the plate.
static func text_place(side: float) -> Vector3:
	return Vector3(0.0, 0.0, side * (THICKNESS * 0.5 + TEXT_PROUD))


## How far the text is turned (radians round y) on `side`: the back faces the other way.
static func text_turn(side: float) -> float:
	return 0.0 if side > 0.0 else PI
