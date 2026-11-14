extends Control
## A quest step's box: filled grey when done, else an open square. Graphics
## (docs/CODE_LAGEN.md): only a drawing, nothing to decide or to work out.
##   const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")

var done := false


func _init() -> void:
	custom_minimum_size = Vector2(10, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if done:
		draw_rect(Rect2(Vector2.ZERO, Vector2(10, 10)), UiStyle.MUTED)
	else:
		# an open square: a 2 px border
		for edge in [Rect2(0, 0, 10, 2), Rect2(0, 8, 10, 2), Rect2(0, 2, 2, 6), Rect2(8, 2, 2, 6)]:
			draw_rect(edge, UiStyle.TEXT)
