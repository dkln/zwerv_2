extends RefCounted
## How busy the town is round the player, and with whom (data/drukte.json, see data/LEESMIJ.md):
## the pedestrians (Pedestrians, scripts/world/pedestrians.gd) and the traffic (Traffic,
## scripts/traffic/traffic.gd) ask it how many there should be and what kind.
## - "uren": moments of the day with the share of the pedestrians and of the traffic out then
##   (1 = Pedestrians.count, Traffic.vehicle_count), the weights of the kinds of people
##   ("mensen") and of the kinds of vehicles ("voertuigen"); between two moments they blend.
## - "gebieden": per neighbourhood (the names of the scene's "wijken" metadata, as the HUD
##   shows them) factors on top of that: busier or quieter ("voetgangers", "verkeer") and
##   other weights for people and vehicles (a kind not named there keeps its weight).
## - "voertuig_basis": the share of each kind of vehicle before the hour and the area.
## - "mensen": the kinds of people: the colours they wear (coats, trousers, shoes, hair),
##   their hair styles (weights), the chance of a skirt (with long hair), their pace, the
##   share that rides a wheelchair or a mobility scooter, and what they carry ("dragen",
##   weights; "" is nothing: CarriedItems, scripts/world/carried_items.gd, when it is there).
##   "pak": in a suit (CarriedItems.business_look when it is there).
## Without the file (or with parts missing) all is as busy as at 1.0 and everyone looks as
## TownsfolkFigure.look_for makes them.
##   var share := Crowd.pedestrian_share(13.5, "Centrum")

const DATA_FILE := "res://data/drukte.json"
const CARRIED_ITEMS_SCRIPT := "res://scripts/world/carried_items.gd"
## The hour when there is no day cycle (the tools, the tests).
const DEFAULT_HOUR := 13.0
## The neighbourhood when the scene has no "wijken" or the spot lies in none of them.
const DEFAULT_AREA := "Den Haag"
## Metres per map cell (the "wijken" table counts in cells).
const CELL_METRES := 4.0

static var _data := {}
static var _loaded := false
static var _carried: Script
static var _carried_looked := false


## The whole table (read once).
static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(DATA_FILE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
			if parsed is Dictionary:
				_data = parsed
			else:
				push_warning("crowd: %s is geen geldige JSON" % DATA_FILE)
	return _data


## Reads the file again (after a change, and for the tests).
static func reload() -> void:
	_loaded = false
	_data = {}


## The hour of the day of the scene `world` (its Dagcyclus), else DEFAULT_HOUR.
static func hour_of(world: Node) -> float:
	var day_cycle := world.get_node_or_null("Dagcyclus") if world else null
	if day_cycle and "time_of_day" in day_cycle:
		return float(day_cycle.time_of_day)
	return DEFAULT_HOUR


## The neighbourhood of `spot` (world metres) in the "wijken" metadata of `world`: the first
## that holds it (as the HUD finds it).
static func area_at(world: Node, spot: Vector3) -> String:
	if world == null:
		return DEFAULT_AREA
	var cell := Vector2(spot.x, spot.z) / CELL_METRES
	for area: Array in world.get_meta("wijken", []):
		if cell.x >= area[1] and cell.y >= area[2] and cell.x < area[3] + 1 and cell.y < area[4] + 1:
			return area[0]
	return DEFAULT_AREA


## The share of Pedestrians.count out at `hour` in `area` (the hour's share times the area's
## factor).
static func pedestrian_share(hour: float, area: String) -> float:
	return _hour_value(hour, "voetgangers") * float(_area(area).get("voetgangers", 1.0))


## The same for Traffic.vehicle_count.
static func traffic_share(hour: float, area: String) -> float:
	return _hour_value(hour, "verkeer") * float(_area(area).get("verkeer", 1.0))


## Only the hour's share of the traffic (for the emergency services, everywhere the same).
static func traffic_hour_share(hour: float) -> float:
	return _hour_value(hour, "verkeer")


## The weight of a kind of vehicle ("auto", "fiets", "brommer", "vracht", "bus", "landbouw",
## "klein") at `hour` in `area`: its base share times the hour's and the area's weight.
static func vehicle_weight(category: String, hour: float, area: String) -> float:
	var base: Dictionary = data().get("voertuig_basis", {})
	var weight := float(base.get(category, 1.0 if base.is_empty() else 0.0))
	weight *= float(_hour_weights(hour, "voertuigen").get(category, 1.0))
	weight *= float((_area(area).get("voertuigen", {}) as Dictionary).get(category, 1.0))
	return maxf(weight, 0.0)


## A kind of person out at `hour` in `area`, drawn by their weights; "" when the table has none.
static func person_kind(hour: float, area: String, random: RandomNumberGenerator) -> String:
	var weights := _hour_weights(hour, "mensen")
	var area_weights: Dictionary = _area(area).get("mensen", {})
	var total := 0.0
	var chosen := {}
	for kind: String in weights:
		var weight := maxf(float(weights[kind]) * float(area_weights.get(kind, 1.0)), 0.0)
		if weight > 0.0:
			chosen[kind] = weight
			total += weight
	return _draw(chosen, total, random)


## The kinds of people the table knows.
static func person_kinds() -> Array:
	return (data().get("mensen", {}) as Dictionary).keys()


## The colours of a hat ("kapsels": "hoed"): black, brown, grey and navy felt, and a tweed.
const HAT_COLOURS := [Color("#1E1E22"), Color("#4E3A2A"), Color("#5A5E64"), Color("#22304A"), Color("#7A6A4E")]


## The look of someone of `kind` (TownsfolkFigure.look_for, then dressed as that kind).
static func look_for(kind: String, look_seed: int) -> Dictionary:
	var profile := _person(kind)
	var carried := carried_items()
	var look: Dictionary
	var suited: bool = profile.get("pak", false) and carried != null and has_function(carried, "business_look")
	if suited:
		look = carried.call("business_look", look_seed)
	else:
		look = TownsfolkFigure.look_for(look_seed)
	if profile.is_empty():
		return look
	var random := RandomNumberGenerator.new()
	random.seed = look_seed * 31 + 17
	var styles: Dictionary = profile.get("kapsels", {})
	if not styles.is_empty():
		var total := 0.0
		for style: String in styles:
			total += maxf(float(styles[style]), 0.0)
		var style := _draw(styles, total, random)
		if style != "":
			look["hair_style"] = style
	var hair: Variant = _colour_from(profile, "haarkleuren", random)
	if hair != null:
		look["hair"] = hair
	if not suited:
		var coat: Variant = _colour_from(profile, "jassen", random)
		if coat != null:
			look["coat"] = coat
			look["trim"] = _trim_of(coat)
		var trousers: Variant = _colour_from(profile, "broeken", random)
		if trousers != null:
			look["trousers"] = trousers
		var shoes: Variant = _colour_from(profile, "schoenen", random)
		if shoes != null:
			look["shoes"] = shoes
	look["skirt"] = look.get("hair_style", "") == "lang" and random.randf() < float(profile.get("rok", 0.3))
	# a uniform (police, handhaving): those colours, whatever was drawn
	var uniform: Dictionary = profile.get("uniform", {})
	for key: String in uniform:
		look[key] = Color(str(uniform[key]))
	if look.get("hair_style", "") == "pet":
		var cap: Variant = _colour_from(profile, "jassen", random)
		if cap != null:
			look["cap"] = cap
	elif look.get("hair_style", "") == "hoed":
		# hats are dark felt or tweed, whatever the coat
		look["cap"] = HAT_COLOURS[random.randi() % HAT_COLOURS.size()]
	return look


## How much faster (> 1) or slower than the usual pace someone of `kind` goes.
static func pace_of(kind: String) -> float:
	return float(_person(kind).get("tempo", 1.0))


## The share of the people of `kind` that ride `aid` ("rolstoel", "scootmobiel").
static func ride_share(kind: String, aid: String) -> float:
	return clampf(float(_person(kind).get(aid, 0.0)), 0.0, 1.0)


## What someone of `kind` carries (a kind of CarriedItems, or "" for nothing), drawn by the
## weights of "dragen"; "" as well without CarriedItems.
static func carried_for(kind: String, random: RandomNumberGenerator) -> String:
	var carried := carried_items()
	if carried == null:
		return ""
	var weights: Dictionary = _person(kind).get("dragen", {})
	var known: Array = carried.get_script_constant_map().get("KINDS", [])
	var usable := {}
	var total := 0.0
	for item: String in weights:
		if item == "" or known.is_empty() or known.has(item):
			usable[item] = maxf(float(weights[item]), 0.0)
			total += usable[item]
	return _draw(usable, total, random)


## The script CarriedItems (scripts/world/carried_items.gd), or null while it is not there.
static func carried_items() -> Script:
	if not _carried_looked:
		_carried_looked = true
		if ResourceLoader.exists(CARRIED_ITEMS_SCRIPT):
			_carried = load(CARRIED_ITEMS_SCRIPT) as Script
	return _carried


## True if `script` has a function `function_name` (its static ones too).
static func has_function(script: Script, function_name: String) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if method.name == function_name:
			return true
	return false


# ------------------------------------------------------------------ the table

static func _area(area: String) -> Dictionary:
	return (data().get("gebieden", {}) as Dictionary).get(area, {})


static func _person(kind: String) -> Dictionary:
	return (data().get("mensen", {}) as Dictionary).get(kind, {})


## The two moments of "uren" round `hour` and how far it is from the first to the second
## (0..1), round midnight too: [first, second, fraction]; empty without moments.
static func _moments_round(hour: float) -> Array:
	var moments: Array = data().get("uren", [])
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


static func _hour_value(hour: float, field: String) -> float:
	var round_hour := _moments_round(hour)
	if round_hour.is_empty():
		return 1.0
	return lerpf(float(round_hour[0].get(field, 1.0)), float(round_hour[1].get(field, 1.0)), round_hour[2])


static func _hour_weights(hour: float, field: String) -> Dictionary:
	var round_hour := _moments_round(hour)
	if round_hour.is_empty():
		return {}
	var first: Dictionary = round_hour[0].get(field, {})
	var second: Dictionary = round_hour[1].get(field, {})
	var blended := {}
	for kind: String in first.keys() + second.keys():
		blended[kind] = lerpf(float(first.get(kind, 0.0)), float(second.get(kind, 0.0)), round_hour[2])
	return blended


## One key of `weights` drawn by its weight (`total`: their sum); "" when there is none.
static func _draw(weights: Dictionary, total: float, random: RandomNumberGenerator) -> String:
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


static func _colour_from(profile: Dictionary, field: String, random: RandomNumberGenerator) -> Variant:
	var colours: Array = profile.get(field, [])
	if colours.is_empty():
		return null
	return Color(String(colours[random.randi() % colours.size()]))


## The darker colour of a coat's collar and cuffs: the one TownsfolkFigure pairs with it, else
## the coat a shade darker.
static func _trim_of(coat: Color) -> Color:
	for pair: Array in TownsfolkFigure.COATS:
		if (pair[0] as Color).is_equal_approx(coat):
			return pair[1]
	return coat.darkened(0.35)
