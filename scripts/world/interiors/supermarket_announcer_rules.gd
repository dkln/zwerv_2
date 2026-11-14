extends RefCounted
## What the loudspeakers of a supermarket say and when (logic, docs/CODE_LAGEN.md): an offer
## (a product of a shelf of the branch at the branch's price; ALFRED STEYHN's bonus in its
## own words) or a notice (data/gesprekken/omroep_supermarkt.json: `data` below), never the
## same twice in a row, and how long until the next one. Every draw comes from the
## generator handed in, so a seed gives the same announcements. The node:
## supermarket_announcer.gd.
##   const SupermarketAnnouncerRules = preload("res://scripts/world/interiors/supermarket_announcer_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")
const MUSIC_FOLDER := "res://assets/audio/muziek/"
const JINGLE_PREFIX := "jingle_"
## The aisles a notice can name ({gang}).
const AISLES := 6
## How often an announcement is tried again for one that differs from the last.
const ATTEMPTS := 4
## The seconds until the first announcement and between two, when the data has none.
const FIRST_SECONDS := Vector2(12.0, 30.0)
const BETWEEN_SECONDS := Vector2(45.0, 100.0)
const DEFAULT_VOICE := "vrouw"


## What the chain `brand` says ("ketens" of the data); empty for a chain it does not know.
static func chain_lines(data: Dictionary, brand: String) -> Dictionary:
	return ((data.get("ketens", {}) as Dictionary).get(brand, {}) as Dictionary)


## The voice of the chain's announcer.
static func voice(lines: Dictionary) -> String:
	return String(lines.get("stem", DEFAULT_VOICE))


## The file of the jingle of the chain `brand`.
static func jingle_path(brand: String) -> String:
	return MUSIC_FOLDER + JINGLE_PREFIX + brand + ".ogg"


## The seconds drawn from the span `key` of the data ([fewest, most]), else from `fallback`.
static func seconds_between(data: Dictionary, key: String, fallback: Vector2, random: RandomNumberGenerator) -> float:
	var span: Variant = data.get(key, [])
	if span is Array and (span as Array).size() == 2:
		return random.randf_range(float(span[0]), float(span[1]))
	return random.randf_range(fallback.x, fallback.y)


## The kinds of shelf of the branch's plan, each once, in the order of its shelves.
static func shelf_categories(plan: Dictionary) -> Array[String]:
	var categories: Array[String] = []
	for shelf: Dictionary in plan.get("shelves", []):
		var category := String(shelf.get("category", ""))
		if category != "" and not categories.has(category):
			categories.append(category)
	return categories


## An offer or a notice that differs from `last_text`, tried ATTEMPTS times; "" when none
## came up (the node then says a notice, whatever the last one was). `products`: per kind
## of shelf of the plan the branch's product ({"name", "price", "bonus"}).
static func fresh_text(data: Dictionary, brand: String, plan: Dictionary, products: Dictionary, last_text: String,
		random: RandomNumberGenerator) -> String:
	for _attempt in ATTEMPTS:
		var text := offer(data, brand, plan, products, random) if random.randf() < float(data.get("aanbieding_kans", 0.5)) \
			else notice(data, brand, plan, random)
		if text != "" and text != last_text:
			return text
	return ""


## A product of one of the branch's shelves, at the branch's price; "" when there is none
## to offer.
static func offer(data: Dictionary, brand: String, plan: Dictionary, products: Dictionary, random: RandomNumberGenerator) -> String:
	var categories := shelf_categories(plan)
	if categories.is_empty():
		return ""
	var product: Dictionary = products.get(categories[random.randi() % categories.size()], {})
	if product.is_empty() or String(product.get("name", "")) == "":
		return ""
	var lines := chain_lines(data, brand)
	var templates: Array = lines.get("bonus", []) if bool(product.get("bonus", false)) and not (lines.get("bonus", []) as Array).is_empty() \
		else lines.get("aanbieding", [])
	if templates.is_empty():
		return ""
	return String(templates[random.randi() % templates.size()]).format({
		"naam": String(product["name"]), "prijs": MoneyText.amount(float(product["price"]))})


## A notice of every supermarket or of the chain, with a checkout of the branch and an
## aisle; "" when there are none.
static func notice(data: Dictionary, brand: String, plan: Dictionary, random: RandomNumberGenerator) -> String:
	var notices: Array = (data.get("mededelingen", []) as Array) + (chain_lines(data, brand).get("mededelingen", []) as Array)
	if notices.is_empty():
		return ""
	var checkouts: Array = plan.get("checkouts", [])
	var checkout_number := 1
	if not checkouts.is_empty():
		checkout_number = int((checkouts[random.randi() % checkouts.size()] as Dictionary).get("number", 1))
	return String(notices[random.randi() % notices.size()]).format({
		"kassa": str(checkout_number), "gang": str(random.randi_range(1, AISLES))})
