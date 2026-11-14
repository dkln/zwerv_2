extends RefCounted
## The rules of the cans in the waste bins (logic; docs/CODE_LAGEN.md; litter_bins.gd):
## which props are bins, how many get a can at the start, which empty bins may get a new
## one, which bins the story fills by the start and which it empties, and the points looked
## at between a bin and a place to see whether a building stands between them. A bin here is
## the Dictionary litter_bins.gd keeps: {"ground": Vector3, "top": Vector3, "spot": Node3D
## or null, "free": bool}; the rules read "ground", "free" and whether "spot" is null.
##   const LitterBinsRules = preload("res://scripts/world/things/litter_bins_rules.gd")

const BIN_TILES := ["straat/prullenbak_paal", "straat/prullenbak_rond"]
const CAN_ITEM := "blikje"
## What "[E]" says at a bin with a can.
const TAKE_TEXT := "Blikje pakken"
## A railway platform (behind the OV gates); a tram stop (tram/tram_halte_perron) is free.
const PLATFORM_GROUND := "spoor/perron"
## The levels of the ground layer looked at under a bin for a platform (from, up to).
const PLATFORM_LEVELS := Vector2i(-2, 8)


## How many bins get a can at the start: `can_share` of them, at most `most_cans`.
static func cans_at_start(bin_count: int, can_share: float, most_cans: int) -> int:
	return mini(most_cans, roundi(bin_count * can_share))


## Whether the ground tile `tile_name` is a railway platform (behind the gates).
static func is_platform(tile_name: String) -> bool:
	return tile_name.contains(PLATFORM_GROUND)


## The name of the spot of the can in bin `index`.
static func spot_name(index: int) -> String:
	return "Blikje%d" % (index + 1)


## Where a bin stands on the map (world x, z).
static func place_of(bin: Dictionary) -> Vector2:
	var at: Vector3 = bin.ground
	return Vector2(at.x, at.z)


## Whether it is time for a new can: `clock` seconds since the last, one every
## `refill_seconds`.
static func refill_due(clock: float, refill_seconds: float) -> bool:
	return clock >= refill_seconds


## The bins (their numbers) that may get a new can: empty, and more than `keep_radius` m
## from `keep_round` (world x, z).
static func refillable(bins: Array[Dictionary], keep_round: Vector2, keep_radius: float) -> Array:
	var empty: Array = []
	for index in bins.size():
		if bins[index].spot == null and place_of(bins[index]).distance_to(keep_round) > keep_radius:
			empty.append(index)
	return empty


## How many bins have a can.
static func cans_in(bins: Array[Dictionary]) -> int:
	var count := 0
	for bin: Dictionary in bins:
		if bin.spot != null:
			count += 1
	return count


## The freely reachable bins with a can nearest to `near` (world x, z), `count` of them:
## where they stand (world x, z).
static func can_spots(bins: Array[Dictionary], near: Vector2, count: int) -> Array:
	var spots: Array = []
	for bin: Dictionary in bins:
		if bin.spot != null and bin.free:   # not on a platform behind the gates
			spots.append(place_of(bin))
	spots.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.distance_to(near) < second.distance_to(near))
	return spots.slice(0, count)


## The freely reachable bins (their numbers) for which `in_sight` holds (a Callable taking
## the place of a bin, world x, z; invalid: all of them), the nearest to `near` first.
static func nearest_free(bins: Array[Dictionary], near: Vector2, in_sight := Callable()) -> Array:
	var order: Array = range(bins.size()).filter(func(index: int) -> bool: return bins[index].free)
	if in_sight.is_valid():
		order = order.filter(func(index: int) -> bool: return in_sight.call(place_of(bins[index])))
	order.sort_custom(func(first: int, second: int) -> bool:
		return place_of(bins[first]).distance_to(near) < place_of(bins[second]).distance_to(near))
	return order


## How far (metres) the farthest of the bins `chosen` (their numbers) is from `near`.
static func farthest(bins: Array[Dictionary], chosen: Array, near: Vector2) -> float:
	var distance := 0.0
	for index: int in chosen:
		distance = maxf(distance, place_of(bins[index]).distance_to(near))
	return distance


## The bins (their numbers) with a can within `alone_within` m of `near` that are not among
## `chosen`: the ones the story empties.
static func others_with_a_can(bins: Array[Dictionary], chosen: Array, near: Vector2, alone_within: float) -> Array:
	var others: Array = []
	for index in bins.size():
		if bins[index].spot != null and not chosen.has(index) and place_of(bins[index]).distance_to(near) <= alone_within:
			others.append(index)
	return others


## The points (world x, z) looked at on the straight line from `from` to `to`, one every
## metre, the ends not among them.
static func sight_points(from: Vector2, to: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var steps := maxi(ceili(from.distance_to(to)), 1)
	for step in range(1, steps):
		points.append(from.lerp(to, float(step) / steps))
	return points
