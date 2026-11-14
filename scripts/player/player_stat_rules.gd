extends RefCounted
## The arithmetic of the player's stats over time (logic; docs/CODE_LAGEN.md): what each
## starts at, a change kept within its maximum, a blow, a while above the maximum (coffee),
## hunger and overstimulation running down, stamina running out and coming back, starving,
## and when the HUD is told. The behaviour is player_controller.gd (change_stat, boost_stat,
## _update_stats, _hurt). A stat is a Vector2(value, maximum), as in the HUD
## (scripts/ui/hud/stat_rules.gd, whose `clamped` is reused here).
##   const PlayerStatRules = preload("res://scripts/player/player_stat_rules.gd")

const StatRules = preload("res://scripts/ui/hud/stat_rules.gd")
const STAT_NAMES := ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"]
const HEALTH := "gezondheid"
const STAMINA := "uithoudingsvermogen"
const HUNGER := "honger"
const OVERSTIMULATION := "overprikkeldheid"
const OVERSTIMULATION_MAXIMUM := 100.0
## Hunger runs out this much slower while wearing clothes (Items "worn": the coat of Ome Wim).
const WORN_HUNGER_FACTOR := 0.85
## The maximum of a stat the archetype does not name.
const DEFAULT_MAXIMUM := 100.0
## What the HUD was given of a stat that was never shown.
const NEVER_SHOWN := Vector2(-1.0, -1.0)


## The stats at the start of a game, from the "stats" of the archetype (the maximum of each):
## everything full, overstimulation at 0 of OVERSTIMULATION_MAXIMUM.
static func starting_stats(archetype_stats: Dictionary) -> Dictionary:
	var stats := {}
	for stat_name: String in STAT_NAMES:
		if stat_name == OVERSTIMULATION:
			stats[stat_name] = Vector2(0.0, OVERSTIMULATION_MAXIMUM)
		else:
			var maximum := float(archetype_stats.get(stat_name, DEFAULT_MAXIMUM))
			stats[stat_name] = Vector2(maximum, maximum)
	return stats


## Whether a change is a blow: health going down (it hurts, change_stat hands it to _hurt).
static func is_blow(stat_name: String, amount: float) -> bool:
	return stat_name == HEALTH and amount < 0.0


## A stat changed by `amount`, kept between 0 and its maximum.
static func changed(current: Vector2, amount: float) -> Vector2:
	return StatRules.clamped(current.x + amount, current.y, current.y)


## A stat after losing `amount` (a blow, running, hunger): never below 0.
static func lowered(current: Vector2, amount: float) -> Vector2:
	return Vector2(maxf(current.x - amount, 0.0), current.y)


## A stat run down at `per_second` for `delta` seconds: never below 0.
static func drained(current: Vector2, per_second: float, delta: float) -> Vector2:
	return Vector2(maxf(current.x - per_second * delta, 0.0), current.y)


## A stat filled up at `per_second` for `delta` seconds: never above its maximum.
static func recovered(current: Vector2, per_second: float, delta: float) -> Vector2:
	return Vector2(minf(current.x + per_second * delta, current.y), current.y)


## A stat with nothing left of it (drowned).
static func emptied(current: Vector2) -> Vector2:
	return Vector2(0.0, current.y)


## A stat `amount` above its maximum for a while: value and maximum up by as much.
static func boosted(current: Vector2, amount: float) -> Vector2:
	return Vector2(current.x + amount, current.y + amount)


## A stat boosted again while the boost lasts: filled to its (raised) maximum, no higher.
static func topped_up(current: Vector2) -> Vector2:
	return Vector2(current.y, current.y)


## A stat when its boost of `amount` wears off: the maximum back, the value with it if above.
static func worn_off(current: Vector2, amount: float) -> Vector2:
	return Vector2(minf(current.x, current.y - amount), current.y - amount)


## Points of hunger a second: `per_minute`, `running_factor` times as fast while running,
## WORN_HUNGER_FACTOR of it while wearing something warm.
static func hunger_per_second(per_minute: float, running: bool, running_factor: float, wears_something: bool) -> float:
	var rate := per_minute / 60.0 * (running_factor if running else 1.0)
	if wears_something:
		rate *= WORN_HUNGER_FACTOR
	return rate


## The clock of starving after `delta` seconds: {"clock", "bites"}. With an empty stomach it
## runs and bites (health off) every `interval` seconds; with food in it, it stands at 0.
static func starvation(clock: float, hunger: Vector2, delta: float, interval: float) -> Dictionary:
	if hunger.x > 0.0:
		return {"clock": 0.0, "bites": false}
	clock += delta
	if clock >= interval:
		return {"clock": clock - interval, "bites": true}
	return {"clock": clock, "bites": false}


## Whether stamina comes back: `rest_seconds` after running, from `delay` seconds on.
static func recovers(rest_seconds: float, delay: float) -> bool:
	return rest_seconds >= delay


## Whether it is (still) exhausted: run empty, until the stamina is back at `until` (a share)
## of its maximum.
static func is_exhausted(was_exhausted: bool, running: bool, stamina: Vector2, until: float) -> bool:
	if running:
		return was_exhausted or stamina.x <= 0.0
	return was_exhausted and not stamina.x >= stamina.y * until


## Whether the HUD has to hear of a stat: its value in whole points or its maximum differs
## from what it was given last (`shown`).
static func shows_change(shown: Vector2, value: Vector2) -> bool:
	return roundf(shown.x) != roundf(value.x) or shown.y != value.y


## Health lost as it floats up over the head: "-12" (at least 1).
static func damage_text(amount: float) -> String:
	return "-%d" % maxi(roundi(amount), 1)
