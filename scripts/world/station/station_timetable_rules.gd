extends RefCounted
## The timetable of Den Haag Centraal (logic; docs/CODE_LAGEN.md): what a departure is, when
## its train comes in and leaves, what the loudspeakers say about it, what the departure
## boards and the platform displays write, which train a traveller picks, and how the hands
## of the station clock stand. station.gd keeps the departures and the clock, draws the
## random numbers and asks here what they mean.
## Every track goes round: a train arrives (from its "origin"), stands DWELL_MINUTES at the
## platform (people get out and in), leaves the way it came, and GAP_MINUTES after it has
## gone the next one comes in. With the time to come in and go out (about 15 s each) a
## track has a train every 2.5 to 4.5 minutes, the twelve together one about every 20 s.
##   const TimetableRules = preload("res://scripts/world/station/station_timetable_rules.gd")

const DWELL_MINUTES := Vector2(1.6, 3.0)
const GAP_MINUTES := Vector2(0.2, 1.0)
const DELAY_CHANCE := 0.12
const DELAY_MINUTES := Vector2i(1, 5)
const CANCEL_CHANCE := 0.03
## Three cars rather than two: the chance for an Intercity and for a Sprinter.
const LONG_INTERCITY_CHANCE := 0.8
const LONG_SPRINTER_CHANCE := 0.4
## The station as you walk in: the chance a track has a train standing, in how many minutes
## that one leaves, and within how many the first one comes in on the other tracks.
const STANDING_AT_START_CHANCE := 0.45
const STANDING_LEAVES_IN := Vector2(0.8, 2.5)
const FIRST_ARRIVAL_IN := Vector2(0.1, 2.5)
## Arrivals are announced as rarely as departures (DEPARTURE_ANNOUNCE_CHANCE).
const ARRIVAL_ANNOUNCE_CHANCE := 0.15
## Seconds before leaving: the announcement, the whistle, the doors shutting.
const ANNOUNCE_SECONDS := 150.0
const WHISTLE_SECONDS := 17.0
const CLOSE_SECONDS := 12.0
## A train that does not run is announced from this many seconds before its time.
const CANCEL_NOTICE_SECONDS := 300.0
## A conductor only comes to a train that stands at least this many seconds still.
const CONDUCTOR_LEAD_SECONDS := 75.0
## The chance of the horn as a train pulls out.
const HORN_CHANCE := 0.3
## How often the loudspeakers speak: after an announcement it stays quiet a random number of
## seconds between these two; only this share of the departures is announced (with twelve
## tracks every one would be far too much), and a general notice (NOTICES) comes after a
## random wait between NOTICE_SECONDS, never the same one twice in a row. An announcement
## that had to wait longer than ANNOUNCEMENT_STALE_SECONDS is dropped (its train is gone).
const ANNOUNCEMENT_PAUSE_SECONDS := Vector2(60.0, 150.0)
const DEPARTURE_ANNOUNCE_CHANCE := 0.15
const NOTICE_SECONDS := Vector2(360.0, 900.0)
const FIRST_NOTICE_SECONDS := Vector2(120.0, 360.0)
const ANNOUNCEMENT_STALE_SECONDS := 60.0
## At most this many announcements wait their turn.
const MOST_WAITING := 2
const NOTICES := [
	"Let op: laat uw bagage niet onbeheerd achter.",
	"Roken is op het hele station niet toegestaan.",
	"Pas op voor zakkenrollers. Houd uw spullen bij u.",
	"Laat bij het instappen eerst de reizigers uitstappen.",
	"Vergeet niet in en uit te checken met uw OV-chipkaart.",
	"De lift naar perron 3 is tijdelijk buiten gebruik.",
	"Wilt u de eigenaar van een blauwe rolkoffer bij spoor 6 zich melden bij de servicebalie?",
	"Fietsen zijn in de stationshal niet toegestaan.",
]
## The states of a departure.
const PLANNED := "gepland"
const COMING_IN := "binnenkomend"
const STANDING := "staat"
const LEAVING := "vertrekkend"
const GONE := "vertrokken"
const INTERCITY := "Intercity"
## What the remark of a row on a departure board is about (board_row "remark_kind").
const REMARK_NONE := ""
const REMARK_DELAY := "vertraging"
const REMARK_CANCELLED := "rijdt_niet"


## A departure: train `id` on `track`, arriving at `arrive_at` (station minutes) and leaving
## `dwell` minutes later on the whole minute, for `destination` ([name, kind], as
## StationLayout.DESTINATIONS) from `origin`, with `cars` cars.
static func new_departure(id: int, track: int, arrive_at: float, destination: Array, origin: String,
		dwell: float, cars: int, cancelled: bool) -> Dictionary:
	return {
		"id": id, "track": track, "time": ceilf(arrive_at + dwell), "delay": 0.0,
		"destination": destination[0], "kind": destination[1], "origin": origin,
		"cars": cars, "cancelled": cancelled, "dwell": dwell,
		"state": PLANNED, "train": null, "announced": false, "cancel_announced": false,
		"whistled": false, "closing": false, "conductor": null,
	}


static func is_intercity(kind: String) -> bool:
	return kind == INTERCITY


## Whether a train for `destination` ([name, kind]) can come from `candidate`: the same kind
## of train, another place.
static func is_origin_for(candidate: Array, destination: Array) -> bool:
	return candidate[1] == destination[1] and candidate[0] != destination[0]


## The cars of a train of `kind` for a roll (0..1): three or two.
static func car_count(kind: String, roll: float) -> int:
	return 3 if roll < (LONG_INTERCITY_CHANCE if is_intercity(kind) else LONG_SPRINTER_CHANCE) else 2


## When a departure really leaves (station minutes): its time and its delay.
static func departs_at(departure: Dictionary) -> float:
	return float(departure.time) + float(departure.delay)


## Seconds until a departure leaves, at `minutes` on the station clock.
static func seconds_left(departure: Dictionary, minutes: float) -> float:
	return (departs_at(departure) - minutes) * 60.0


## Whether the train of a planned departure comes in now: its dwell before it leaves.
static func comes_in_now(departure: Dictionary, minutes: float) -> bool:
	return minutes >= departs_at(departure) - float(departure.dwell)


## Station minutes as the boards write them: "13:05" (running on past midnight).
static func clock_text(at_minutes: float) -> String:
	var whole := int(floorf(fposmod(at_minutes, 24.0 * 60.0)))
	return "%02d:%02d" % [whole / 60, whole % 60]


## The hour of the day (0..24) at `minutes` on the station clock.
static func hour_of(minutes: float) -> float:
	return fposmod(minutes / 60.0, 24.0)


## How far round the hands of the clock are (radians, clockwise negative as the hands turn):
## {"second", "minute", "hour"}.
static func clock_hand_turns(minutes: float) -> Dictionary:
	return {
		"second": -fposmod(minutes * 60.0, 60.0) / 60.0 * TAU,
		"minute": -fposmod(minutes, 60.0) / 60.0 * TAU,
		"hour": -fposmod(minutes / 60.0, 12.0) / 12.0 * TAU,
	}


## The loudspeakers: a train that does not run.
static func cancelled_text(departure: Dictionary) -> String:
	return "De %s naar %s van %s rijdt vandaag niet. Excuses voor het ongemak." % [
		departure.kind, departure.destination, clock_text(float(departure.time))]


## The loudspeakers: a train coming in.
static func arrival_text(departure: Dictionary) -> String:
	return "Op spoor %d komt binnen: de %s uit %s." % [int(departure.track), departure.kind, departure.origin]


## The loudspeakers: a train about to leave (with its delay).
static func departure_text(departure: Dictionary) -> String:
	var line := "Spoor %d: de %s naar %s, vertrekt om %s." % [int(departure.track), departure.kind, departure.destination, clock_text(departs_at(departure))]
	if float(departure.delay) > 0.0:
		line += " Deze trein heeft ongeveer %d minuten vertraging." % int(departure.delay)
	return line


## The departures a board shows (not the ones gone), in their order.
static func shown_on_boards(departures: Array) -> Array:
	return departures.filter(func(departure: Dictionary) -> bool: return departure.state != GONE)


## A row of a departure board: {"time", "destination", "track", "remark", "remark_kind"}.
static func board_row(departure: Dictionary) -> Dictionary:
	var row := {
		"time": clock_text(float(departure.time)),
		"destination": "%s  %s" % [departure.destination, "IC" if is_intercity(String(departure.kind)) else "SPR"],
		"track": str(departure.track), "remark": "", "remark_kind": REMARK_NONE,
	}
	if departure.cancelled:
		row.remark = "Rijdt niet"
		row.remark_kind = REMARK_CANCELLED
	elif float(departure.delay) > 0.0:
		row.remark = "+%d" % int(departure.delay)
		row.remark_kind = REMARK_DELAY
	return row


## The two lines of the display at the head of a track: {"time", "destination"}.
static func display_lines(departure: Dictionary) -> Dictionary:
	var when := clock_text(float(departure.time))
	var time_line := "%s  %s" % [when, departure.kind]
	if departure.cancelled:
		time_line = "%s  Rijdt niet" % when
	elif float(departure.delay) > 0.0:
		time_line = "%s +%d  %s" % [when, int(departure.delay), departure.kind]
	return {"time": time_line, "destination": String(departure.destination)}


## The departures a traveller can pick at `minutes`: running, leaving between `soonest` and
## `latest` minutes from now, not the one with `except_id`; the soonest first.
static func choosable(departures: Array, minutes: float, soonest: float, latest: float, except_id := -1) -> Array:
	var choices := departures.filter(func(departure: Dictionary) -> bool:
		var left := departs_at(departure) - minutes
		return not departure.cancelled and left >= soonest and left <= latest and int(departure.id) != except_id)
	choices.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return departs_at(first) < departs_at(second))
	return choices


## Which of `count` choices (the soonest first) a roll (0..1) picks: sooner ones more likely.
static func choice_index(roll: float, count: int) -> int:
	return mini(int(floorf(pow(roll, 1.6) * count)), count - 1)


## Whether someone waiting for `departure` has missed it: none, gone, or not running and
## past its time.
static func is_missed(departure: Dictionary, minutes: float) -> bool:
	return departure.is_empty() or departure.state == GONE or (departure.cancelled and seconds_left(departure, minutes) <= 0.0)


## Whether people can get into the train of `departure` now (its doors may still be shut).
static func is_boarding(departure: Dictionary) -> bool:
	return departure.state == STANDING and not departure.closing


## Whether someone can still make `departure` from where they are (after a fall, a detour).
static func can_still_catch(departure: Dictionary, minutes: float) -> bool:
	return not departure.is_empty() and departure.state != GONE and not departure.cancelled and seconds_left(departure, minutes) > 40.0


## Another notice than the last one: `pick` (0..NOTICES-1) was the same, `extra_pick`
## (0..NOTICES-2) moves it on.
static func other_notice(pick: int, extra_pick: int) -> int:
	return (pick + 1 + extra_pick) % NOTICES.size()


## Whether an announcement queued at `queued_at` (station minutes) waited too long.
static func is_stale(queued_at: float, minutes: float) -> bool:
	return (minutes - queued_at) * 60.0 > ANNOUNCEMENT_STALE_SECONDS
