extends RefCounted
## The cans the story wants in Den Haag Centraal (logic; docs/CODE_LAGEN.md): which bins on
## the platforms they go in and which cans are still to be put. A mission may want an empty
## can in two bins behind the gates (Story.station_cans_wanted: the first mission's last
## two), in the order of KINDS; one the player took stays gone.
##   const CanRules = preload("res://scripts/world/station/station_can_rules.gd")

## The bins on the platforms (the prop in the GridMap Props).
const PLATFORM_BIN := "straat/prullenbak_paal"
const CAN_REACH := 1.3
const KINDS := ["perron_1", "perron_2"]
## How far apart (m) the two bins of the story's cans are at least when no other platform has one.
const CANS_APART := 12.0
## What the player gets and what the spot offers.
const CAN_ITEM := "blikje"
const ACTION_TEXT := "Blikje pakken"


## The bins for the story's cans out of the `bins` on the platforms (`platforms`: the
## platform each is on), up to two: the one nearest the middle of the gates, then the
## nearest on another platform, else the nearest at least CANS_APART m from the first.
static func story_bins(bins: Array, platforms: Array) -> Array:
	if bins.is_empty():
		return []
	var order := range(bins.size())
	order.sort_custom(func(first: int, second: int) -> bool:
		return _from_the_middle(bins[first]) < _from_the_middle(bins[second]))
	var first: int = order[0]
	for other: int in order:
		if platforms[other] != platforms[first]:
			return [bins[first], bins[other]]
	for other: int in order:
		if Vector2(bins[other].x - bins[first].x, bins[other].z - bins[first].z).length() >= CANS_APART:
			return [bins[first], bins[other]]
	return [bins[first]]


## The kinds of can to put now: the story wants `wanted` cans; `lying` are there already,
## `taken` the player has had, and there are `bin_count` bins (one per kind, in order).
static func kinds_to_put(wanted: int, lying: Array, taken: Array, bin_count: int) -> Array[String]:
	var to_put: Array[String] = []
	var left := wanted
	for index in KINDS.size():
		var kind: String = KINDS[index]
		if left <= 0:
			break
		if lying.has(kind):
			left -= 1
			continue
		if taken.has(kind) or index >= bin_count:
			continue
		to_put.append(kind)
		left -= 1
	return to_put


## The name of the spot of the can of `kind`.
static func spot_name(kind: String) -> String:
	return "BlikjeOpPerron" + kind.trim_prefix("perron")


static func _from_the_middle(at: Vector3) -> float:
	return Vector2(at.x, at.z).length()
