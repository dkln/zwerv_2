extends RefCounted
## The rules of the people of the story (logic; docs/CODE_LAGEN.md): when the one you walk
## with waits for you, which line it says, where someone stands in your way and when you are
## past it, where those who come after you appear and stand, and how someone wanders its
## round. characters.gd is the node that keeps who is where and moves them; the numbers it
## draws at random are handed in here.
##   const CharacterRules = preload("res://scripts/story/character_rules.gd")

## Metres the player may be behind the one it walks with before that one waits.
const WAIT_DISTANCE := 9.0
## Seconds between two calls of the one waiting ("Kom je nog?").
const CALL_SECONDS := 9.0
const CALLS := ["Kom je nog?", "Hé, deze kant op!", "Niet treuzelen, jong."]
## Seconds between two lines of its "onderweg" while you walk along (not while it waits), and
## before the first one.
const TALK_EVERY := Vector2(9.0, 16.0)
const FIRST_TALK := Vector2(3.0, 6.0)
## Metres within which the player has come up with someone who walked on without waiting.
const ARRIVED_NEAR := 12.0
## Metres from a point of its route within which someone is there.
const AT_POINT := 6.0
## Metres before the player someone stands in the way when it has no place of its own (at
## most half the way to where the player goes).
const BLOCK_AHEAD := 12.0
## Seconds after the step begins before they come; how far off (m) they appear, behind the
## player; how near they come (the one who talks, the others round it); seconds between two
## conversations; how often (s) they look again where the player is.
const CHASE_DELAY := 4.0
const CHASE_FROM := 10.0
## How near (m) they are when they count as there (chase_near: the step shows in the task list).
const CHASE_SHOW := 6.0
const CHASE_REACH := 2.2
const CHASE_GROUP_REACH := 3.4
const CHASE_AGAIN := 6.0
const CHASE_RETARGET := 0.5
## How fast (m/s) they come after you: about as fast as you walk, so you cannot simply walk
## away; and how far behind (m) they may lose you before they turn up behind you again (round
## a corner, out of a building).
const CHASE_PACE := 3.2
const CHASE_LOST := 40.0
## Metres between those who come after you, side by side, and round the player.
const CHASE_SIDE_BY_SIDE := 1.4
const CHASE_ROUND := 1.5
## An ordinary walk (m/s), for who gives up the chase.
const WALK_PACE := 1.3
## Metres from the player at which the one wandering stops and turns to them.
const STOP_FOR_PLAYER := 3.5
## The arm of the one smoking goes to the mouth for this long (s), every SMOKE_EVERY s.
const DRAG_SECONDS := 1.4
const SMOKE_EVERY := Vector2(3.0, 6.0)
## Metres from the player within which the one wandering mutters to itself, the seconds
## between two lines and before the first.
const MUTTER_WITHIN := 30.0
const MUTTER_EVERY := Vector2(8.0, 25.0)
const FIRST_MUTTER := Vector2(2.0, 6.0)
## Metres from a point of its round within which someone wandering has reached it.
const ROUND_POINT_REACHED := 0.3
## How fast someone turns to the player it stops for, and into the way it walks (per second).
const TURN_TO_PLAYER := 6.0
const TURN_TO_WAY := 4.0
## The height of a figure of "lengte" 1 (metres).
const FIGURE_HEIGHT := 1.8


## A world position as x, z.
static func flat(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


## The top of the figure of a character over its feet (its "lengte" counted).
static func head_height(entry: Dictionary) -> float:
	return FIGURE_HEIGHT * float(entry.get("lengte", 1.0))


## A line of `lines` at `drawn` (any number from 0 up), never the one said last (`said`): the
## next one instead, when there is more than one.
static func other_line(lines: Array, drawn: int, said: String) -> String:
	var text := str(lines[drawn % lines.size()])
	if text == said and lines.size() > 1:
		text = str(lines[(lines.find(text) + 1) % lines.size()])
	return text


# ------------------------------------------------------------------ walking with the player

## What is kept of someone leading the player along `points`: where it is going ("index"),
## the clocks of its calls and its lines on the way, its own pace to go back to, whether it
## waits for the player and whether it stands at the end already ("there").
static func lead_state(points: Array, waits: bool, own_pace: Variant, first_talk: float) -> Dictionary:
	return {"points": points, "index": 0, "call": CALL_SECONDS * 0.5, "talk": first_talk, "said": "",
		"pace": own_pace, "waits": waits, "there": false}


## Whether the one leading waits now: it waits at all, the player is more than WAIT_DISTANCE
## from it and farther from where they go than it is (behind, not ahead).
static func is_behind(waits: bool, feet: Vector2, at: Vector2, goal: Vector2) -> bool:
	return waits and feet.distance_to(at) > WAIT_DISTANCE and feet.distance_to(goal) > at.distance_to(goal)


## Whether the player has come up with the one that walked on (ARRIVED_NEAR).
static func has_come_along(feet: Vector2, at: Vector2) -> bool:
	return feet.distance_to(at) <= ARRIVED_NEAR


## Whether someone at `at` is at the point `goal` of its route.
static func is_at(at: Vector2, goal: Vector2) -> bool:
	return at.distance_to(goal) < AT_POINT


## Whether a route of `count` points is walked to the end when `index` is the next point.
static func is_route_done(index: int, count: int) -> bool:
	return index >= count


# ------------------------------------------------------------------ in the way

## Where someone stands in the way (world x, z): `at` when it has a place; else a few metres
## before the player on the way to `past` (INF when that is unknown too).
static func blocking_spot(at: Vector2, feet: Variant, past: Vector2) -> Vector2:
	if at != Vector2.INF or feet == null or past == Vector2.INF:
		return at
	var from: Vector2 = feet
	return from + (past - from).normalized() * minf(BLOCK_AHEAD, from.distance_to(past) * 0.5)


## Whether the player is by the one in the way (within its `reach`).
static func is_by(feet: Vector2, at: Vector2, reach: float) -> bool:
	return feet.distance_to(at) < reach


## Whether the player, having been by the one in the way (`was_near`), is past it now: nearer
## to `past` than it is and a few metres from it (walked round it).
static func is_past(was_near: bool, feet: Vector2, at: Vector2, past: Vector2) -> bool:
	return was_near and feet.distance_to(past) + 2.0 < at.distance_to(past) and feet.distance_to(at) > 3.0


# ------------------------------------------------------------------ after the player

## What is kept of a chase: the "group" that comes along, the clock before they come and
## between two conversations ("wait"), the clock of looking where the player is ("retarget"),
## whether they came yet, and the pages to show the first time they reach the player.
static func chase_state(group: Array, first_pages: Array) -> Dictionary:
	return {"group": group.duplicate(), "wait": CHASE_DELAY, "retarget": 0.0, "came": false,
		"first_pages": first_pages.duplicate()}


## Everyone of a chase: who talks, then the group.
static func chase_names(who: String, chase: Dictionary) -> Array:
	return [who] + Array(chase.get("group", []))


## Where `count` people appear behind the player (world x, z each): CHASE_FROM away from
## where it looks (`back`: the way behind it; none: down the map), side by side.
static func chase_spots(feet: Vector2, back: Vector2, count: int) -> Array:
	var behind := back.normalized()
	if behind == Vector2.ZERO:
		behind = Vector2.DOWN
	var from := feet + behind * CHASE_FROM
	var side := behind.orthogonal()
	var spots: Array = []
	for index in count:
		spots.append(from + side * (index - (count - 1) * 0.5) * CHASE_SIDE_BY_SIDE)
	return spots


## Where the follower number `round_index` (1 for the first) of a chase goes: round the
## player, each on its own side.
static func follower_spot(feet: Vector2, round_index: int) -> Vector2:
	return feet + Vector2.from_angle(TAU * round_index / 3.0) * CHASE_ROUND


## Whether those who chase have come near enough to show (CHASE_SHOW), have lost the player
## (CHASE_LOST), have reached it (CHASE_REACH; a follower: CHASE_GROUP_REACH).
static func chase_shows(gap: float) -> bool:
	return gap <= CHASE_SHOW


static func chase_lost(gap: float) -> bool:
	return gap > CHASE_LOST


static func chase_reached(gap: float) -> bool:
	return gap <= CHASE_REACH


static func follower_reached(gap: float) -> bool:
	return gap <= CHASE_GROUP_REACH


# ------------------------------------------------------------------ wandering about

## The points of a round (world x, z): `offsets` ([x, z] or Vector2 each, metres) from
## `home`; `home` itself when there are none.
static func round_points(home: Vector2, offsets: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for offset: Variant in offsets:
		points.append(home + (offset as Vector2 if offset is Vector2 else Vector2(float(offset[0]), float(offset[1]))))
	if points.is_empty():
		points.append(home)
	return points


## What is kept of someone wandering along `points`: its "zwerft" data (`roam`: "tempo" m/s,
## "rookpauze" [from, to] seconds, else `usual_rest`), its clocks, no smoke or trolley yet.
static func wander_state(points: Array[Vector2], roam: Dictionary, usual_rest: Array) -> Dictionary:
	return {"points": points, "index": 0, "pause": 1.0, "phase": 0.0, "puff": 2.0,
		"speed": float(roam.get("tempo", 0.6)), "rest": roam.get("rookpauze", usual_rest),
		"smoke": null, "trolley": null}


## Whether the one wandering stops for the player (STOP_FOR_PLAYER).
static func stops_for(gap: float) -> bool:
	return gap < STOP_FOR_PLAYER


## Whether the one wandering has reached the point of its round it walks to.
static func round_point_reached(to_goal: Vector2) -> bool:
	return to_goal.length() < ROUND_POINT_REACHED


## How far (metres) someone walking at `speed` gets in `delta` seconds on the way `to_goal`.
static func step_length(speed: float, delta: float, to_goal: Vector2) -> float:
	return minf(speed * delta, to_goal.length())


## The angle (round y) of someone looking along `way` (x, z).
static func facing(way: Vector2) -> float:
	return atan2(way.x, way.y)


## How much of a turn is made in `delta` seconds at `rate` (0..1, for lerp_angle).
static func turn_share(delta: float, rate: float) -> float:
	return 1.0 - exp(-delta * rate)


## The phase of the walk after `delta` seconds at `speed` with strides of `stride` metres
## (`walking`: 1 walking, 0 standing: it stays).
static func walk_phase(phase: float, speed: float, delta: float, stride: float, walking: float) -> float:
	return fmod(phase + speed * delta / stride * PI * walking, TAU)


## Whether the one wandering mutters at all now (the player within MUTTER_WITHIN).
static func mutters(gap: float) -> bool:
	return gap <= MUTTER_WITHIN
