extends RefCounted
## The shape of the arrows on the maps (layout; docs/CODE_LAGEN.md): an arrow with a tail,
## like "->". Drawn by player_arrow.gd (the player on the minimap) and quest_marks.gd (a far
## place on the minimap's edge).
##   const PlayerArrowLayout = preload("res://scripts/ui/widgets/player_arrow_layout.gd")

## The player's arrow, pointing up: its ink outline and the white arrow in it, each
## [tip, length, head length, half the head, half the tail] (see shape).
const OUTLINE := [Vector2(0, -12), 23.0, 14.0, 11.0, 4.5]
const INSIDE := [Vector2(0, -9), 18.0, 9.0, 8.0, 2.5]


## An arrow with a tail: its tip at `tip` pointing `way` (unit length), `length` px from the
## tip to the end of the tail, the head `head_length` long and `head_half` px to either side,
## the tail `tail_half` px to either side.
static func shape(tip: Vector2, way: Vector2, length: float, head_length: float, head_half: float, tail_half: float) -> PackedVector2Array:
	var across := Vector2(-way.y, way.x)
	var head_base := tip - way * head_length
	var tail_end := tip - way * length
	return PackedVector2Array([tip,
		head_base + across * head_half, head_base + across * tail_half,
		tail_end + across * tail_half, tail_end - across * tail_half,
		head_base - across * tail_half, head_base - across * head_half])


## The arrow of `measures` (OUTLINE or INSIDE), pointing up.
static func upward(measures: Array) -> PackedVector2Array:
	return shape(measures[0], Vector2.UP, measures[1], measures[2], measures[3], measures[4])
