extends RefCounted
## The sizes of the picture on a machine's screen (the layout of
## scripts/ui/machines/machine_display_view.gd, which builds it; part of the screen of
## scripts/ui/machines/machine_screen.gd): how big the picture is for a screen of a given
## shape, the margins of its glass, the room between its title, its text and the column of
## buttons, and the sizes of those buttons. Constants and plain functions, without nodes.
##   const MachineDisplayLayout = preload("res://scripts/ui/machines/machine_display_layout.gd")

## The picture: its width (px; the height follows the screen) and its least height.
const WIDTH := 720
const MIN_HEIGHT := 180
## The glass: its border and its margins, a little wider than the bulge of the glass takes
## off at the edges.
const GLASS_BORDER := 6
const GLASS_MARGIN := Vector2(34, 26)
## The room between the title and what is under it, between the text and the buttons, and
## between the buttons.
const TITLE_SEPARATION := 10
const BODY_SEPARATION := 18
const CONTROLS_SEPARATION := 8
## The column of buttons beside the text on a touch screen: its width unless the machine
## says otherwise.
const CONTROLS_WIDTH := 300.0
## A button as it is made (its height, the margins of its text, how far its shadow falls,
## its border) and the height it gets on the screen.
const BUTTON_HEIGHT := 40.0
const BUTTON_MARGIN := 10
const BUTTON_SHADOW := Vector2(3, 3)
const BUTTON_BORDER := 3
const SCREEN_BUTTON_HEIGHT := 46.0


## The size of the picture (px) for a screen `screen_size` (metres) big: WIDTH wide, as high
## as the screen is in proportion, at least MIN_HEIGHT.
static func picture_size(screen_size: Vector2) -> Vector2i:
	return Vector2i(WIDTH, maxi(roundi(WIDTH * screen_size.y / maxf(screen_size.x, 0.01)), MIN_HEIGHT))


## The least size of a button `wide` px wide as it is made.
static func button_size(wide: float) -> Vector2:
	return Vector2(wide, BUTTON_HEIGHT)


## How far the shadow of a button falls; pressed in: not at all.
static func button_shadow(pressed: bool) -> Vector2:
	return Vector2.ZERO if pressed else BUTTON_SHADOW
