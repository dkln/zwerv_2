extends RefCounted
## The rules of the player's pockets and money (logic; docs/CODE_LAGEN.md): how many kinds of
## item fit, whether there is room, what it wears, what it eats first, whether it can pay,
## and how getting something is written. The items themselves: items.gd. The behaviour is
## player_controller.gd (add_item, buy, add_money, eat_something). An inventory is a
## Dictionary item id -> how many.
##   const PlayerInventoryRules = preload("res://scripts/player/player_inventory_rules.gd")

const Items = preload("res://scripts/player/items.gd")
## The kinds of item F eats or drinks (eat_something), and how much rather food than a drink.
const FOOD := "eten"
const DRINK := "drinken"
const FOOD_FIRST := 100.0
## Paying is not refused over less than this (rounding of cents).
const PRICE_SLACK := 0.001
## What rises over the figure when there is no room.
const FULL_TEXT := "Zakken vol"
## What buying comes to (PlayerController.buy).
const BOUGHT := "ok"
const NO_MONEY := "geld"
const NO_ROOM := "vol"


## Whether something warm is worn (an item "worn" in the pockets: Items.is_worn).
static func wears_something(inventory: Dictionary) -> bool:
	for item_id: String in inventory:
		if Items.is_worn(item_id):
			return true
	return false


## How many kinds of item fit: the pockets, and more with a coat on (its pockets).
static func slots(inventory: Dictionary) -> int:
	return Items.BASE_SLOTS + (Items.COAT_SLOTS if wears_something(inventory) else 0)


## The slots taken: the kinds of item in the pockets that take one (Items.takes_slot).
static func slots_used(inventory: Dictionary) -> int:
	var used := 0
	for item_id: String in inventory:
		if Items.takes_slot(item_id):
			used += 1
	return used


## True if there is room for one more of `item_id`: it has some already, it takes no slot,
## or a slot is free.
static func has_room_for(inventory: Dictionary, item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0 or not Items.takes_slot(item_id) or slots_used(inventory) < slots(inventory)


## The inventory with `count` more of `item_id` (a new Dictionary).
static func with_added(inventory: Dictionary, item_id: String, count: int) -> Dictionary:
	var after := inventory.duplicate()
	after[item_id] = int(after.get(item_id, 0)) + count
	return after


## The inventory with one less of `item_id` (a new Dictionary); the last one gone, its slot is free.
static func with_one_less(inventory: Dictionary, item_id: String) -> Dictionary:
	var after := inventory.duplicate()
	if not after.has(item_id):
		return after
	after[item_id] = int(after[item_id]) - 1
	if after[item_id] <= 0:
		after.erase(item_id)
	return after


## Whether one of `item_id` can be used now: there is one and it is something to use.
static func can_use(inventory: Dictionary, item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0 and Items.can_use(item_id)


## What F eats or drinks: the food that fills the stomach most, or else a drink; "" when
## there is nothing.
static func best_food(inventory: Dictionary) -> String:
	var best := ""
	var best_score := 0.0
	for item_id: String in inventory:
		if not Items.can_use(item_id):
			continue
		var kind := String(Items.item(item_id).get("kind", ""))
		if kind != FOOD and kind != DRINK:
			continue
		var score := float(Items.item(item_id).effect.get("honger", 0.0)) + (FOOD_FIRST if kind == FOOD else 0.0)
		if best == "" or score > best_score:
			best = item_id
			best_score = score
	return best


## Getting something as it rises over the figure: "+ Kroket", "+ 3 x Blikje".
static func got_text(item_id: String, count: int) -> String:
	var item_name := String(Items.item(item_id).get("name", item_id))
	return "+ %s" % item_name if count == 1 else "+ %d x %s" % [count, item_name]


## Whether `money` euros pay a `price`.
static func can_pay(money: float, price: float) -> bool:
	return not money + PRICE_SLACK < price


## The money after `euros` came in (or went out, negative): never below nothing.
static func money_after(money: float, euros: float) -> float:
	return maxf(money + euros, 0.0)


## What counts as earned of `euros`: only what comes in, and only when `earned`.
static func earned_of(euros: float, earned: bool) -> float:
	return euros if euros > 0.0 and earned else 0.0
