extends RefCounted
## Where a floating number stands on the screen (layout; docs/CODE_LAGEN.md): over its
## point, a little to the side, with its shadow copy under it. Used by floating_numbers.gd
## and floating_numbers_view.gd.
##   const FloatingNumbersLayout = preload("res://scripts/ui/widgets/floating_numbers_layout.gd")

## How far the darker shadow copy sits below the coloured text, in design pixels.
const SHADOW_OFFSET := Vector2(0.0, 3.0)
## A few pixels of sideways spread, so numbers on the same spot do not cover each other.
const SPREAD_PIXELS := 14.0
## The size of a number when nothing else is asked (design pixels).
const FONT_SIZE := 16


## A point in window pixels (where the camera projects to) in the design pixels of a HUD
## that is drawn `root_scale` times as big.
static func design_point(window_point: Vector2, root_scale: float) -> Vector2:
	return window_point / maxf(root_scale, 0.001)


## The top left corner of a number of `label_size` whose middle stands at `on_screen`,
## `shift` px to the side, on whole pixels.
static func label_position(on_screen: Vector2, label_size: Vector2, shift: float) -> Vector2:
	return (on_screen - label_size * 0.5 + Vector2(shift, 0.0)).round()
