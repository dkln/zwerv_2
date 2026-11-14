extends Control
## The thumbnail of a "NIEUWE MISSIE" page in the story box (story_box.gd), in place of the
## speaker's portrait: a pixel emblem, an amber diamond with an ink exclamation mark in it
## and a hard ink shadow, bobbing a little, with a few sparkles round it that blink in turn
## and light rays turning slowly behind it. Fills its parent; drawn in code. Graphics
## (docs/CODE_LAGEN.md): a picture on its own, nothing to decide; its shapes come from
## mission_badge_layout.gd.
##   const MissionBadge = preload("res://scripts/ui/widgets/mission_badge.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MissionBadgeLayout = preload("res://scripts/ui/widgets/mission_badge_layout.gd")
## The rays behind it (shared with the reward screen).
const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")
const LightRaysLayout = preload("res://scripts/ui/widgets/light_rays_layout.gd")
## How much lighter the upper left edge of the diamond is, and how much darker the lower right.
const EDGE_LIGHTEN := 0.35
const EDGE_DARKEN := 0.3

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
	var middle := LightRaysLayout.middle(size)
	LightRays.draw_rays(self, middle, LightRaysLayout.reach(size), _clock * LightRaysLayout.RAY_SPEED)
	var origin := MissionBadgeLayout.emblem_origin(middle, MissionBadgeLayout.bob(_clock))
	var shadow_origin := origin + MissionBadgeLayout.shadow_offset()
	for row in MissionBadgeLayout.DIAMOND_PIXELS:
		for column in MissionBadgeLayout.DIAMOND_PIXELS:
			if MissionBadgeLayout.in_diamond(column, row):
				draw_rect(MissionBadgeLayout.pixel_rect(shadow_origin, column, row), UiStyle.INK)
	for row in MissionBadgeLayout.DIAMOND_PIXELS:
		for column in MissionBadgeLayout.DIAMOND_PIXELS:
			if MissionBadgeLayout.in_diamond(column, row):
				draw_rect(MissionBadgeLayout.pixel_rect(origin, column, row),
						UiStyle.INK if MissionBadgeLayout.in_mark(column, row) else shade(column, row, colour))
	_draw_sparkles(middle)


## Four-point pixel sparkles, each on for part of its own turn.
func _draw_sparkles(middle: Vector2) -> void:
	for index in MissionBadgeLayout.SPARKLES.size():
		var arms := MissionBadgeLayout.sparkle_arms(_clock, index)
		if arms == 0:
			continue
		for rect in MissionBadgeLayout.sparkle_rects(MissionBadgeLayout.sparkle_place(index, middle, size), arms):
			draw_rect(rect, colour)


## The colour of pixel (column, row) of a diamond in `base_colour`: lighter along the upper left
## edge, darker along the lower right: a bevelled look.
static func shade(column: int, row: int, base_colour: Color) -> Color:
	match MissionBadgeLayout.edge_of(column, row):
		MissionBadgeLayout.EDGE_LIT:
			return base_colour.lightened(EDGE_LIGHTEN)
		MissionBadgeLayout.EDGE_DARK:
			return base_colour.darkened(EDGE_DARKEN)
	return base_colour
