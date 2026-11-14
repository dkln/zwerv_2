extends RefCounted
## How busy the town is round the player, and with whom (data/drukte.json, see data/LEESMIJ.md):
## the pedestrians (Pedestrians, scripts/world/people/pedestrians.gd) and the traffic (Traffic,
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
##   weights; "" is nothing: CarriedItems, scripts/world/people/carried_items.gd, when it is there).
##   "pak": in a suit (CarriedItems.business_look when it is there).
## Without the file (or with parts missing) all is as busy as at 1.0 and everyone looks as
## TownsfolkFigure.look_for makes them.
## The sums over the table (shares, weights, draws) are crowd_rules.gd (logic;
## docs/CODE_LAGEN.md); this script reads the file once, looks up the hour and the
## neighbourhood in the scene, and dresses a kind in its colours.
##   var share := Crowd.pedestrian_share(13.5, "Centrum")

const CrowdRules = preload("res://scripts/world/people/crowd_rules.gd")
const DATA_FILE := "res://data/drukte.json"
const CARRIED_ITEMS_SCRIPT := "res://scripts/world/people/carried_items.gd"
## The hour when there is no day cycle (the tools, the tests).
const DEFAULT_HOUR := 13.0
## The neighbourhood when the scene has no "wijken" or the spot lies in none of them.
const DEFAULT_AREA := CrowdRules.DEFAULT_AREA
## Metres per map cell (the "wijken" table counts in cells).
const CELL_METRES := CrowdRules.CELL_METRES

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
	return CrowdRules.area_of(world.get_meta("wijken", []), spot)


## The share of Pedestrians.count out at `hour` in `area` (the hour's share times the area's
## factor).
static func pedestrian_share(hour: float, area: String) -> float:
	return CrowdRules.pedestrian_share(data(), hour, area)


## An area's evening, when `hour` is in it; else empty (CrowdRules.evening).
static func _evening(area: String, hour: float) -> Dictionary:
	return CrowdRules.evening(data(), area, hour)


## The same for Traffic.vehicle_count.
static func traffic_share(hour: float, area: String) -> float:
	return CrowdRules.traffic_share(data(), hour, area)


## How much comes and goes through Den Haag Centraal at `hour` (0..1, the hour's "station":
## the rush hours most; Pedestrians, people coming out of its doors and going in).
static func station_share(hour: float) -> float:
	return CrowdRules.station_share(data(), hour)


## Only the hour's share of the traffic (for the emergency services, everywhere the same).
static func traffic_hour_share(hour: float) -> float:
	return CrowdRules.traffic_hour_share(data(), hour)


## The weight of a kind of vehicle ("auto", "fiets", "brommer", "vracht", "bus", "landbouw",
## "klein") at `hour` in `area`: its base share times the hour's and the area's weight.
static func vehicle_weight(category: String, hour: float, area: String) -> float:
	return CrowdRules.vehicle_weight(data(), category, hour, area)


## How drunk someone of `kind` is at `hour` (0 sober .. 1 very; CrowdRules.drunkenness).
static func drunkenness(kind: String, hour: float, random: RandomNumberGenerator) -> float:
	return CrowdRules.drunkenness(kind, hour, random)


## A kind of person out at `hour` in `area`, drawn by their weights; "" when the table has none.
static func person_kind(hour: float, area: String, random: RandomNumberGenerator) -> String:
	return CrowdRules.person_kind(data(), hour, area, random)


## The kinds of people the table knows.
static func person_kinds() -> Array:
	return CrowdRules.person_kinds(data())


## The colours of a hat ("kapsels": "hoed"): black, brown, grey and navy felt, and a tweed.
const HAT_COLOURS := [Color("#1E1E22"), Color("#4E3A2A"), Color("#5A5E64"), Color("#22304A"), Color("#7A6A4E")]


## The look of someone of `kind` (TownsfolkFigure.look_for, then dressed as that kind).
static func look_for(kind: String, look_seed: int) -> Dictionary:
	var profile := CrowdRules.profile_of(data(), kind)
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
	random.seed = CrowdRules.dress_seed(look_seed)
	var style := CrowdRules.hair_style_for(profile, random)
	if style != "":
		look["hair_style"] = style
	var hair: Variant = _colour_from(profile, "haarkleuren", random)
	if hair != null:
		look["hair"] = hair
	if not suited:
		_dress_in(look, profile, random)
	look["skirt"] = CrowdRules.wears_skirt(profile, look.get("hair_style", ""), random)
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


## The coat (with its trim), the trousers and the shoes of a kind, each from its colours.
static func _dress_in(look: Dictionary, profile: Dictionary, random: RandomNumberGenerator) -> void:
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


## How much faster (> 1) or slower than the usual pace someone of `kind` goes.
static func pace_of(kind: String) -> float:
	return CrowdRules.pace_of(data(), kind)


## The share of the people of `kind` that ride `aid` ("rolstoel", "scootmobiel").
static func ride_share(kind: String, aid: String) -> float:
	return CrowdRules.ride_share(data(), kind, aid)


## Whether the next person of `kind` rides ("" on foot), with what each kind still owes in
## `debts` (CrowdRules.aid_owed).
static func aid_owed(kind: String, debts: Dictionary) -> String:
	return CrowdRules.aid_owed(data(), kind, debts)


## What someone of `kind` carries (a kind of CarriedItems, or "" for nothing), drawn by the
## weights of "dragen"; "" as well without CarriedItems.
static func carried_for(kind: String, random: RandomNumberGenerator) -> String:
	var carried := carried_items()
	if carried == null:
		return ""
	return CrowdRules.carried_for(data(), kind, carried.get_script_constant_map().get("KINDS", []), random)


## The script CarriedItems (scripts/world/people/carried_items.gd), or null while it is not there.
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
