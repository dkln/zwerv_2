extends RefCounted
## The sizes of the loading screen (the layout layer of scripts/ui/loading_screen.gd, which
## is the behaviour; loading_screen_rules.gd has the logic, loading_screen_view.gd builds
## it with these sizes): the bar and its segments, the panel round it and the room between
## the rows. Constants, without nodes.
##   const LoadingScreenLayout = preload("res://scripts/ui/screens/loading_screen_layout.gd")

## The layer of the screen: over the game and its HUD.
const LAYER := 100
## Segments of the progress bar and how high they are.
const SEGMENTS := 30
const SEGMENT_HEIGHT := 14
## The room between the title, what is loading and the bar.
const COLUMN_SEPARATION := 18
## The panel round the bar: its border, the room inside it, and between bar and percentage.
const BOX_BORDER := 3
const BOX_MARGIN := 12
const ROW_SEPARATION := 12
## The room kept for the percentage beside the bar (so "100%" fits and nothing jumps).
const PERCENTAGE_SIZE := Vector2(48, 0)
