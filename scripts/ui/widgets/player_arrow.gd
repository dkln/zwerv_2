extends Control
## The player on the minimap: a white arrow with a tail (like "->"), pointing up (north) when
## unturned, with an ink outline, turned round its middle. shape() gives the same arrow to
## the other arrows on the maps (quest_marks.gd: a far place on the minimap's edge).

const UiStyle = preload("res://scripts/ui/ui_style.gd")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_colored_polygon(shape(Vector2(0, -12), Vector2.UP, 23.0, 14.0, 11.0, 4.5), UiStyle.INK)
	draw_colored_polygon(shape(Vector2(0, -9), Vector2.UP, 18.0, 9.0, 8.0, 2.5), Color.WHITE)


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
