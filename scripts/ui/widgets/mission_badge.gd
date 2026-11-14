extends Control
## The thumbnail of a "NIEUWE MISSIE" page in the story box (story_box.gd), in place of the
## speaker's portrait: a pixel emblem, an amber diamond with an ink exclamation mark in it
## and a hard ink shadow, bobbing a little, with a few sparkles round it that blink in turn
## and light rays turning slowly behind it. Fills its parent; drawn in code.

const UiStyle = preload("res://scripts/ui/ui_style.gd")
## The rays behind it (shared with the reward screen).
const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")

## The emblem is DIAMOND_PIXELS wide and high (an odd number), each pixel EMBLEM_PIXEL px.
const DIAMOND_PIXELS := 17
const EMBLEM_PIXEL := 7.0
const SHADOW_PIXELS := 1
## How far (px) and how fast (per second) it bobs.
const BOB_PIXELS := 4.0
const BOB_SPEED := 2.2
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
	LightRays.draw_rays(self, middle, size.length() * LightRays.RAY_LENGTH, _clock * LightRays.RAY_SPEED)
	var bob := roundf(sin(_clock * BOB_SPEED) * BOB_PIXELS)
	var top_left := (middle - Vector2.ONE * DIAMOND_PIXELS * EMBLEM_PIXEL * 0.5 + Vector2(0, bob)).round()
	var shadow := Vector2.ONE * SHADOW_PIXELS * EMBLEM_PIXEL
	for row in DIAMOND_PIXELS:
		for column in DIAMOND_PIXELS:
			if in_diamond(column, row):
				_pixel(top_left + shadow, column, row, UiStyle.INK)
	for row in DIAMOND_PIXELS:
		for column in DIAMOND_PIXELS:
			if in_diamond(column, row):
				_pixel(top_left, column, row, UiStyle.INK if in_mark(column, row) else shade(column, row, colour))
	_draw_sparkles(middle)


## Four-point pixel sparkles, each on for part of its own turn.
func _draw_sparkles(middle: Vector2) -> void:
	var arm := 3.0
	for index in SPARKLES.size():
		var grown := sparkle_arms(_clock, index)
		if grown == 0:
			continue
		var at := (middle + (SPARKLES[index] as Vector2) * size).round()
		draw_rect(Rect2(at - Vector2.ONE * arm * 0.5, Vector2.ONE * arm), colour)
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			for step in grown:
				draw_rect(Rect2(at - Vector2.ONE * arm * 0.5 + direction * arm * (step + 1.0), Vector2.ONE * arm), colour)


func _pixel(top_left: Vector2, column: int, row: int, pixel_colour: Color) -> void:
	draw_rect(Rect2(top_left + Vector2(column, row) * EMBLEM_PIXEL, Vector2.ONE * EMBLEM_PIXEL), pixel_colour)


## How long the arms of sparkle `index` are `clock` seconds in (pixels of the sparkle): 0
## while it is off, 1 as it comes and goes, 2 in between. Each sparkle is on for the first
## 45 % of its own turn of SPARKLE_SECONDS, the turns one after the other.
static func sparkle_arms(clock: float, index: int) -> int:
	var turn := fposmod(clock / SPARKLE_SECONDS - float(index) / SPARKLES.size(), 1.0)
	if turn > 0.45:
		return 0
	return 1 if turn < 0.15 or turn > 0.3 else 2


## Whether pixel (column, row) of the emblem lies in the diamond.
static func in_diamond(column: int, row: int) -> bool:
	var half := DIAMOND_PIXELS / 2
	return absi(column - half) + absi(row - half) <= half


## The exclamation mark: a bar three pixels wide and a dot under it.
static func in_mark(column: int, row: int) -> bool:
	var half := DIAMOND_PIXELS / 2
	if absi(column - half) > 1:
		return false
	return (row >= 3 and row <= 9) or (row >= 11 and row <= 12)


## The colour of pixel (column, row) of a diamond in `base_colour`: lighter along the upper left
## edge, darker along the lower right: a bevelled look.
static func shade(column: int, row: int, base_colour: Color) -> Color:
	var half := DIAMOND_PIXELS / 2
	var from_edge := half - (absi(column - half) + absi(row - half))
	if from_edge == 0:
		return base_colour.lightened(0.35) if column + row <= DIAMOND_PIXELS - 1 else base_colour.darkened(0.3)
	return base_colour
