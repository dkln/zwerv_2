extends RefCounted
## The logic of the wipe between two pictures (the rules layer of
## scripts/ui/swipe_transition.gd, which is the behaviour; swipe_transition_view.gd holds
## the still and wipes it away): whether a wipe that is running is the one a new call gets,
## and how long the edge waits under the still for what is behind it. Plain functions,
## without nodes or the clock (the behaviour hands the time in).
##   const SwipeTransitionRules = preload("res://scripts/ui/screens/swipe_transition_rules.gd")

## Frames the new picture gets to settle under the still before the wipe starts.
const SETTLE_FRAMES := 3
## The longest the edge waits for `hold_until` (seconds of the clock: what it waits for, such as
## regions loading on a thread, takes clock time, not game time).
const MAX_HOLD_SECONDS := 5.0
## What a wipe that made way for a new one is called after its own name.
const PREVIOUS_SUFFIX := "_vorige"


## Whether a call for a wipe gets the one that is running: only while it has not covered
## yet (two calls in one frame make one wipe); one whose edge is under way makes way.
static func reuses_running(running_has_covered: bool) -> bool:
	return not running_has_covered


## The name of a running wipe called `node_name` once it has made way for a new one.
static func previous_name(node_name: String) -> String:
	return node_name + PREVIOUS_SUFFIX


## The moment (ms on the clock) the edge stops waiting, when it starts to wait at `now_msec`
## for at most `max_hold_seconds`.
static func give_up_at(now_msec: int, max_hold_seconds: float) -> int:
	return now_msec + int(max_hold_seconds * 1000.0)


## Whether the edge still waits: what it waits for is not `ready` yet and it is not yet
## `give_up_at_msec` on the clock.
static func still_holding(ready: bool, now_msec: int, give_up_at_msec: int) -> bool:
	return not ready and now_msec < give_up_at_msec
