extends RefCounted
## The rules of a branch of a supermarket (logic, docs/CODE_LAGEN.md): what the chain sells
## and at what price (ALFRED STEYHN's bonus off), which kinds of shelf have the bonus in
## this branch, how much goes in a trolley or a basket, what [E] says at the trolleys and
## at a shelf, the seeds of who works and shops there, and what going out with unpaid
## goods is. `chain`: the chain's entry of data/gesprekken/supermarkten.json ("ketens").
## The node: supermarket.gd; paying: supermarket_checkout_rules.gd; the floor:
## supermarket_floor_rules.gd; the shoppers: supermarket_shopper_rules.gd.
##   const SupermarketRules = preload("res://scripts/world/interiors/supermarket_rules.gd")

const RandomPick = preload("res://scripts/common/random_pick.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")

const CART := "karretje"
const BASKET := "mandje"
## How many things go in a trolley and in a basket when the chain does not say.
const CART_ROOM := 12
const BASKET_ROOM := 6
## The offence of going out with goods not paid for (uitzetten.json).
const THEFT := "winkeldiefstal"
## A branch whose way in gives no width has a front of this many cells.
const DEFAULT_WIDTH := 6


## What the chain `brand` says, sells and wears ("ketens" of supermarkten.json).
static func chain(data: Dictionary, brand: String) -> Dictionary:
	return ((data.get("ketens", {}) as Dictionary).get(brand, {}) as Dictionary)


## The seed of the people of a branch (who shops, what the till says) and of its bonus.
static func people_seed(brand: String, seed: int) -> int:
	return hash([brand, seed, "mensen"])


static func bonus_seed(brand: String, seed: int) -> int:
	return hash([brand, seed, "bonus"])


## The kinds of shelf with a bonus in the branch of `plan`: a few ("aantal") of the kinds
## it has a shelf and a product of, in an order drawn from `random`. None for a chain
## without a bonus.
static func bonus_categories(chain_data: Dictionary, plan: Dictionary, random: RandomNumberGenerator) -> Array[String]:
	var chosen: Array[String] = []
	var bonus: Dictionary = chain_data.get("bonus", {})
	if bonus.is_empty():
		return chosen
	var kinds: Array = []
	for shelf: Dictionary in plan.shelves:
		var category := String(shelf.category)
		if not kinds.has(category) and (chain_data.get("producten", {}) as Dictionary).has(category):
			kinds.append(category)
	RandomPick.shuffle(random, kinds)
	for index in mini(int(bonus.get("aantal", 2)), kinds.size()):
		chosen.append(String(kinds[index]))
	return chosen


## The texts of the signs (`sign_texts`: per kind of shelf) over the shelves with a bonus,
## as the keys of a Dictionary.
static func bonus_sign_texts(bonus: Array[String], sign_texts: Dictionary) -> Dictionary:
	var texts := {}
	for category in bonus:
		texts[String(sign_texts.get(category, ""))] = true
	return texts


## What stands on the bonus plate under a sign.
static func bonus_plate_text(chain_data: Dictionary) -> String:
	return String((chain_data.get("bonus", {}) as Dictionary).get("tekst", "BONUS"))


## What stands on the price board of a pallet: the price of the chain's "actie".
static func promotion_price_text(chain_data: Dictionary) -> String:
	var promotion: Dictionary = (chain_data.get("producten", {}) as Dictionary).get("actie", {})
	return MoneyText.euros(float(promotion.get("prijs", 0.99)))


## The product of a kind of shelf in the chain, with the branch's price (the bonus off when
## `bonus` has the kind): {"item", "price", "name", "category", "bonus"}; empty when the
## chain does not sell that kind.
static func product(chain_data: Dictionary, bonus: Array[String], category: String) -> Dictionary:
	var entry: Dictionary = (chain_data.get("producten", {}) as Dictionary).get(category, {})
	if entry.is_empty():
		return {}
	var price := float(entry.get("prijs", 1.0))
	if bonus.has(category):
		var off := float((chain_data.get("bonus", {}) as Dictionary).get("korting", 0.25))
		price = snappedf(price * (1.0 - off), 0.01)
	return {"item": String(entry.get("item", "")), "price": price, "name": String(entry.get("naam", "")),
		"category": category, "bonus": bonus.has(category)}


## How many things go in `carrier` ("karretje", "mandje"; "": nothing).
static func capacity(chain_data: Dictionary, carrier: String) -> int:
	if carrier == "":
		return 0
	return int(chain_data.get(carrier, CART_ROOM if carrier == CART else BASKET_ROOM))


## What [E] says at the trolleys or the baskets (`kind`), with `carrier` in hand.
static func carrier_text(carrier: String, kind: String) -> String:
	if carrier == kind:
		return "Karretje terugzetten" if kind == CART else "Mandje terugzetten"
	return "Karretje pakken" if kind == CART else "Mandje pakken"


## What [E] says at a shelf with `found` (product) on it.
static func shelf_text(found: Dictionary) -> String:
	return "Pakken: %s %s%s" % [found.name, "BONUS " if found.bonus else "", MoneyText.euros(found.price)]


## Why nothing more can be taken off a shelf with `carrier` holding `held` things of
## `room`: "" when one more fits.
static func no_room_text(carrier: String, held: int, room: int) -> String:
	if carrier == "":
		return "Pak eerst een karretje of mandje"
	if held >= room:
		return "Je karretje is vol" if carrier == CART else "Je mandje is vol"
	return ""


## What floats up when `found` goes in.
static func taken_text(found: Dictionary) -> String:
	return "+ " + String(found.name)


## The offence of going out of the door with `unpaid` things: "" with none.
static func leave_offence(unpaid: int) -> String:
	return THEFT if unpaid > 0 else ""


## The letters on the name plate of the one at the till.
static func emblem(brand: String) -> String:
	return "D" if brand == "derrek" else "AS"


## The role of who fills the shelves of the chain (personeel.json).
static func worker_role(brand: String) -> String:
	return "medewerker_" + brand


## The seeds of the looks: the one at checkout `number`, worker `index`, the shopper
## `index` that is in the shop already, and the first one to come in after them.
static func cashier_seed(seed: int, number: int) -> int:
	return seed * 5 + number * 11


static func worker_seed(seed: int, index: int) -> int:
	return seed * 13 + index * 17 + 2


static func shopper_seed(seed: int, index: int) -> int:
	return seed * 31 + index * 7 + 3


static func first_new_shopper_seed(seed: int) -> int:
	return seed * 31 + 101
