extends Control
## A segmented bar: `segments` blocks of 9 px wide and `segment_height` high, 2 px apart, on
## ink with a 2 px border; the first `fill` share of them in `full_colour`.
## It shows when the fill changes, without moving:
## - going down, what was lost stays a moment in the loss colour (blinking), then drains away
##   to the new fill (the damage trail of a fighting game), so a hit shows how much it took;
##   a meter that runs down slowly (hunger) keeps the segment at its edge blinking while it does;
## - going up by a jump (eating, xp), the segments it gained light up and fade to their colour.
## It keeps showing a change CHANGE_HOLD seconds after the last one.
## Behaviour (docs/CODE_LAGEN.md): it keeps the fill and the change under way; what a
## segment is at a moment is segment_bar_rules.gd, its size segment_bar_layout.gd, its
## picture segment_bar_view.gd.
##   const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")

const SegmentBarRules = preload("res://scripts/ui/widgets/segment_bar_rules.gd")
const SegmentBarLayout = preload("res://scripts/ui/widgets/segment_bar_layout.gd")
const SegmentBarView = preload("res://scripts/ui/widgets/segment_bar_view.gd")
const CHANGE_HOLD := SegmentBarRules.CHANGE_HOLD
const LOSS_HOLD := SegmentBarRules.LOSS_HOLD
const LOSS_DRAIN := SegmentBarRules.LOSS_DRAIN

var segments := 20:
	set(value):
		segments = value
		_resize()
var segment_height := 12:
	set(value):
		segment_height = value
		view.segment_height = value
		_resize()
var full_colour := Color.WHITE:
	set(value):
		full_colour = value
		view.full_colour = value
var empty_colour := Color.BLACK:
	set(value):
		empty_colour = value
		view.empty_colour = value
var fill := 1.0:
	set(value):
		var new_fill := SegmentBarRules.clamped(value)
		var falls := SegmentBarRules.falls(fill, new_fill)
		var jumps := SegmentBarRules.jumps(fill, new_fill)
		if _fill_set and (falls or jumps):
			_change_clock = CHANGE_HOLD
			_going_down = falls
			if falls:
				_lost_from = maxf(_lost_from, fill)
				_loss_wait = LOSS_HOLD
			else:
				_gained_from = fill
				_lost_from = 0.0
			set_process(true)
		_fill_set = true
		fill = new_fill
		_show()
## Its picture.
var view: SegmentBarView

var _fill_set := false        # the first fill is the start, not a change
var _change_clock := 0.0      # seconds it still shows the last change
var _going_down := false
var _lost_from := 0.0         # the fill before the loss still shown (0 = none)
var _loss_wait := 0.0         # seconds before the lost part starts to drain
var _gained_from := 0.0       # the fill before the last jump up
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = SegmentBarView.new()
	add_child(view)
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and view:
		view.size = size


func _process(delta: float) -> void:
	_clock += delta
	_change_clock -= delta
	if _lost_from > fill:
		_loss_wait -= delta
		if _loss_wait <= 0.0:
			_lost_from = SegmentBarRules.drained(_lost_from, fill, delta)
	if SegmentBarRules.is_change_over(_change_clock, _lost_from, fill):
		_change_clock = 0.0
		_lost_from = 0.0
		set_process(false)
	_show()


## True while it shows a change (for the tests).
func is_showing_change() -> bool:
	return _change_clock > 0.0


## How many segments of the loss are still shown in the loss colour (for the tests).
func lost_segments() -> int:
	return SegmentBarRules.lost_segments(_lost_from, fill, segments)


## The colour segment `segment_index` (0 = the first) has now: full or empty, or what shows a
## change under way (see the top).
func segment_colour(segment_index: int) -> Color:
	return view.colour_of(_segment_state(segment_index), SegmentBarRules.glow(_change_clock))


func _resize() -> void:
	custom_minimum_size = SegmentBarLayout.bar_size(segments, segment_height)
	size = custom_minimum_size
	view.size = size
	_show()


## What segment `segment_index` is now (SegmentBarRules.segment_state).
func _segment_state(segment_index: int) -> String:
	return SegmentBarRules.segment_state(segment_index, SegmentBarRules.full_segments(fill, segments),
			SegmentBarRules.full_segments(_lost_from, segments), SegmentBarRules.full_segments(_gained_from, segments),
			_change_clock > 0.0, _going_down, SegmentBarRules.is_blink_on(_clock), _loss_wait <= 0.0)


## Hands the view what every segment is now.
func _show() -> void:
	var states := []
	for segment_index in segments:
		states.append(_segment_state(segment_index))
	view.show_segments(states, SegmentBarRules.glow(_change_clock))
