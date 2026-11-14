extends RefCounted
## The rules of the loose change on the streets (logic; docs/CODE_LAGEN.md; loose_change.gd):
## which coins there are and how often each comes, which of them is the big one, how a coin
## turns and bobs, and what rises from where it lay when it is picked up.
##   const LooseChangeRules = preload("res://scripts/world/things/loose_change_rules.gd")
##   LooseChangeRules.value_of(RandomPick.weighted(random, LooseChangeRules.VALUE_WEIGHTS))   # 0.5

const MoneyText = preload("res://scripts/common/money_text.gd")
## What the story unlocks before any coin lies on the streets.
const UNLOCK := "kleingeld"
## Values (euros) and how often each comes.
const VALUES := [0.1, 0.2, 0.5, 1.0]
const VALUE_WEIGHTS := [3.0, 3.0, 3.0, 1.0]
## From this value (euros) a coin is the big one.
const BIG_FROM := 1.0
## How fast a coin turns (radians a second), and how fast and how far it bobs (metres).
const TURN_SPEED := 2.4
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.05


## The value (euros) of the coin drawn as number `drawn` of VALUES (RandomPick.weighted over
## VALUE_WEIGHTS).
static func value_of(drawn: int) -> float:
	return VALUES[clampi(drawn, 0, VALUES.size() - 1)]


## Whether a coin of `value` euros is the big one (a euro).
static func is_big(value: float) -> bool:
	return value >= BIG_FROM


## How far (radians) a coin has turned after `clock` seconds; `phase` is its own start.
static func turn(clock: float, phase: float) -> float:
	return clock * TURN_SPEED + phase


## How far (metres) a coin stands above or below its place after `clock` seconds.
static func bob(clock: float, phase: float) -> float:
	return sin(clock * BOB_SPEED + phase) * BOB_HEIGHT


## What rises from a coin of `value` euros picked up: "+€ 0,50".
static func pickup_text(value: float) -> String:
	return "+" + MoneyText.euros(value)
