extends RefCounted
## The sizes of the pause menu (the layout layer of scripts/ui/screens/pause_menu.gd, which
## is the behaviour; pause_menu_rules.gd has the logic, pause_menu_view.gd builds and shows
## it with these sizes): how wide and high the buttons are, the margins of the panel and
## the room between its rows. Constants and plain functions, without nodes.
##   const PauseMenuLayout = preload("res://scripts/ui/screens/pause_menu_layout.gd")

## The width of the buttons of the menu itself.
const WIDTH := 300.0
## How much wider the buttons of the settings are (their values beside their names).
const SETTINGS_WIDER := 100.0
const BUTTON_HEIGHT := 44.0
## The room between the edge of the panel and what is in it.
const PANEL_MARGIN_SIDE := 18.0
const PANEL_MARGIN_TOP := 16.0
const PANEL_MARGIN_BOTTOM := 18.0
const PANEL_BORDER := 3
## The room between the rows (title, buttons, key line) and between the buttons.
const ROW_SEPARATION := 6


## The width of the buttons of the menu itself, or (`settings`) of the settings.
static func button_width(settings: bool) -> float:
	return WIDTH + (SETTINGS_WIDER if settings else 0.0)


## The smallest size of a button `width` wide.
static func button_size(width: float) -> Vector2:
	return Vector2(width, BUTTON_HEIGHT)
