extends Control
## The clock of the HUD (the node "Klok", under the minimap; behaviour,
## docs/CODE_LAGEN.md): the day and the time. It reads the time from the day cycle of the
## town (follow: its time_of_day; a day passes when it goes round midnight), or is set by
## hand (set_time), after which the day cycle is no longer followed. How they are written:
## clock_rules.gd; its picture: clock_view.gd.
##   const Clock = preload("res://scripts/ui/hud/clock.gd")

const ClockRules = preload("res://scripts/ui/hud/clock_rules.gd")
const ClockView = preload("res://scripts/ui/hud/clock_view.gd")

## Its picture.
var view: ClockView

var _day := 1
var _hour := 12.0
var _last_cycle_hour := ClockRules.NO_HOUR
var _set_by_hand := false


func _init() -> void:
	name = "Klok"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = ClockView.new()
	add_child(view)


## The day the count starts on.
func set_day(day: int) -> void:
	_day = day


func day() -> int:
	return _day


## The hour of the day (0..24).
func hour() -> float:
	return _hour


## The clock by hand, when there is no day cycle (or to override it): hour 0..24, and the
## day if >= 1.
func set_time(new_hour: float, new_day := -1) -> void:
	_set_by_hand = true
	_hour = ClockRules.hour_of_day(new_hour)
	if new_day >= 1:
		_day = new_day
	_show()


## A look at `day_cycle` (the Dagcyclus of the town, null: none): its hour is the time, a
## day more when it went round midnight; then shows the clock.
func follow(day_cycle: Node) -> void:
	if day_cycle != null and not _set_by_hand and "time_of_day" in day_cycle:
		var cycle_hour: float = day_cycle.time_of_day
		if ClockRules.day_passed(_last_cycle_hour, cycle_hour):
			_day += 1
		_last_cycle_hour = cycle_hour
		_hour = cycle_hour
	_show()


func _show() -> void:
	view.show_clock(ClockRules.time_text(_hour), ClockRules.day_text(_day), ClockRules.is_night(_hour))
