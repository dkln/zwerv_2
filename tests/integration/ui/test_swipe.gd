extends "res://tests/integration/support/town_test.gd"
## The swipe (scripts/ui/swipe_transition.gd): with `hold_until` set when it covers, its edge
## waits under the still until that is true (going out of a building: the street loading,
## Interiors._go_out), and gives up after max_hold_seconds (here short: the clock seconds of a
## long wait would be thousands of frames with --fixed-fps); without it, it goes at once.
##   tests/run_integration_tests.sh swipe

const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")


static func world_options() -> Dictionary:
	return {"town": false}


## Waits (clock time, at most `most_seconds`) until no swipe is running.
func _swipe_gone(most_seconds: float) -> bool:
	var give_up_at := Time.get_ticks_msec() + int(most_seconds * 1000.0)
	while tree.root.has_node(SwipeTransition.NODE_NAME) and Time.get_ticks_msec() < give_up_at:
		await tree.process_frame
	return not tree.root.has_node(SwipeTransition.NODE_NAME)


func test_swipe_waits_for_hold_until(test) -> void:
	var ready := [false]
	var swipe := SwipeTransition.swipe(tree)
	await swipe.covered
	swipe.hold_until = func() -> bool: return ready[0]
	var started := Time.get_ticks_msec()
	await frames(30)
	test.check(is_instance_valid(swipe) and swipe.is_inside_tree(), "de rand wacht onder het stilstaande beeld")
	ready[0] = true
	var gone := await _swipe_gone(SwipeTransition.WIPE_SECONDS + 3.0)
	test.check(gone, "klaar: de rand gaat erdoor (na %d ms)" % (Time.get_ticks_msec() - started))


func test_swipe_gives_up_waiting(test) -> void:
	var swipe := SwipeTransition.swipe(tree)
	await swipe.covered
	swipe.hold_until = func() -> bool: return false
	swipe.max_hold_seconds = 0.3
	var started := Time.get_ticks_msec()
	var gone := await _swipe_gone(3.0)
	var took := (Time.get_ticks_msec() - started) / 1000.0
	test.check(gone and took >= 0.3, "nooit klaar: na %.2f s toch door (max 0.3 s wachten)" % took)
	test.check(SwipeTransition.MAX_HOLD_SECONDS <= 5.0, "in het spel hooguit %.0f s wachten" % SwipeTransition.MAX_HOLD_SECONDS)


func test_swipe_without_hold_goes_at_once(test) -> void:
	var swipe := SwipeTransition.swipe(tree)
	await swipe.covered
	var started := Time.get_ticks_msec()
	var gone := await _swipe_gone(SwipeTransition.WIPE_SECONDS + 3.0)
	var took := (Time.get_ticks_msec() - started) / 1000.0
	test.check(gone and took < SwipeTransition.MAX_HOLD_SECONDS, "zonder hold_until meteen door (%.1f s)" % took)
