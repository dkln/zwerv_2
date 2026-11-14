extends RefCounted
## The crowd of Den Haag Centraal (logic; docs/CODE_LAGEN.md): how busy it is by the hour,
## who travels then, how many get off a train, and how often someone walks in at the doors.
## The crowd comes and goes: new travellers walk in at the doors now and then (a random
## DOOR_ARRIVAL_SECONDS apart at the busiest hour, further apart when it is quiet; quicker,
## CATCH_UP_SECONDS, while there are far fewer than the hour wants) and get off the trains;
## they leave through the doors or get into a train. Both kinds of coming in stop at
## TRAVELLER_CAP_SHARE times the travellers the hour wants (target_travellers), so the two
## balance out; a train still lets at least one person off when it is busy.
##   const CrowdRules = preload("res://scripts/world/station/station_crowd_rules.gd")

## Travellers in the station at the busiest hour, and the share of that by the hour.
const TRAVELLERS_AT_FULL := 70
const BUSY_BY_HOUR := [[0.0, 0.25], [4.0, 0.1], [6.0, 0.5], [7.5, 1.0], [9.5, 0.7], [12.5, 0.8],
	[16.0, 0.8], [17.5, 1.0], [19.0, 0.7], [22.0, 0.45], [24.0, 0.25]]
## Who travels by the hour: [from hour, {role: weight}].
const WHO_BY_HOUR := [
	[0.0, {"reiziger": 0.75, "student": 0.25}],
	[6.5, {"zakenman": 0.35, "student": 0.2, "reiziger": 0.35, "toerist": 0.1}],
	[9.5, {"zakenman": 0.12, "student": 0.1, "reiziger": 0.48, "toerist": 0.3}],
	[16.0, {"zakenman": 0.35, "student": 0.2, "reiziger": 0.35, "toerist": 0.1}],
	[19.0, {"zakenman": 0.05, "student": 0.2, "reiziger": 0.6, "toerist": 0.15}],
]
const DEFAULT_ROLE := "reiziger"
## People getting out of a train at the busiest hour (fewer when it is quiet; trains come
## often, so not too many each time), times a random factor between these two.
const ALIGHTING_AT_FULL := 10
const ALIGHTING_SPREAD := Vector2(0.5, 1.2)
const DOOR_ARRIVAL_SECONDS := Vector2(1.5, 5.0)
const CATCH_UP_SECONDS := Vector2(0.5, 1.4)
const TRAVELLER_CAP_SHARE := 1.2
## Someone off a train who stays a while: a look at the departure boards first.
const LINGER_CHANCE := 0.15
## Travellers added per frame when the hall is topped up.
const POPULATE_PER_FRAME := 3
## Someone waiting for a train gives up after this many seconds (and goes on to something else).
const WAIT_TRAIN_LIMIT := 300.0


## The share (0..1) of the busiest hour at `hour` (0..24).
static func busy_share(hour: float) -> float:
	for index in BUSY_BY_HOUR.size() - 1:
		var from: Array = BUSY_BY_HOUR[index]
		var to: Array = BUSY_BY_HOUR[index + 1]
		if hour >= float(from[0]) and hour <= float(to[0]):
			return lerpf(float(from[1]), float(to[1]), (hour - float(from[0])) / maxf(float(to[0]) - float(from[0]), 0.01))
	return 0.5


## The travellers the hour wants in the station.
static func target_travellers(hour: float) -> int:
	return roundi(TRAVELLERS_AT_FULL * busy_share(hour))


## The most travellers there may be in the station at `hour` (both kinds of coming in stop there).
static func traveller_cap(hour: float) -> int:
	return ceili(target_travellers(hour) * TRAVELLER_CAP_SHARE)


## Who travels at `hour`: {role: weight}.
static func role_mix(hour: float) -> Dictionary:
	var mix: Dictionary = WHO_BY_HOUR[0][1]
	for entry: Array in WHO_BY_HOUR:
		if hour >= float(entry[0]):
			mix = entry[1]
	return mix


## The role of a traveller at `hour` for a roll (0..1).
static func role_for(hour: float, roll: float) -> String:
	var mix := role_mix(hour)
	var left := roll
	for role: String in mix:
		left -= float(mix[role])
		if left <= 0.0:
			return role
	return DEFAULT_ROLE


## How many get off a train: by how busy it is (`busy` 0..1) and a random `factor`
## (ALIGHTING_SPREAD), within the `room` left under the cap (but one when it is busy).
static func alighting(busy: float, factor: float, room: int) -> int:
	var count := roundi(ALIGHTING_AT_FULL * busy * factor)
	return clampi(count, 0, maxi(room, 1 if busy > 0.3 else 0))


## Whether there are far fewer travellers than the hour wants (they come in quicker then).
static func is_catching_up(travellers: int, wanted: int) -> bool:
	return travellers < wanted * 0.6


## Seconds to the next traveller at the doors: `seconds` at the busiest hour, further apart
## when it is quiet.
static func door_interval(seconds: float, busy: float) -> float:
	return seconds / maxf(busy, 0.2)


## Whether the hall is so empty as the player comes in that it is filled up at once.
static func needs_topping_up(people: int, wanted: int) -> bool:
	return people < wanted / 2
