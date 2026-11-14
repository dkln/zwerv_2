extends Control
## What a segmented bar looks like (graphics; docs/CODE_LAGEN.md): blocks on ink with a
## border, each in the colour of what it is now: full, empty, just lost (LOSS_COLOUR, dimmed
## while it blinks) or just gained (lit up towards GAIN_GLOW). It draws what segment_bar.gd
## hands it (show_segments); its sizes come from segment_bar_layout.gd.
##   const SegmentBarView = preload("res://scripts/ui/widgets/segment_bar_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SegmentBarLayout = preload("res://scripts/ui/widgets/segment_bar_layout.gd")

## The lost part, and how much darker it is while its blink is off.
const LOSS_COLOUR := Color(1.0, 0.32, 0.22)
const LOSS_DIM := 0.45
## What the gained segments light up towards, and how far at most.
const GAIN_GLOW := Color(1.0, 1.0, 1.0)
const GAIN_LIGHT := 0.75

var segment_height := 12
var full_colour := Color.WHITE
var empty_colour := Color.BLACK

var _states: Array = []
var _glow := 0.0


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the segments: `states` says of each what it is ("full", "empty", "lost", "lost_dim",
## "gained"); `glow` (0..1) is how strongly the gained ones light up.
func show_segments(states: Array, glow: float) -> void:
	_states = states
	_glow = glow
	queue_redraw()


## What is shown of each segment now.
func states() -> Array:
	return _states


## The colour of a segment that is `state`, the gained ones lit up by `glow` (0..1).
func colour_of(state: String, glow: float) -> Color:
	match state:
		"full":
			return full_colour
		"lost":
			return LOSS_COLOUR
		"lost_dim":
			return LOSS_COLOUR.darkened(LOSS_DIM)
		"gained":
			return full_colour.lerp(GAIN_GLOW, GAIN_LIGHT * glow)
	return empty_colour


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BORDER)
	draw_rect(SegmentBarLayout.inside(size), UiStyle.INK)
	for segment_index in _states.size():
		draw_rect(SegmentBarLayout.segment_rect(segment_index, segment_height), colour_of(_states[segment_index], _glow))
