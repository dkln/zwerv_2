extends RefCounted
## Fare dodging in Den Haag Centraal (logic; docs/CODE_LAGEN.md): when crossing the gate line
## is seen, why a conductor is after the player, the fine, and the names of the ways a chase
## goes. station.gd keeps who chases whom and asks here.
## The player crossing the gate line from the hall onto a platform without a check-in
## (jumping over the paddles or slipping through behind someone) is seen with
## FARE_CHECK_CHANCE (quiet .. busiest hour, more staff about); a conductor (the nearest one
## within CONDUCTOR_NOTICE_RANGE, else one at those gates) shouts and runs after them at
## CHASE_SPEED (the player walks 3, runs 6.5 m/s). Within CATCH_REACH: a fine of FINE_EUROS
## (all they have when it is less). He gives up when the player leaves the station, stays
## more than GIVE_UP_DISTANCE away for GIVE_UP_SECONDS, or after CHASE_SECONDS.
## The same the other way: from a platform into the hall still checked in (REASON_NOT_CHECKED_OUT;
## caught, the fine and he checks them out); not checked in at all: REASON_DODGING.
## On the platforms a conductor checks: the player within INSPECTION_REACH of one is asked
## for their card with INSPECTION_CHANCE (once per conductor).
##   const FareRules = preload("res://scripts/world/station/station_fare_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")
const FARE_CHECK_CHANCE := Vector2(0.35, 0.5)
const INSPECTION_REACH := 3.0
const INSPECTION_CHANCE := 0.5
const FINE_EUROS := 50.0
const CHASE_SPEED := 4.6
const CATCH_REACH := 1.0
const GIVE_UP_DISTANCE := 15.0
const GIVE_UP_SECONDS := 3.0
const CHASE_SECONDS := 30.0
const CONDUCTOR_NOTICE_RANGE := 35.0
## Every CHASE_REPLAN seconds whoever is after the player looks again which way to go.
const CHASE_REPLAN := 0.5
## How far off (m) a BOA still sees what the player does and warns them.
const WARN_REACH := 40.0
## Falling off a platform by accident: the chance at an edge, for someone walking and for a
## conductor in a chase; one chance every STUMBLE_PAUSE seconds at most.
const STUMBLE_CHANCE := 0.03
const CHASE_STUMBLE_CHANCE := 0.2
const STUMBLE_PAUSE := 5.0
## Why a conductor is after the player (also the mood of his shout, DriverShout).
const REASON_DODGING := "zwartrijden"
const REASON_NOT_CHECKED_OUT := "uitchecken"
## The way a chase goes now: straight at the player in the same area.
const PLAN_SAME_AREA := "zelfde"
## The steps of someone getting into a train or leaving: not taken off it for a chase.
const BUSY_STEPS := ["board", "leave"]


## Whether going from `previous_side` of the gate line to `side` (-1 the hall, 1 the
## platforms, 0 not known) crossed it.
static func crossed(previous_side: int, side: int) -> bool:
	return previous_side != 0 and side != previous_side


## The chance crossing the gate line without a check-in is seen: `override` when it is 0 or
## more, else by how busy it is (`busy` 0..1).
static func fare_check_chance(override: float, busy: float) -> float:
	return override if override >= 0.0 else lerpf(FARE_CHECK_CHANCE.x, FARE_CHECK_CHANCE.y, busy)


## The chance of a check on the platform: `override` when it is 0 or more.
static func inspection_chance(override: float) -> float:
	return override if override >= 0.0 else INSPECTION_CHANCE


## Why the conductor is after someone who crossed to `side`: out into the hall (-1) still
## checked in is not checked out; else (either way) fare dodging.
static func chase_reason(side: int, checked_in: bool) -> String:
	return REASON_NOT_CHECKED_OUT if side == -1 and checked_in else REASON_DODGING


## What of the fine someone with `money` pays: all they have when it is less.
static func fine_paid(money: float) -> float:
	return minf(FINE_EUROS, money)


## The line over the player who is fined for `reason` and paid `paid`.
static func fine_text(reason: String, paid: float) -> String:
	var line := "Beboet voor zwartrijden: € %d" % int(FINE_EUROS)
	if reason == REASON_NOT_CHECKED_OUT:
		line = "Beboet, niet uitgecheckt: € %d" % int(FINE_EUROS)
	if paid < FINE_EUROS:
		line += " (je had maar %s)" % MoneyText.euros(paid)
	return line


## The chance of going over a platform edge by accident.
static func stumble_chance(chasing: bool) -> float:
	return CHASE_STUMBLE_CHANCE if chasing else STUMBLE_CHANCE


## Whether someone whose last chance of stumbling was at `last_chance_at` (seconds) may have
## another at `now`.
static func may_stumble_again(now: float, last_chance_at: float) -> bool:
	return now - last_chance_at >= STUMBLE_PAUSE


## Whether someone on a step of `step_type` is getting into a train or leaving.
static func is_busy_step(step_type: String) -> bool:
	return step_type in BUSY_STEPS


## The name of the way to the edge above the player down on the rails at `spot` (the same
## while they stay about there).
static func track_plan(spot: Vector3) -> String:
	return "spoor %d %d" % [roundi(spot.x), roundi(spot.z / 3.0)]


static func is_track_plan(plan: String) -> bool:
	return plan.begins_with("spoor")


## The name of the way from one area of the station to another (StationLayout.area_of).
static func route_plan(from_area: int, to_area: int) -> String:
	return "route %d %d" % [from_area, to_area]
