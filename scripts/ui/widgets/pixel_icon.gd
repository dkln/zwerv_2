extends Control
## A pixel icon: a bitmap of rows ("#" = coloured), `pixel` screen pixels per pixel.

var bitmap: Array = []:
	set(value):
		bitmap = value
		_resize()
var colour := Color.WHITE:
	set(value):
		colour = value
		queue_redraw()
var pixel := 2.0:
	set(value):
		pixel = value
		_resize()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _resize() -> void:
	var rows := bitmap.size()
	var columns: int = (bitmap[0] as String).length() if rows > 0 else 0
	custom_minimum_size = Vector2(columns, rows) * pixel
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	for row_index in bitmap.size():
		var row: String = bitmap[row_index]
		for column_index in row.length():
			if row[column_index] == "#":
				draw_rect(Rect2(Vector2(column_index, row_index) * pixel, Vector2(pixel, pixel)), colour)
