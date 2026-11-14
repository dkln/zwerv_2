extends Control
## What drifts through space behind the story of the intro (scripts/ui/intro.gd): now and
## then one of the zwervers of the game (the characters of the character creation screen)
## or a tractor crosses the screen, tumbling slowly; never the same one twice in a row.
## The intro puts it over its stars and steps it on (advance).
## This is the behaviour layer: when the next one sets off, the flight under way.
## drifter_rules.gd has the logic (what drifts, the flight), drifter_layout.gd the sizes,
## drifter_view.gd makes the models and shows them.
##   const Drifter = preload("res://scripts/ui/intro/drifter.gd")

const DrifterRules = preload("res://scripts/ui/intro/drifter_rules.gd")
const DrifterLayout = preload("res://scripts/ui/intro/drifter_layout.gd")
const DrifterView = preload("res://scripts/ui/intro/drifter_view.gd")
const ScreenLayout = preload("res://scripts/ui/menu/screen_layout.gd")

## The moment (seconds on the clock handed to advance) the first one may set off, and
## after which none sets off any more.
var first_at := 0.0
var last_at := INF

var _view: DrifterView
var _last := ""         # the name of the last one (character id or tractor model), not twice in a row
var _flight := {}       # the flight under way (DrifterRules.plan_flight); empty when none
var _next_at := -1.0    # when the next one sets off (below 0: at first_at)
var _random := RandomNumberGenerator.new()


func _init() -> void:
	name = "Zwever"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_random.randomize()
	_view = DrifterView.new()
	add_child(_view)


## Starts something drifting across now and then, and moves the one under way; `clock`:
## the seconds the intro has run, `delta`: since the last step.
func advance(clock: float, delta: float) -> void:
	if _flight.is_empty() and not _set_off(clock):
		return
	var flown := DrifterRules.flown(_flight, clock)
	if flown >= 1.0:
		_flight = {}
		_view.show_nothing()
		_next_at = DrifterRules.next_start(_random, clock)
		return
	_view.show_flying(DrifterRules.position_at(_flight, flown), DrifterRules.tumble(_flight, delta))


## Whether something is on its way across now.
func is_flying() -> bool:
	return not _flight.is_empty()


## The name of what drifted last (a character id or a tractor model; "": nothing yet).
func last_drifter() -> String:
	return _last


## The toss of what drifts and how (a test seeds it).
func random() -> RandomNumberGenerator:
	return _random


func view() -> DrifterView:
	return _view


## The next one sets off, if its time has come; false when nothing flies.
func _set_off(clock: float) -> bool:
	if not DrifterRules.may_start(clock, first_at if _next_at < 0.0 else _next_at, last_at):
		return false
	var drifter_name := DrifterRules.pick_drifter(_random, _last)
	var is_character := DrifterRules.is_character(drifter_name)
	var model := DrifterView.make_character(drifter_name) if is_character else DrifterView.make_tractor(drifter_name)
	if model == null:
		_next_at = INF   # no models: nothing drifts
		return false
	_last = drifter_name
	_view.show_model(model, is_character)
	_flight = DrifterRules.plan_flight(_random, clock, ScreenLayout.DESIGN_SIZE, DrifterLayout.SIZE)
	_view.show_setting_off(_flight.shown, DrifterRules.far_share(_flight.shown, DrifterLayout.SIZE), _flight.attitude)
	return true
