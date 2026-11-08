extends Control
## A segmented bar: `segments` blocks of 9 px wide and `segment_height` high, 2 px apart, on
## ink with a 2 px border; the first `fill` share of them in `full_colour`.

const UiStyle = preload("res://scripts/ui/ui_style.gd")

const SEGMENT_WIDTH := 9.0
const GAP := 2.0
const PADDING := 3.0
const BORDER_WIDTH := 2.0
var segments := 20:
	set(value):
		segments = value
		_resize()
var segment_height := 12:
	set(value):
		segment_height = value
		_resize()
var full_colour := Color.WHITE
var empty_colour := Color.BLACK
var fill := 1.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _resize() -> void:
	var inner := Vector2(segments * SEGMENT_WIDTH + (segments - 1) * GAP, segment_height)
	custom_minimum_size = inner + Vector2.ONE * 2.0 * (PADDING + BORDER_WIDTH)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BORDER)
	draw_rect(Rect2(Vector2.ONE * BORDER_WIDTH, size - Vector2.ONE * 2.0 * BORDER_WIDTH), UiStyle.INK)
	var full := roundi(fill * segments)
	var start := Vector2.ONE * (BORDER_WIDTH + PADDING)
	for segment_index in segments:
		var at := start + Vector2(segment_index * (SEGMENT_WIDTH + GAP), 0.0)
		draw_rect(Rect2(at, Vector2(SEGMENT_WIDTH, segment_height)), full_colour if segment_index < full else empty_colour)
