extends RefCounted
## The logic of the level-up screen (the rules layer of scripts/ui/level_up_screen.gd, which
## is the behaviour; level_up_screen_layout.gd has the sizes, level_up_screen_view.gd builds
## and shows it): the stats you can raise, which one the arrows go to, from when a key takes
## one, and how the level, the XP and a stat's maximum read. Plain functions, without nodes.
##   const LevelUpScreenRules = preload("res://scripts/ui/screens/level_up_screen_rules.gd")

## Seconds before a key counts (a key still held from the game must not pick at once).
const KEYS_AFTER := 0.5
## The stats you can raise, in this order: the stat (PlayerController.STAT_NAMES), how it is
## called here and what it does for you. How much: PlayerController.LEVEL_UP_RAISE.
const OPTIONS := [
	{"stat": "gezondheid", "name": "GEZONDHEID", "text": "Je kunt meer hebben."},
	{"stat": "uithoudingsvermogen", "name": "UITHOUDINGSVERMOGEN", "text": "Je kunt langer rennen."},
	{"stat": "honger", "name": "GROTERE MAAG", "text": "Je houdt het langer uit zonder eten."},
	{"stat": "overprikkeldheid", "name": "INCASSERINGSVERMOGEN", "text": "Je kunt meer prikkels aan."},
]


## The stat of option `index` ("" when there is no such option).
static func stat_at(index: int) -> String:
	return String(OPTIONS[index].stat) if index >= 0 and index < OPTIONS.size() else ""


## The option `step` (1: down, -1: up) from `index`, round at the ends.
static func next_index(index: int, step: int) -> int:
	return posmod(index + step, OPTIONS.size())


## Whether a key that takes a stat counts yet, `since` seconds after the screen opened.
static func keys_work(since: float) -> bool:
	return since >= KEYS_AFTER


## How the new level reads ("LEVEL 3").
static func level_text(level: int) -> String:
	return "LEVEL %d" % level


## How the XP that did it reads ("+150 XP").
static func xp_text(xp_gained: int) -> String:
	return "+%d XP" % xp_gained


## Whether the XP that did it is shown: only when the level up came with a reward.
static func shows_xp(xp_gained: int) -> bool:
	return xp_gained > 0


## A stat's maximum now and after the level up, in whole points ("70 → 80").
static func value_text(maximum: float, raised: float) -> String:
	return "%d → %d" % [roundi(maximum), roundi(maximum + raised)]
