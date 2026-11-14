extends RefCounted
## The size the screens before the game are laid out at (the intro, the main menu and the
## character creation: scripts/ui/intro.gd, main_menu.gd, character_creation.gd) and how
## that design fits the window: scaled as a whole, in the middle (layout;
## docs/CODE_LAGEN.md). Constants and plain functions, without nodes.
##   const ScreenLayout = preload("res://scripts/ui/menu/screen_layout.gd")

## The size of the design (pixels).
const DESIGN_SIZE := Vector2(1280, 720)


## How many times the design is enlarged to fit `window` whole.
static func scale_in(window: Vector2) -> float:
	return minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)


## The top left corner of the design in `window`, so it stands in the middle.
static func position_in(window: Vector2) -> Vector2:
	return (window - DESIGN_SIZE * scale_in(window)) * 0.5
