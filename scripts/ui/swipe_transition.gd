extends CanvasLayer
## A wipe as in the old films (the Star Wars wipe): the picture as it was is held (a still of
## it, over everything), the change happens behind it, and a hard straight edge sweeps slowly
## across from left to right, wiping the old picture away to show the new one behind it. For
## going into or out of a building (Interiors) and between the main menu and the character
## creation. `covered` fires once the still is up (change what you like then: it is not seen),
## `finished` when the edge is through. It runs while the tree is paused too.
## What is behind it may need longer than SETTLE_FRAMES to be ready (the town round the door
## you come out of, still loading: Interiors._go_out): set `hold_until` (a Callable -> bool)
## when `covered` fires, and the edge waits under the still until it is true (at most
## MAX_HOLD_SECONDS of the clock), then SETTLE_FRAMES more, so the new picture is drawn whole.
## This is the behaviour layer: one wipe at a time, the frames it waits, when `covered` and
## `finished` fire. screens/swipe_transition_rules.gd has the logic (which wipe a call gets,
## how long the edge waits), screens/swipe_transition_view.gd holds the still and wipes it away.
##   const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
##   var swipe := SwipeTransition.swipe(get_tree())
##   await swipe.covered
##   ... (teleport, change the scene)

signal covered
signal finished

const SwipeTransitionRules = preload("res://scripts/ui/screens/swipe_transition_rules.gd")
const SwipeTransitionView = preload("res://scripts/ui/screens/swipe_transition_view.gd")
const NODE_NAME := "Swipe"
## The numbers of the rules and the view, here for whoever has the wipe at hand.
const SETTLE_FRAMES := SwipeTransitionRules.SETTLE_FRAMES
const MAX_HOLD_SECONDS := SwipeTransitionRules.MAX_HOLD_SECONDS
const WIPE_SECONDS := SwipeTransitionView.WIPE_SECONDS
const SHADER := SwipeTransitionView.SHADER
const LAYER := 128

## True once `covered` has fired.
var has_covered := false
## Set when `covered` fires: the edge waits until this is true (see the top).
var hold_until := Callable()
## The longest it waits for hold_until (seconds of the clock).
var max_hold_seconds := MAX_HOLD_SECONDS
var _view: SwipeTransitionView


## Starts a wipe over everything. A running one that has not covered yet is returned (so two
## calls in one frame make one wipe); one that already covered (its edge under way) makes way
## for a new one, so `covered` of what is returned always still comes.
static func swipe(tree: SceneTree) -> CanvasLayer:
	var running := tree.root.get_node_or_null(NODE_NAME) as CanvasLayer
	if running:
		if SwipeTransitionRules.reuses_running(bool(running.get("has_covered"))):
			return running
		running.name = SwipeTransitionRules.previous_name(NODE_NAME)
	var transition: CanvasLayer = (load("res://scripts/ui/swipe_transition.gd") as GDScript).new()
	tree.root.add_child(transition)
	transition.call("_run")
	return transition


func _init() -> void:
	name = NODE_NAME
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = SwipeTransitionView.new()
	add_child(_view)


## Where the edge is now (0: the whole still, 1: all of it wiped away).
func edge() -> float:
	return _view.edge()


func _set_edge(value: float) -> void:
	_view.show_edge(value)


func _run() -> void:
	# the picture as it is now (the last frame drawn), held
	await get_tree().process_frame
	# (headless, as in the checks, nothing is drawn: no picture to hold, and asking for one
	# only makes the renderer complain "Parameter t is null")
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image and not image.is_empty():
			_view.show_still(image)
	_view.show_edge(0.0)
	has_covered = true
	covered.emit()
	for frame_index in SETTLE_FRAMES:
		await get_tree().process_frame
	if hold_until.is_valid():
		var give_up_at := SwipeTransitionRules.give_up_at(Time.get_ticks_msec(), max_hold_seconds)
		while SwipeTransitionRules.still_holding(bool(hold_until.call()), Time.get_ticks_msec(), give_up_at):
			await get_tree().process_frame
		for frame_index in SETTLE_FRAMES:
			await get_tree().process_frame
	await _view.play_wipe().finished
	finished.emit()
	queue_free()
