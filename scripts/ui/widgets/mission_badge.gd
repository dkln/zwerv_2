extends Control
## The thumbnail of a "NIEUWE MISSIE" page in the story box (story_box.gd), in place of the
## speaker's portrait: a pixel emblem, an amber diamond with an ink exclamation mark in it
## and a hard ink shadow, bobbing a little, with a few sparkles round it that blink in turn
## and light rays turning slowly behind it. Fills its parent; drawn in code.

const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The emblem is DIAMOND_PIXELS wide and high (an odd number), each pixel EMBLEM_PIXEL px.
const DIAMOND_PIXELS := 17
const EMBLEM_PIXEL := 7.0
const SHADOW_PIXELS := 1
## How far (px) and how fast (per second) it bobs.
const BOB_PIXELS := 4.0
const BOB_SPEED := 2.2
## The rays: how many, how long (share of the frame), how fast they turn (radians per second).
const RAY_COUNT := 8
const RAY_LENGTH := 0.75
const RAY_SPEED := 0.35
const RAY_COLOUR := Color(1.0, 0.71, 0.28, 0.08)
## Sparkles: places round the emblem (share of the size, from the middle) and how often they blink.
const SPARKLES := [Vector2(-0.36, -0.30), Vector2(0.34, -0.22), Vector2(-0.30, 0.32), Vector2(0.38, 0.30)]
const SPARKLE_SECONDS := 1.6

var colour := UiStyle.ACCENT
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var middle := (size * 0.5).round()
	_draw_rays(middle)
	var bob := roundf(sin(_clock * BOB_SPEED) * BOB_PIXELS)
	var top_left := (middle - Vector2.ONE * DIAMOND_PIXELS * EMBLEM_PIXEL * 0.5 + Vector2(0, bob)).round()
	var shadow := Vector2.ONE * SHADOW_PIXELS * EMBLEM_PIXEL
	for row in DIAMOND_PIXELS:
		for column in DIAMOND_PIXELS:
			if _in_diamond(column, row):
				_pixel(top_left + shadow, column, row, UiStyle.INK)
	for row in DIAMOND_PIXELS:
		for column in DIAMOND_PIXELS:
			if _in_diamond(column, row):
				_pixel(top_left, column, row, UiStyle.INK if _in_mark(column, row) else _shade(column, row))
	_draw_sparkles(middle)


## Rays from the middle, turning slowly: thin triangles, barely there.
func _draw_rays(middle: Vector2) -> void:
	var reach := size.length() * RAY_LENGTH
	for ray in RAY_COUNT:
		var angle := _clock * RAY_SPEED + TAU * ray / RAY_COUNT
		var spread := 0.11
		draw_colored_polygon(PackedVector2Array([middle,
				middle + Vector2.from_angle(angle - spread) * reach,
				middle + Vector2.from_angle(angle + spread) * reach]), RAY_COLOUR)


## Four-point pixel sparkles, each on for part of its own turn.
func _draw_sparkles(middle: Vector2) -> void:
	var arm := 3.0
	for index in SPARKLES.size():
		var turn := fposmod(_clock / SPARKLE_SECONDS - float(index) / SPARKLES.size(), 1.0)
		if turn > 0.45:
			continue
		var at := (middle + (SPARKLES[index] as Vector2) * size).round()
		var grown := 1.0 if turn < 0.15 or turn > 0.3 else 2.0
		draw_rect(Rect2(at - Vector2.ONE * arm * 0.5, Vector2.ONE * arm), colour)
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			for step in grown:
				draw_rect(Rect2(at - Vector2.ONE * arm * 0.5 + direction * arm * (step + 1.0), Vector2.ONE * arm), colour)


func _pixel(top_left: Vector2, column: int, row: int, pixel_colour: Color) -> void:
	draw_rect(Rect2(top_left + Vector2(column, row) * EMBLEM_PIXEL, Vector2.ONE * EMBLEM_PIXEL), pixel_colour)


static func _in_diamond(column: int, row: int) -> bool:
	var half := DIAMOND_PIXELS / 2
	return absi(column - half) + absi(row - half) <= half


## The exclamation mark: a bar three pixels wide and a dot under it.
static func _in_mark(column: int, row: int) -> bool:
	var half := DIAMOND_PIXELS / 2
	if absi(column - half) > 1:
		return false
	return (row >= 3 and row <= 9) or (row >= 11 and row <= 12)


## Lighter along the upper left edge, darker along the lower right: a bevelled look.
func _shade(column: int, row: int) -> Color:
	var half := DIAMOND_PIXELS / 2
	var from_edge := half - (absi(column - half) + absi(row - half))
	if from_edge == 0:
		return colour.lightened(0.35) if column + row <= DIAMOND_PIXELS - 1 else colour.darkened(0.3)
	return colour
