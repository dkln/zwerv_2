extends RefCounted
## The logic of the queue of Burgerzaken in the city hall (docs/CODE_LAGEN.md): the numbers
## and what the boards and the loudspeakers say of them, which counter may call the next,
## what a counter does once it has called (a visitor walks there, the player is waited for,
## nobody comes), where a visitor goes to sit after, and what a clerk says to who comes out
## of turn. A ticket is {"number", "who": a visitor, or PLAYER, or "" for one who does not
## come}. Behaviour: city_hall.gd; the rest of the building's logic: city_hall_rules.gd.
##   const CityHallQueueRules = preload("res://scripts/world/interiors/city_hall_queue_rules.gd")

## Seconds a visitor stands at the counter, a counter waits for a number nobody comes for,
## waits for you (your number), rests before it calls the next, and rests at the start; how
## fast visitors walk (m/s); how far on your number is (from .. to places); how many numbers
## the waiting board shows.
const SERVE_SECONDS := Vector2(8.0, 22.0)
const NO_SHOW_SECONDS := 5.0
const PLAYER_WAIT := 45.0
const CALL_PAUSE := Vector2(2.0, 6.0)
const FIRST_CALL := Vector2(1.0, 8.0)
const VISITOR_PACE := 1.3
const TICKET_GAP := Vector2i(3, 7)
const BOARD_LINES := 4
## The last number given out before the first, and the number the boards count back from.
const LAST_ISSUED := 40
const NEXT_NUMBER := 41
## The meta on the player with its number, and the slip in the pockets (Items).
const TICKET_META := "wachtnummer"
const TICKET_ITEM := "wachtnummer"
## The floor of Burgerzaken.
const COUNTER_FLOOR := 1
## A visitor is at its spot when within this (metres); a seat is taken by who is within this.
const AT_SPOT := 0.6
const SEAT_TAKEN_WITHIN := 0.3
const CLERK_ROLE := "loketmedewerker"
const VISITOR_ROLE := "klant"
## Who a ticket of the player is of.
const PLAYER := "speler"
## What a counter is doing: free, a visitor walking to it, serving them, the visitor walking
## back, waiting for a number nobody has, waiting for the player.
const FREE := "vrij"
const WALKING := "lopen"
const SERVING := "bediend"
const GOING_BACK := "terug"
const NOBODY := "niemand"
const FOR_PLAYER := "speler"
## What a clerk says, crosser every time, when you come to the counter out of turn: without a
## number, and with one that is not called yet.
const CROSS_NO_TICKET := ["Eerst een nummertje trekken, bij de automaat bij de ingang.",
	"Nee. Eerst een nummertje. Daar, bij de automaat.",
	"Hoe vaak moet ik het nog zeggen? Een NUMMERTJE. Beveiliging!"]
const CROSS_NOT_YET := ["U bent nog niet aan de beurt. Let op het bord, dan roepen we u om.",
	"U bent écht nog niet aan de beurt. Gaat u zitten.",
	"Nu is het klaar. Ik bel de beveiliging."]
const MISSED_THOUGHT := "Mijn nummer is al geweest. Gemist. Dan maar een nieuw nummertje trekken."
## The offence of coming to a counter out of turn (uitzetten.json), and the consequence of a
## clerk's answer that sends you on to a colleague (Conversations "gevolg").
const OFFENCE := "voordringen"
const SENT_ON := "doorverwezen"
const WAITING_HEADING := "AAN DE BEURT"
const NOW_HEADING := "NU AAN DE BEURT"
const NOW_NOBODY := "B ---"


## A ticket: `number` for `who` (a visitor, PLAYER, or "": nobody comes for it).
static func ticket(number: int, who: Variant) -> Dictionary:
	return {"number": number, "who": who}


## Whether `queue_ticket` is the player's.
static func is_players(queue_ticket: Dictionary) -> bool:
	var who: Variant = queue_ticket.get("who")
	return who is String and String(who) == PLAYER


## `queue` without the player's ticket.
static func without_player(queue: Array[Dictionary]) -> Array[Dictionary]:
	return queue.filter(func(queue_ticket: Dictionary) -> bool: return not is_players(queue_ticket))


## A number as the boards write it: "B 047".
static func number_text(number: int) -> String:
	return "B %03d" % number


## What the board over counter `counter_number` says before it has called anyone.
static func counter_start_text(counter_number: int) -> String:
	return number_text(NEXT_NUMBER - 4 + counter_number)


## A line of the waiting board: "B 047 → 3".
static func called_line(number: int, counter_number: int) -> String:
	return "%s → %d" % [number_text(number), counter_number]


## The numbers called (`called`, the last first) with `line` before them: at most BOARD_LINES.
static func remember_called(called: Array[String], line: String) -> Array[String]:
	var lines: Array[String] = [line]
	lines.append_array(called)
	lines.resize(mini(lines.size(), BOARD_LINES))
	return lines


## The lines of the waiting board under its heading: the last numbers called (BOARD_LINES
## lines, empty where there is none), then how many wait.
static func board_texts(called: Array[String], waiting: int) -> Array[String]:
	var texts: Array[String] = []
	for line_index in BOARD_LINES:
		texts.append(called[line_index] if line_index < called.size() else "")
	texts.append("WACHTEND: %d" % waiting)
	return texts


## What the big board says when `number` is called at `counter_number`.
static func now_text(number: int, counter_number: int) -> String:
	return "%s  →  LOKET %d" % [number_text(number), counter_number]


## What the loudspeakers say when `number` is called at `counter_number`.
static func announcement(number: int, counter_number: int) -> String:
	return "Nummer %s, loket %d." % [number_text(number), counter_number]


## What the player thinks taking `number`, with what the board says now (`called`).
static func ticket_thought(number: int, called: Array[String]) -> String:
	if called.is_empty():
		return "Zo, nummertje %s. Er is nog niemand omgeroepen. Dat wordt even wachten." % number_text(number)
	return "Zo, nummertje %s. Op het bord staat nu %s. Dat wordt even wachten." % [number_text(number), called[0].get_slice(" →", 0)]


## How many numbers nobody comes for are given out before the player's, `places` on.
static func skipped_before(places: int) -> int:
	return maxi(places - 1, 0)


## Whether counter `counter_number` may call the first of `queue` now: there is one, and it
## is not the player's at a counter whose clerk sent them on (`sent_away`).
static func may_call(queue: Array[Dictionary], counter_number: int, sent_away: Array[int]) -> bool:
	if queue.is_empty():
		return false
	return not (is_players(queue[0]) and sent_away.has(counter_number))


## What a counter does once it has called `called_ticket`: WALKING (`visitor_comes`: its
## visitor is there), FOR_PLAYER (the player's), else NOBODY.
static func state_after_call(called_ticket: Dictionary, visitor_comes: bool) -> String:
	if visitor_comes:
		return WALKING
	return FOR_PLAYER if is_players(called_ticket) else NOBODY


## How long a counter waits in `state` for who it called (FOR_PLAYER, NOBODY; else 0).
static func wait_seconds(state: String) -> float:
	match state:
		FOR_PLAYER:
			return PLAYER_WAIT
		NOBODY:
			return NO_SHOW_SECONDS
	return 0.0


## Whether a visitor at `at` is at `spot` (along the floor): near it, or its path there used up.
static func is_at_spot(at: Vector3, spot: Vector3, path_used_up: bool) -> bool:
	return Vector2(at.x - spot.x, at.z - spot.z).length() < AT_SPOT or path_used_up


## Whether a walker's path is used up (at the end of where it could go): it has one, it is
## empty, and it was not just looked for again (`clock`: seconds till the next look, `replan`:
## the seconds between two looks).
static func is_path_used_up(has_path: bool, path_left: int, clock: float, replan: float) -> bool:
	return has_path and path_left == 0 and clock < replan - 0.05


## The index of the clerk nearest (along x) to the counter at `counter_x`, of the clerks at
## `clerk_xs`; the first of equals, -1 without clerks.
static func nearest_clerk(clerk_xs: Array, counter_x: float) -> int:
	var nearest := -1
	for clerk_index in clerk_xs.size():
		if nearest < 0 or absf(float(clerk_xs[clerk_index]) - counter_x) < absf(float(clerk_xs[nearest]) - counter_x):
			nearest = clerk_index
	return nearest


## The seats of `seats` nobody has: none of `taken` (where others sit or go to sit) within
## SEAT_TAKEN_WITHIN of it.
static func free_seats(seats: Array[Transform3D], taken: Array[Vector3]) -> Array[Transform3D]:
	var free: Array[Transform3D] = []
	for seat in seats:
		if not taken.any(func(spot: Vector3) -> bool: return spot.distance_to(seat.origin) < SEAT_TAKEN_WITHIN):
			free.append(seat)
	return free


## Where the player's number is called now, seen from counter `counter_number` (`counters`:
## {"number", "state"} each): {"here": at this one, "elsewhere": the number of another
## counter that waits for them (the last such), 0 when none}.
static func called_where(counters: Array[Dictionary], counter_number: int) -> Dictionary:
	var where := {"here": false, "elsewhere": 0}
	for counter in counters:
		if String(counter.state) != FOR_PLAYER:
			continue
		if int(counter.number) == counter_number:
			where.here = true
		else:
			where.elsewhere = int(counter.number)
	return where


## What a clerk says the `times`-th time (from 1) you come out of turn, crosser every time:
## without a number (`has_ticket` false) or with one not called yet.
static func cross_line(times: int, has_ticket: bool) -> String:
	var lines: Array = CROSS_NOT_YET if has_ticket else CROSS_NO_TICKET
	return lines[clampi(times - 1, 0, lines.size() - 1)]


## The page a clerk says `line` with, cross.
static func cross_page(line: String) -> Dictionary:
	return {"kind": "gesprek", "speaker": "AMBTENAAR", "text": line, "mood": "boos"}


## The page a clerk sends you to counter `counter_number` with (your number is called there).
static func elsewhere_page(counter_number: int) -> Dictionary:
	return {"kind": "gesprek", "speaker": "AMBTENAAR", "text": "U moet bij loket %d zijn." % counter_number}


## The counters whose clerk sent the player on, after the one of `counter_number` did
## (`sent_away` before it): added once; when every counter (`counter_count`) has, the
## oldest is forgotten.
static func sent_away_after(sent_away: Array[int], counter_number: int, counter_count: int) -> Array[int]:
	var sent := sent_away.duplicate()
	if not sent.has(counter_number):
		sent.append(counter_number)
	if sent.size() >= counter_count:
		sent.pop_front()
	return sent
