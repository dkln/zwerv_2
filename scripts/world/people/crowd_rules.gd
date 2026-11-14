extends RefCounted
## How busy the town is and with whom, worked out over the table of data/drukte.json
## (logic; docs/CODE_LAGEN.md): the share of the pedestrians and the traffic at an hour in a
## neighbourhood, the kind of person drawn by the weights, how drunk the night's crowd is,
## the pace of a kind, the share that rides, what a kind carries. Every function gets the
## `table` (the parsed file, Crowd.data()); without one (or with parts missing) all is as
## busy as at 1.0. The script that reads the file and dresses the kinds: crowd.gd.
##   const CrowdRules = preload("res://scripts/world/people/crowd_rules.gd")

## The neighbourhood when the scene has no "wijken" or the spot lies in none of them.
const DEFAULT_AREA := "Den Haag"
## Metres per map cell (the "wijken" table counts in cells).
const CELL_METRES := 4.0
## An area's evening when it names no hours: from, to (may run past midnight).
const EVENING_FROM := 20.0
const EVENING_TO := 4.0
## The night's crowd: from when (and till when in the morning) who may be drunk, the chance
## of it and how drunk (least, most), per kind of person.
const DRUNK_TILL := 6.0
const DRUNK_KINDS := {
	"nachtbraker": {"from": 22.0, "chance": 0.75, "least": 0.45, "most": 1.0},
	"uitgaanspubliek": {"from": 23.0, "chance": 0.35, "least": 0.35, "most": 0.85},
}
## The chance of a skirt (with long hair) of a kind that names none.
const SKIRT_CHANCE := 0.3
## What people ride (the fields of a kind with the share that does).
const AIDS: Array[String] = ["rolstoel", "scootmobiel"]


## The neighbourhood of `spot` (world metres) in `areas` (the "wijken" metadata of the
## scene: [name, x0, z0, x1, z1] in cells): the first that holds it (as the HUD finds it).
static func area_of(areas: Array, spot: Vector3) -> String:
	var cell := Vector2(spot.x, spot.z) / CELL_METRES
	for area: Array in areas:
		if cell.x >= area[1] and cell.y >= area[2] and cell.x < area[3] + 1 and cell.y < area[4] + 1:
			return area[0]
	return DEFAULT_AREA


## The share of Pedestrians.count out at `hour` in `area` (the hour's share times the area's
## factor and that of its evening).
static func pedestrian_share(table: Dictionary, hour: float, area: String) -> float:
	return hour_value(table, hour, "voetgangers") * float(area_of_table(table, area).get("voetgangers", 1.0)) \
		* float(evening(table, area, hour).get("voetgangers", 1.0))


## An area's evening ("avond": {"van", "tot" (hours, may run past midnight), "voetgangers",
## "mensen"}: the Plein and the Grote Markt fill up with the night's crowd), when `hour` is in
## it; else empty.
static func evening(table: Dictionary, area: String, hour: float) -> Dictionary:
	var area_evening: Dictionary = area_of_table(table, area).get("avond", {})
	if area_evening.is_empty():
		return {}
	var from := float(area_evening.get("van", EVENING_FROM))
	var to := float(area_evening.get("tot", EVENING_TO))
	return area_evening if is_between_hours(hour, from, to) else {}


## True if `hour` lies from `from` up to `to`, which may run past midnight (from 20 to 4).
static func is_between_hours(hour: float, from: float, to: float) -> bool:
	return (hour >= from and hour < to) if from < to else (hour >= from or hour < to)


## The same as pedestrian_share for Traffic.vehicle_count.
static func traffic_share(table: Dictionary, hour: float, area: String) -> float:
	return hour_value(table, hour, "verkeer") * float(area_of_table(table, area).get("verkeer", 1.0))


## How much comes and goes through Den Haag Centraal at `hour` (0..1, the hour's "station").
static func station_share(table: Dictionary, hour: float) -> float:
	return hour_value(table, hour, "station")


## Only the hour's share of the traffic (for the emergency services, everywhere the same).
static func traffic_hour_share(table: Dictionary, hour: float) -> float:
	return hour_value(table, hour, "verkeer")


## The weight of a kind of vehicle at `hour` in `area`: its base share times the hour's and
## the area's weight.
static func vehicle_weight(table: Dictionary, category: String, hour: float, area: String) -> float:
	var base: Dictionary = table.get("voertuig_basis", {})
	var weight := float(base.get(category, 1.0 if base.is_empty() else 0.0))
	weight *= float(hour_weights(table, hour, "voertuigen").get(category, 1.0))
	weight *= float((area_of_table(table, area).get("voertuigen", {}) as Dictionary).get(category, 1.0))
	return maxf(weight, 0.0)


## How drunk someone of `kind` is at `hour` (0 sober .. 1 very): the night revellers from ten
## at night to six in the morning (most of them), the people going out after eleven (some);
## nobody else, nobody in the daytime. Draws from `random` only for a kind out at its hours.
static func drunkenness(kind: String, hour: float, random: RandomNumberGenerator) -> float:
	if not DRUNK_KINDS.has(kind):
		return 0.0
	var night: Dictionary = DRUNK_KINDS[kind]
	if not is_between_hours(hour, float(night.from), DRUNK_TILL):
		return 0.0
	if random.randf() < float(night.chance):
		return random.randf_range(float(night.least), float(night.most))
	return 0.0


## The weights of the kinds of people out at `hour` in `area` (only those above 0): the
## hour's times the area's and its evening's.
static func person_weights(table: Dictionary, hour: float, area: String) -> Dictionary:
	var weights := hour_weights(table, hour, "mensen")
	var area_weights: Dictionary = area_of_table(table, area).get("mensen", {})
	var evening_weights: Dictionary = evening(table, area, hour).get("mensen", {})
	var chosen := {}
	for kind: String in weights:
		var weight := maxf(float(weights[kind]) * float(area_weights.get(kind, 1.0)) * float(evening_weights.get(kind, 1.0)), 0.0)
		if weight > 0.0:
			chosen[kind] = weight
	return chosen


## A kind of person out at `hour` in `area`, drawn by their weights; "" when the table has
## none (then nothing is drawn from `random`).
static func person_kind(table: Dictionary, hour: float, area: String, random: RandomNumberGenerator) -> String:
	var chosen := person_weights(table, hour, area)
	return draw(chosen, total_of(chosen), random)


## The kinds of people the table knows.
static func person_kinds(table: Dictionary) -> Array:
	return (table.get("mensen", {}) as Dictionary).keys()


## What the table says of a kind of person ("mensen"); empty for one it does not know.
static func profile_of(table: Dictionary, kind: String) -> Dictionary:
	return (table.get("mensen", {}) as Dictionary).get(kind, {})


## What the table says of a neighbourhood ("gebieden"); empty for one it does not know.
static func area_of_table(table: Dictionary, area: String) -> Dictionary:
	return (table.get("gebieden", {}) as Dictionary).get(area, {})


## How much faster (> 1) or slower than the usual pace someone of `kind` goes.
static func pace_of(table: Dictionary, kind: String) -> float:
	return float(profile_of(table, kind).get("tempo", 1.0))


## The share of the people of `kind` that ride `aid` ("rolstoel", "scootmobiel").
static func ride_share(table: Dictionary, kind: String, aid: String) -> float:
	return clampf(float(profile_of(table, kind).get(aid, 0.0)), 0.0, 1.0)


## Whether the next person of `kind` rides, with what each kind still owes (`debts`:
## "kind/aid" -> the share of a rider owed, changed here): each kind owes its share of
## riders and pays one out once it owes a whole one, so the shares come out even, not by
## luck. The aid, or "" on foot.
static func aid_owed(table: Dictionary, kind: String, debts: Dictionary) -> String:
	for aid: String in AIDS:
		var debt_key := kind + "/" + aid
		var debt := float(debts.get(debt_key, 0.0)) + ride_share(table, kind, aid)
		if debt >= 1.0:
			debts[debt_key] = debt - 1.0
			return aid
		debts[debt_key] = debt
	return ""


## The things a kind may carry with their weights ("dragen"), only those of `known` (the
## kinds of CarriedItems; empty: all) and "" (nothing).
static func carried_weights(table: Dictionary, kind: String, known: Array) -> Dictionary:
	var weights: Dictionary = profile_of(table, kind).get("dragen", {})
	var usable := {}
	for item: String in weights:
		if item == "" or known.is_empty() or known.has(item):
			usable[item] = maxf(float(weights[item]), 0.0)
	return usable


## What someone of `kind` carries (one of `known`, or "" for nothing), drawn by the weights
## of "dragen".
static func carried_for(table: Dictionary, kind: String, known: Array, random: RandomNumberGenerator) -> String:
	var usable := carried_weights(table, kind, known)
	return draw(usable, total_of(usable), random)


## The hair style of a kind ("kapsels", weights) drawn by its weight; "" when it names none
## (then nothing is drawn).
static func hair_style_for(profile: Dictionary, random: RandomNumberGenerator) -> String:
	var styles: Dictionary = profile.get("kapsels", {})
	if styles.is_empty():
		return ""
	var total := 0.0
	for style: String in styles:
		total += maxf(float(styles[style]), 0.0)
	return draw(styles, total, random)


## True if someone of this kind with that hair wears a skirt (long hair only; one draw).
static func wears_skirt(profile: Dictionary, hair_style: String, random: RandomNumberGenerator) -> bool:
	return hair_style == "lang" and random.randf() < float(profile.get("rok", SKIRT_CHANCE))


## The seed of the draws that dress a kind, from the seed of the look.
static func dress_seed(look_seed: int) -> int:
	return look_seed * 31 + 17


## The two moments of "uren" round `hour` and how far it is from the first to the second
## (0..1), round midnight too: [first, second, fraction]; empty without moments.
static func moments_round(table: Dictionary, hour: float) -> Array:
	var moments: Array = table.get("uren", [])
	if moments.is_empty():
		return []
	var at := fposmod(hour, 24.0)
	var before: Dictionary = moments[-1]
	var after: Dictionary = moments[0]
	for moment: Dictionary in moments:
		if float(moment.get("uur", 0.0)) <= at:
			before = moment
		else:
			after = moment
			break
	var start := float(before.get("uur", 0.0))
	var end := float(after.get("uur", 0.0))
	if end <= start:
		end += 24.0
	var from_start := at - start if at >= start else at + 24.0 - start
	var fraction := clampf(from_start / maxf(end - start, 0.001), 0.0, 1.0)
	return [before, after, fraction]


## A number of the hour (`field` of "uren"), blended between the two moments round it; 1
## without moments.
static func hour_value(table: Dictionary, hour: float, field: String) -> float:
	var round_hour := moments_round(table, hour)
	if round_hour.is_empty():
		return 1.0
	return lerpf(float(round_hour[0].get(field, 1.0)), float(round_hour[1].get(field, 1.0)), round_hour[2])


## The weights of the hour (`field` of "uren": "mensen", "voertuigen"), blended likewise.
static func hour_weights(table: Dictionary, hour: float, field: String) -> Dictionary:
	var round_hour := moments_round(table, hour)
	if round_hour.is_empty():
		return {}
	var first: Dictionary = round_hour[0].get(field, {})
	var second: Dictionary = round_hour[1].get(field, {})
	var blended := {}
	for kind: String in first.keys() + second.keys():
		blended[kind] = lerpf(float(first.get(kind, 0.0)), float(second.get(kind, 0.0)), round_hour[2])
	return blended


## The sum of the weights.
static func total_of(weights: Dictionary) -> float:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	return total


## One key of `weights` drawn by its weight (`total`: their sum); "" when there is none
## (nothing is drawn then).
static func draw(weights: Dictionary, total: float, random: RandomNumberGenerator) -> String:
	if total <= 0.0:
		return ""
	var roll := random.randf() * total
	var last := ""
	for key: String in weights:
		last = key
		roll -= float(weights[key])
		if roll < 0.0:
			return key
	return last
