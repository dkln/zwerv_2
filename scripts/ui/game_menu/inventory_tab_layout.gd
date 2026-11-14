extends RefCounted
## The sizes of the INVENTARIS tab of the game menu (layout; docs/CODE_LAGEN.md): the grid
## of slots, the column of the character and the panel of the chosen item. Built with these
## by inventory_tab_view.gd; inventory_tab.gd is the behaviour, inventory_tab_rules.gd the
## logic.
##   const InventoryTabLayout = preload("res://scripts/ui/game_menu/inventory_tab_layout.gd")

const GRID_COLUMNS := 6
const GRID_ROWS := 5
const SLOT_SIZE := 69.0
const SLOT_GAP := 6
## Screen pixels per pixel of an item's icon in a slot, and in the panel of the chosen item.
const SLOT_ICON_PIXEL := 3.0
const DETAIL_ICON_PIXEL := 4.0
## The column of the character: its width and the height of the frame of the figure.
const CHARACTER_WIDTH := 320.0
const FIGURE_HEIGHT := 196.0
## The bars of the stats under the figure.
const STAT_SEGMENTS := 24
const STAT_SEGMENT_HEIGHT := 8
const CATEGORY_HEIGHT := 36.0
## The frame of the icon of the chosen item, and the height of the buttons under it.
const DETAIL_ICON_FRAME := 72.0
const BUTTON_HEIGHT := 44.0
## The hard shadow of a chosen slot and of the use button.
const CHOSEN_SHADOW := 3.0


## How many slots the grid has.
static func slot_count() -> int:
	return GRID_COLUMNS * GRID_ROWS


## The smallest size of one slot.
static func slot_size() -> Vector2:
	return Vector2(SLOT_SIZE, SLOT_SIZE)


## How far a step in `direction` (arrows) moves through the slots, counted row by row.
static func slot_step(direction: Vector2i) -> int:
	return direction.x + direction.y * GRID_COLUMNS
