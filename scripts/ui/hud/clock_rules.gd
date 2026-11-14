extends RefCounted
## The rules of the clock of the HUD (logic; docs/CODE_LAGEN.md): how the time and the day
## are written, when it is night, and when a day has passed. Used by clock.gd.
##   const ClockRules = preload("res://scripts/ui/hud/clock_rules.gd")

const HOURS_IN_DAY := 24.0
## Night: before this hour and after that one.
const NIGHT_UNTIL := 6.5
const NIGHT_FROM := 21.0
## The hour of the day cycle fell back by more than this: it went round midnight.
const MIDNIGHT_DROP := 12.0
## No hour of the day cycle seen yet.
const NO_HOUR := -1.0


## An hour within the day (0..24): 25.25 -> 1.25.
static func hour_of_day(hour: float) -> float:
	return fposmod(hour, HOURS_IN_DAY)


## The time as the clock writes it: 8.5 -> "08:30".
static func time_text(hour: float) -> String:
	var minutes := int(hour * 60.0) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## The day as the clock writes it: "DAG 3".
static func day_text(day: int) -> String:
	return "DAG %d" % day


static func is_night(hour: float) -> bool:
	return hour < NIGHT_UNTIL or hour > NIGHT_FROM


## Whether a day passed between two looks at the day cycle: its hour went from
## `last_hour` (NO_HOUR: the first look) back to `hour`, round midnight.
static func day_passed(last_hour: float, hour: float) -> bool:
	return last_hour >= 0.0 and hour < last_hour - MIDNIGHT_DROP
