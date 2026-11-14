extends RefCounted
## The sizes of the frame of the game menu (layout; docs/CODE_LAGEN.md): the design it is
## laid out at, the tab bar, the margins of a page and how the design is scaled to the
## window. The frame is built with these by menu_frame_view.gd, the pages by
## menu_parts_view.gd (`fill_page`); scripts/ui/game_menu.gd is the behaviour.
##   const MenuFrameLayout = preload("res://scripts/ui/game_menu/menu_frame_layout.gd")

## Size of the design; the menu is laid out at this size and scaled to the window.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const TAB_BAR_HEIGHT := 64.0
## The line under the tab bar.
const TAB_BAR_BORDER := 3
## Space left and right of a tab title, inside its amber background when chosen.
const TAB_PADDING_X := 18
## Room between the tabs, and the width of the "[Q]" and "[E]" beside them.
const TAB_SEPARATION := 4
const TAB_KEY_WIDTH := 32.0
## Room between the header text, the money and the close button.
const HEADER_GAP := 18.0
const PAGE_MARGIN_X := 28
const PAGE_MARGIN_Y := 22
const PAGE_MARGIN_BOTTOM := 14
## Room between the content of a page and its line of keys, and between its columns.
const PAGE_SEPARATION := 12
const CONTENT_SEPARATION := 24


## The smallest size of the tab bar (its line under it included).
static func tab_bar_size() -> Vector2:
	return Vector2(0.0, TAB_BAR_HEIGHT + TAB_BAR_BORDER)


## How much the design is scaled to fit `window` (the smaller of the two ratios); 0 when
## the window has no size.
static func scale_for(window: Vector2) -> float:
	return maxf(minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y), 0.0)


## The size of the design at scale `factor` so that it fills `window`.
static func size_for(window: Vector2, factor: float) -> Vector2:
	return window / factor if factor > 0.0 else DESIGN_SIZE
