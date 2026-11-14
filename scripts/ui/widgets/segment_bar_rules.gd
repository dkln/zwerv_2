extends RefCounted
## The rules of a segmented bar (logic; docs/CODE_LAGEN.md): when a change of its fill
## shows, how the lost part drains away, and what each segment is at a moment: full, empty,
## just lost or just gained. Kept by segment_bar.gd, coloured by segment_bar_view.gd.
##   const SegmentBarRules = preload("res://scripts/ui/widgets/segment_bar_rules.gd")

## Seconds a change keeps showing after the last one, and how often it blinks (per second).
const CHANGE_HOLD := 1.2
const CHANGE_BLINK := 6.0
## The lost part: how long it stays before it drains, and how fast (share per second).
const LOSS_HOLD := 0.45
const LOSS_DRAIN := 0.6
## Share of the bar a rise has to jump at once to light up.
const GAIN_JUMP := 0.02
## The least fall that counts as one.
const FALL_MARGIN := 0.00001
## What a segment is (segment_state).
const FULL := "full"
const EMPTY := "empty"
const LOST := "lost"
const LOST_DIM := "lost_dim"
const GAINED := "gained"


## A fill within the bar (0..1).
static func clamped(fill: float) -> float:
	return clampf(fill, 0.0, 1.0)


## Whether going from `old_fill` to `new_fill` is a fall: every fall shows (a meter running down).
static func falls(old_fill: float, new_fill: float) -> bool:
	return new_fill < old_fill - FALL_MARGIN


## Whether going from `old_fill` to `new_fill` is a jump up (eating, xp): a rise only shows
## when it jumps, not while a meter slowly fills up again.
static func jumps(old_fill: float, new_fill: float) -> bool:
	return new_fill - old_fill >= GAIN_JUMP


## How many of `segments` segments a `fill` (0..1) fills.
static func full_segments(fill: float, segments: int) -> int:
	return roundi(fill * segments)


## How many segments of a loss from `lost_from` down to `fill` are still shown.
static func lost_segments(lost_from: float, fill: float, segments: int) -> int:
	return maxi(0, full_segments(lost_from, segments) - full_segments(fill, segments))


## The fill the lost part still reaches after draining `delta` seconds: down to `fill`.
static func drained(lost_from: float, fill: float, delta: float) -> float:
	return maxf(fill, lost_from - LOSS_DRAIN * delta)


## Whether a blinking segment is on, `clock` seconds in.
static func is_blink_on(clock: float) -> bool:
	return fmod(clock * CHANGE_BLINK, 1.0) < 0.5


## How strongly the gained segments still light up (1 just gained .. 0) with `change_left`
## seconds of the change to go.
static func glow(change_left: float) -> float:
	return clampf(change_left / CHANGE_HOLD, 0.0, 1.0)


## Whether a bar is done showing its change: its hold is over (`change_left` seconds to go)
## and nothing lost is left over the `fill`.
static func is_change_over(change_left: float, lost_from: float, fill: float) -> bool:
	return change_left <= 0.0 and lost_from <= fill


## What segment `segment_index` (0 = the first) is now. `full`: how many segments are full;
## `lost_to`: up to which segment the loss still shows; `gained_from`: from which segment the
## last jump up came; `changing`: a change is showing, `going_down`: it was a fall;
## `blink_on`: the blink is on; `draining`: the lost part has started to drain.
## - the lost part: LOST, blinking with LOST_DIM while it waits, steady while it drains;
## - a loss smaller than a segment (a meter running down): its edge blinks LOST and EMPTY;
## - the segments of a jump up: GAINED;
## - else FULL or EMPTY.
static func segment_state(segment_index: int, full: int, lost_to: int, gained_from: int, changing: bool,
		going_down: bool, blink_on: bool, draining: bool) -> String:
	if segment_index >= full and segment_index < lost_to:
		return LOST if (blink_on or draining) else LOST_DIM
	if changing and going_down and segment_index == full and lost_to <= full:
		return LOST if blink_on else EMPTY
	if changing and not going_down and segment_index < full and segment_index >= gained_from:
		return GAINED
	return FULL if segment_index < full else EMPTY
