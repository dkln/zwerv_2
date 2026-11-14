extends RefCounted
## The arithmetic of the stats of the player and the experience (logic; docs/CODE_LAGEN.md):
## a value within its maximum, the share of its bar that is full, how it is written, and
## when a change is a jump. How the stats look: stat_look.gd; where they are shown:
## player_frame.gd (the HUD), the game menu, the level-up screen.
##   const StatRules = preload("res://scripts/ui/hud/stat_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")
## The maximum of a stat that was never given one.
const DEFAULT_MAXIMUM := 100.0
## A change of a stat of at least this many points in one go is a jump (a hit, eating,
## hunger biting); the slow running down and filling up of the meters is not.
const JUMP_FROM := 1.5


## A stat's value within 0..its maximum: Vector2(value, maximum). `maximum` <= 0 keeps
## `previous_maximum`.
static func clamped(value: float, maximum: float, previous_maximum: float) -> Vector2:
	var top := maximum if maximum > 0.0 else previous_maximum
	return Vector2(clampf(value, 0.0, top), top)


## A stat as its bar writes it: "35/80".
static func value_text(stat: Vector2) -> String:
	return "%d/%d" % [roundi(stat.x), roundi(stat.y)]


## The share (0..1) of a stat's bar that is full.
static func fill(stat: Vector2) -> float:
	return stat.x / stat.y if stat.y > 0.0 else 0.0


## Whether a stat going from `before` to `after` in one go is a jump.
static func is_jump(before: float, after: float) -> bool:
	return absf(after - before) >= JUMP_FROM


## The experience within this level: Vector2(points, points the level takes), the points
## within 0..that, the level at least 1 point long.
static func experience(points: float, points_for_level: float) -> Vector2:
	var top := maxf(points_for_level, 1.0)
	return Vector2(clampf(points, 0.0, top), top)


## The experience as written under its bar: "6.420 / 10.000".
static func experience_text(experience_now: Vector2) -> String:
	return "%s / %s" % [MoneyText.thousands(roundi(experience_now.x)), MoneyText.thousands(roundi(experience_now.y))]


## The level as written on the badge: "LEVEL 4".
static func level_text(level: int) -> String:
	return "LEVEL %d" % level
