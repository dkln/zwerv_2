extends Control
## Light rays turning slowly behind something that is a moment of its own: the emblem of a new
## mission in the story box (widgets/mission_badge.gd) and the item of the reward screen
## (scripts/ui/reward_screen.gd). Thin triangles from the middle; fills its parent; drawn in
## code (draw_rays, also for whoever draws them in its own _draw). Graphics
## (docs/CODE_LAGEN.md): a picture on its own, nothing to decide; its shapes come from
## light_rays_layout.gd.
##   const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")

const LightRaysLayout = preload("res://scripts/ui/widgets/light_rays_layout.gd")
const RAY_COUNT := LightRaysLayout.RAY_COUNT
const RAY_LENGTH := LightRaysLayout.RAY_LENGTH
const RAY_SPREAD := LightRaysLayout.RAY_SPREAD
const RAY_SPEED := LightRaysLayout.RAY_SPEED
## The colour, barely there.
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
	draw_rays(self, LightRaysLayout.middle(size), LightRaysLayout.reach(size, length), _clock * speed, colour, count, spread)


## `ray_count` rays from `middle` on `canvas`, `reach` px long, turned `turn` radians.
static func draw_rays(canvas: CanvasItem, middle: Vector2, reach: float, turn: float, ray_colour := RAY_COLOUR,
		ray_count := RAY_COUNT, ray_spread := RAY_SPREAD) -> void:
	for ray in ray_count:
		canvas.draw_colored_polygon(LightRaysLayout.ray_triangle(middle, reach,
				LightRaysLayout.ray_angle(turn, ray, ray_count), ray_spread), ray_colour)
