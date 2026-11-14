extends RefCounted
## The arithmetic of the player's experience (logic; docs/CODE_LAGEN.md): how many points a
## level takes, what a gain does to the points and the level, and what choosing a stat on the
## level-up screen does to it. The behaviour is player_controller.gd (add_xp, raise_stat); how
## the bar is written is the HUD's (scripts/ui/hud/stat_rules.gd).
##   const PlayerExperienceRules = preload("res://scripts/player/player_experience_rules.gd")

## XP the first level up takes (level 1 -> 2); each next level takes XP_GROWTH times as
## much (rounded to XP_ROUNDING): 500, 750, 1150, 1750, ...
const XP_FIRST_LEVEL := 500.0
const XP_GROWTH := 1.5
const XP_ROUNDING := 50.0
## How much the maximum of a stat goes up when it is chosen on the level-up screen. Health,
## stamina and hunger also fill up by as much; overstimulation (how much you can take) does not.
const LEVEL_UP_RAISE := {"gezondheid": 10.0, "uithoudingsvermogen": 10.0, "honger": 20.0, "overprikkeldheid": 15.0}
## The stat whose value stays where it is when its maximum is raised.
const NOT_FILLED := "overprikkeldheid"


## The points the level after one of `points_for_level` takes.
static func next_level_points(points_for_level: float) -> float:
	return roundf(points_for_level * XP_GROWTH / XP_ROUNDING) * XP_ROUNDING


## `points` more experience on top of `xp` (of the `xp_for_level` this level takes) at `level`:
## {"xp", "xp_for_level", "level", "levels_gained" (Array[int]: every level reached, in order)}.
## Nothing or less than nothing changes nothing.
static func gained(xp: float, xp_for_level: float, level: int, points: float) -> Dictionary:
	var levels_gained: Array[int] = []
	if points > 0.0:
		xp += points
		while xp >= xp_for_level:
			xp -= xp_for_level
			level += 1
			xp_for_level = next_level_points(xp_for_level)
			levels_gained.append(level)
	return {"xp": xp, "xp_for_level": xp_for_level, "level": level, "levels_gained": levels_gained}


## Whether a stat can be chosen on the level-up screen.
static func can_raise(stat_name: String) -> bool:
	return LEVEL_UP_RAISE.has(stat_name)


## A stat (value, maximum) after it was chosen on the level-up screen: the maximum up by
## LEVEL_UP_RAISE, the value with it (not for NOT_FILLED); unchanged for a stat that cannot.
static func raised(stat_name: String, current: Vector2) -> Vector2:
	if not can_raise(stat_name):
		return current
	var amount: float = LEVEL_UP_RAISE[stat_name]
	var filled := current.x if stat_name == NOT_FILLED else current.x + amount
	return Vector2(filled, current.y + amount)


## A gain as it rises over the figure: "+50 XP".
static func gain_text(points: float) -> String:
	return "+%d XP" % roundi(points)
