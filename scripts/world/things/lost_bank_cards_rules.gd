extends RefCounted
## The rules of the lost bank cards on the streets (logic; docs/CODE_LAGEN.md;
## lost_bank_cards.gd): their own lots, how far from the start and from each other they
## lie, how a card turns, and what the reward screen says when one is found.
##   const LostBankCardsRules = preload("res://scripts/world/things/lost_bank_cards_rules.gd")

## What the story unlocks before any card lies on the streets.
const UNLOCK := "pinpassen"
## Their own lots, not those of the coins.
const CARD_SEED := 97
## How far from the start the nearest card may lie, and how far off the middle of its cell
## a card lies (metres).
const CLOSEST := 12.0
const SCATTER := 1.2
## The cards lie this share of `reach` apart.
const APART_SHARE := 1.0 / 3.0
## How fast a card turns (radians a second).
const TURN_SPEED := 1.1


## How far apart (metres) the cards lie in a town searched up to `reach` metres.
static func apart(reach: float) -> float:
	return reach * APART_SHARE


## How far (radians) a card has turned after `clock` seconds; `phase` is its own start.
static func turn(clock: float, phase: float) -> float:
	return clock * TURN_SPEED + phase


## What the reward screen shows for a card found on the street (GameHud.show_reward);
## `item_id` is the bank card among the items.
static func found_reward(item_id: String) -> Dictionary:
	return {"heading": "GEVONDEN", "title": "Op straat", "items": [{"item": item_id, "count": 1}]}
