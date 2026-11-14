extends RefCounted
## The logic of a lift ride (docs/CODE_LAGEN.md): which way the lift goes, which levels it
## passes, how long that takes, and what its display says ("▲ 2", "▼ 1", "K" for the
## basement). Its behaviour: lift_ride.gd; where things stand: lift_ride_layout.gd.
##   const LiftRideRules = preload("res://scripts/world/interiors/lift_ride_rules.gd")

## The ride: seconds per floor going by, and after arriving before you step out.
const FLOOR_SECONDS := 1.4
const ARRIVE_SECONDS := 0.9
## The scale of the stand-in when the player does not say its own (PlayerController.FIGURE_SCALE).
const FIGURE_SCALE := 0.78


## Which way the lift steps from level `from` to `to`: 1 up, -1 down (also when it stays).
static func step(from: int, to: int) -> int:
	return 1 if to > from else -1


## The arrow the display shows on the way from `from` to `to`: 1 up, -1 down, 0 none (it stays).
static func arrow(from: int, to: int) -> int:
	return 0 if to == from else step(from, to)


## The levels the lift is at one after the other, from `from` up to and with `to`.
static func levels_passed(from: int, to: int) -> Array[int]:
	var levels: Array[int] = [from]
	var level := from
	while level != to:
		level += step(from, to)
		levels.append(level)
	return levels


## How long the ride from `from` to `to` moves (seconds): the further, the longer.
static func ride_seconds(from: int, to: int) -> float:
	return absi(to - from) * FLOOR_SECONDS


## The text of a level: "K" for the basement (below 0), else its number.
static func level_text(level: int) -> String:
	return "K" if level < 0 else str(level)


## What the display says at `level` going `direction` (1 up, -1 down, 0 standing): "▲ 2", "3".
static func display_text(level: int, direction: int) -> String:
	var arrow_text := "▲ " if direction > 0 else ("▼ " if direction < 0 else "")
	return arrow_text + level_text(level)
