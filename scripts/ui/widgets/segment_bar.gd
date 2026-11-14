extends Control
## A segmented bar: `segments` blocks of 9 px wide and `segment_height` high, 2 px apart, on
## ink with a 2 px border; the first `fill` share of them in `full_colour`.
## It shows when the fill changes, without moving:
## - going down, what was lost stays a moment in LOSS_COLOUR (blinking), then drains away to
##   the new fill (the damage trail of a fighting game), so a hit shows how much it took;
##   a meter that runs down slowly (hunger) keeps the segment at its edge blinking while it does;
## - going up by a jump (eating, xp), the segments it gained light up and fade to their colour.
## It keeps showing a change CHANGE_HOLD seconds after the last one.

const UiStyle = preload("res://scripts/ui/ui_style.gd")

const SEGMENT_WIDTH := 9.0
const GAP := 2.0
const PADDING := 3.0
const BORDER_WIDTH := 2.0
const CHANGE_HOLD := 1.2
const CHANGE_BLINK := 6.0
## The lost part: its colour, how long it stays before it drains, how fast (share per second).
const LOSS_COLOUR := Color(1.0, 0.32, 0.22)
const LOSS_HOLD := 0.45
const LOSS_DRAIN := 0.6
const GAIN_GLOW := Color(1.0, 1.0, 1.0)
## Share of the bar a rise has to jump at once to light up.
const GAIN_JUMP := 0.02
var segments := 20:
	set(value):
		segments = value
		_resize()
var segment_height := 12:
	set(value):
		segment_height = value
		_resize()
var full_colour := Color.WHITE
var empty_colour := Color.BLACK
var fill := 1.0:
	set(value):
		var new_fill := clampf(value, 0.0, 1.0)
		# every fall shows (a meter running down); a rise only when it jumps (eating, xp), not
		# while a meter slowly fills up again
		var falls := new_fill < fill - 0.00001
		var jumps := new_fill - fill >= GAIN_JUMP
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
		queue_redraw()

var _fill_set := false        # the first fill is the start, not a change
var _change_clock := 0.0      # seconds it still shows the last change
var _going_down := false
var _lost_from := 0.0         # the fill before the loss still shown (0 = none)
var _loss_wait := 0.0         # seconds before the lost part starts to drain
var _gained_from := 0.0       # the fill before the last jump up
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	_change_clock -= delta
	if _lost_from > fill:
		_loss_wait -= delta
		if _loss_wait <= 0.0:
			_lost_from = maxf(fill, _lost_from - LOSS_DRAIN * delta)
	if _change_clock <= 0.0 and _lost_from <= fill:
		_change_clock = 0.0
		_lost_from = 0.0
		set_process(false)
	queue_redraw()


## True while it shows a change (for the tests).
func is_showing_change() -> bool:
	return _change_clock > 0.0


## How many segments of the loss are still shown in LOSS_COLOUR (for the tests).
func lost_segments() -> int:
	return maxi(0, roundi(_lost_from * segments) - roundi(fill * segments))


func _resize() -> void:
	var inner := Vector2(segments * SEGMENT_WIDTH + (segments - 1) * GAP, segment_height)
	custom_minimum_size = inner + Vector2.ONE * 2.0 * (PADDING + BORDER_WIDTH)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BORDER)
	draw_rect(Rect2(Vector2.ONE * BORDER_WIDTH, size - Vector2.ONE * 2.0 * BORDER_WIDTH), UiStyle.INK)
	var start := Vector2.ONE * (BORDER_WIDTH + PADDING)
	for segment_index in segments:
		var at := start + Vector2(segment_index * (SEGMENT_WIDTH + GAP), 0.0)
		draw_rect(Rect2(at, Vector2(SEGMENT_WIDTH, segment_height)), segment_colour(segment_index))


## The colour segment `segment_index` (0 = the first) has now: full or empty, or what shows a
## change under way (see the top).
func segment_colour(segment_index: int) -> Color:
	var full := roundi(fill * segments)
	var lost_to := roundi(_lost_from * segments)
	var gained_from := roundi(_gained_from * segments)
	var changing := _change_clock > 0.0
	var blink_on := fmod(_clock * CHANGE_BLINK, 1.0) < 0.5
	var glow := clampf(_change_clock / CHANGE_HOLD, 0.0, 1.0)
	var colour := full_colour if segment_index < full else empty_colour
	if segment_index >= full and segment_index < lost_to:
		# the lost part, blinking while it waits, steady while it drains
		colour = LOSS_COLOUR if (blink_on or _loss_wait <= 0.0) else LOSS_COLOUR.darkened(0.45)
	elif changing and _going_down and segment_index == full and lost_to <= full:
		# a loss smaller than a segment (a meter running down): its edge blinks
		colour = LOSS_COLOUR if blink_on else empty_colour
	elif changing and not _going_down and segment_index < full and segment_index >= gained_from:
		colour = full_colour.lerp(GAIN_GLOW, 0.75 * glow)
	return colour
