extends Control
## The player on the minimap: a white triangle pointing up (north) when unturned, with an
## ink outline, turned round its middle.

const UiStyle = preload("res://scripts/ui/ui_style.gd")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var outline := PackedVector2Array([Vector2(0, -10), Vector2(10, 10), Vector2(-10, 10)])
	draw_colored_polygon(outline, UiStyle.INK)
	var arrow := PackedVector2Array([Vector2(0, -8), Vector2(8, 8), Vector2(-8, 8)])
	draw_colored_polygon(arrow, Color.WHITE)
