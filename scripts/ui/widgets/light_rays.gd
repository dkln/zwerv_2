extends Control
## Light rays turning slowly behind something that is a moment of its own: the emblem of a new
## mission in the story box (widgets/mission_badge.gd) and the item of the reward screen
## (scripts/ui/reward_screen.gd). Thin triangles from the middle; fills its parent; drawn in
## code (draw_rays, also for whoever draws them in its own _draw).

const UiStyle = preload("res://scripts/ui/ui_style.gd")
## How many, how long (share of the size), how wide each one is (radians either side) and how
## fast they turn (radians per second); the colour, barely there.
const RAY_COUNT := 8
const RAY_LENGTH := 0.75
const RAY_SPREAD := 0.11
const RAY_SPEED := 0.35
const RAY_COLOUR := Color(1.0, 0.71, 0.28, 0.08)

var colour := RAY_COLOUR
var count := RAY_COUNT
var length := RAY_LENGTH
var spread := RAY_SPREAD
var speed := RAY_SPEED
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
	draw_rays(self, (size * 0.5).round(), size.length() * length, _clock * speed, colour, count, spread)


## `ray_count` rays from `middle` on `canvas`, `reach` px long, turned `turn` radians.
static func draw_rays(canvas: CanvasItem, middle: Vector2, reach: float, turn: float, ray_colour := RAY_COLOUR,
		ray_count := RAY_COUNT, ray_spread := RAY_SPREAD) -> void:
	for ray in ray_count:
		var angle := turn + TAU * ray / ray_count
		canvas.draw_colored_polygon(PackedVector2Array([middle,
				middle + Vector2.from_angle(angle - ray_spread) * reach,
				middle + Vector2.from_angle(angle + ray_spread) * reach]), ray_colour)
