extends RefCounted
## The rules of the sellers of Straatnieuws by the supermarkets (logic; docs/CODE_LAGEN.md):
## who they are, the chance one turns up, the round it shuffles before a door, which
## supermarket is near and when it may go again. street_paper_sellers.gd is the node that
## keeps the clocks and asks Characters for them.
##   const StreetPaperSellerRules = preload("res://scripts/story/street_paper_seller_rules.gd")

const SELLERS := ["straatnieuws_ans", "straatnieuws_henk"]
## Seconds between two looks, the chance a seller turns up at a look (near a supermarket), how
## near (metres) that is, how long one stays (seconds, from .. to) and how near the player may
## be when they go (they do not vanish under its eyes).
const LOOK_EVERY := 15.0
const CHANCE := 0.45
const NEAR_SUPERMARKET := 90.0
const STAYS := Vector2(90.0, 240.0)
const LEAVE_UNSEEN_BEYOND := 30.0
## The round before the door (metres from the way in, outwards and along the front).
const ROUND := [Vector2(0.0, 0.0), Vector2(3.0, 0.0), Vector2(3.0, 2.0), Vector2(-3.0, 2.0), Vector2(-3.0, 0.0)]
## What they call out, how often (seconds, from .. to) and within how many metres of the player.
const CALLS := ["Straatnieuws! Nieuwe editie!", "Straatnieuws, steun de verkoper!", "Straatnieuws! Met puzzel!",
	"Twee vijftig, en de helft is voor mij!", "Straatnieuws! Lees wat de krant niet schrijft!", "Goedemiddag! Straatnieuws?"]
const CALL_EVERY := Vector2(7.0, 14.0)
const CALL_WITHIN := 22.0
## Metres before the door (outwards) the middle of the round lies.
const BEFORE_DOOR := 3.0


## Where a seller stands before a way in (world x, z): BEFORE_DOOR outwards from its door.
static func spot_before(door: Vector3, outward: Vector3) -> Vector2:
	var at := door + outward * BEFORE_DOOR
	return Vector2(at.x, at.z)


## The round before a door that looks `outward` (x, z offsets from spot_before): ROUND with
## its x along the front and its y outwards.
static func round_points(outward: Vector3) -> Array:
	var across := Vector2(-outward.z, outward.x)
	var points: Array = []
	for point: Vector2 in ROUND:
		points.append(across * point.x + Vector2(outward.x, outward.z) * point.y)
	return points


## The way in of `ways_in` (each {"door": Vector3, ...}) nearest `player_position`, within
## NEAR_SUPERMARKET of it; {} when none is that near.
static func nearest_door(ways_in: Array, player_position: Vector3) -> Dictionary:
	var best := {}
	var best_gap := NEAR_SUPERMARKET
	for way_in: Dictionary in ways_in:
		var gap := (way_in.door as Vector3).distance_to(player_position)
		if gap < best_gap:
			best_gap = gap
			best = way_in
	return best


## Whether a seller goes now: its time is up and the player does not see it (far enough
## off, or inside).
static func may_leave(seconds_left: float, gap: float, player_inside: bool) -> bool:
	return seconds_left <= 0.0 and (gap > LEAVE_UNSEEN_BEYOND or player_inside)


## Whether a seller is near enough to the player to call out (CALL_WITHIN).
static func within_call(gap: float) -> bool:
	return gap <= CALL_WITHIN
