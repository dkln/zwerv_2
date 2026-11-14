extends RefCounted
## The rules of paying at a checkout of a supermarket (logic, docs/CODE_LAGEN.md): what it
## comes to, what goes back when the player has too little, what the one at the till (or
## the self-scan pillar) says. `lines`: the chain's "kassa" or "zelfscan" of
## data/gesprekken/supermarkten.json; a thing: {"item", "price", "name", "category"}.
## The node: supermarket.gd.
##   const SupermarketCheckoutRules = preload("res://scripts/world/interiors/supermarket_checkout_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")

## The choices under what it comes to; the second one puts everything back.
const CHOICES := ["Betalen", "Laat maar, ik leg het terug"]
const CHOICE_PUT_BACK := 1
## The till beeps at most this many things through, this long apart (s).
const MOST_BEEPS := 8
const BEEP_SECONDS := 0.32
## A cent of slack on what the player has.
const SLACK := 0.001
## The offence of paying with nothing at all (uitzetten.json).
const NO_MONEY := "geen_geld"


## What `things` come to (euros, to the cent).
static func total(things: Array) -> float:
	var sum := 0.0
	for thing: Dictionary in things:
		sum += float(thing.price)
	return snappedf(sum, 0.01)


## Which of the chain's lines are said at a checkout: the pillar's or the cashier's.
static func lines_of(chain_data: Dictionary, self_scan: bool) -> Dictionary:
	return chain_data.get("zelfscan" if self_scan else "kassa", {})


## How often the till beeps for `count` things of the player, and for a shopper with
## `goods` things.
static func beeps(count: int) -> int:
	return mini(count, MOST_BEEPS)


static func shopper_beeps(goods: int) -> int:
	return clampi(goods * 2, 2, MOST_BEEPS)


## What the till says `count` things come to, after `greeting` ("" for none).
static func total_text(lines: Dictionary, sum: float, count: int, greeting: String) -> String:
	var text := String(lines.get("totaal", "{prijs}")).replace("{prijs}", MoneyText.euros(sum)).replace("{aantal}", str(count))
	return text if greeting == "" else greeting + " " + text


## The greeting drawn from the lines' "begroetingen"; "" (and no draw) when there are none.
static func greeting(lines: Dictionary, random: RandomNumberGenerator) -> String:
	var greetings: Array = lines.get("begroetingen", [])
	if greetings.is_empty():
		return ""
	return String(greetings[random.randi() % greetings.size()])


## The thanks after paying: one of the lines' "betaald" (a draw when it is a list).
static func thanks(lines: Dictionary, random: RandomNumberGenerator) -> String:
	var said: Variant = lines.get("betaald", "Dank je wel!")
	return String(said[random.randi() % said.size()]) if said is Array else String(said)


## What the player with `money` can pay of `things`: the dearest go back until the rest is
## no more than they have. {"basket": the things paid for (dearest first), "put_back": the
## names of what goes back}.
static func affordable(things: Array[Dictionary], money: float) -> Dictionary:
	var basket: Array[Dictionary] = things.duplicate()
	basket.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.price) > float(second.price))
	var put_back: Array[String] = []
	while not basket.is_empty() and total(basket) > money + SLACK:
		put_back.append(String(basket.pop_front().name))
	return {"basket": basket, "put_back": put_back}


## The line `key` of the lines (`fallback` when missing) with {wat} the `names`, in a row.
static func listing_text(lines: Dictionary, key: String, names: Array[String]) -> String:
	return String(lines.get(key, "{wat}")).replace("{wat}", ", ".join(names))


## The plain line `key` of the lines.
static func line_text(lines: Dictionary, key: String, fallback: String) -> String:
	return String(lines.get(key, fallback))


## A page of what the till says, without a face: the narrator's way (the self-scan pillar,
## a till no one sits at) or, `spoken`, a conversation with the mood of `line_kind`.
static func page(lines: Dictionary, text: String, line_kind: String, spoken: bool) -> Dictionary:
	var made := {"kind": "gesprek" if spoken else "verhaal", "text": text, "speaker": String(lines.get("spreker", "KASSA"))}
	if spoken:
		made["mood"] = String((lines.get("stemmingen", {}) as Dictionary).get(line_kind, "neutraal"))
	return made
