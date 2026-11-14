extends RefCounted
## The shape of the light rays behind a reward or a new mission (layout;
## docs/CODE_LAGEN.md): how many, how long, how wide and how fast they turn, and the
## triangle of each one. Drawn by light_rays.gd (and by mission_badge.gd behind its emblem).
##   const LightRaysLayout = preload("res://scripts/ui/widgets/light_rays_layout.gd")

## How many, how long (share of the size), how wide each one is (radians either side) and how
## fast they turn (radians per second).
const RAY_COUNT := 8
const RAY_LENGTH := 0.75
const RAY_SPREAD := 0.11
const RAY_SPEED := 0.35


## The middle of a picture of `size` px, on a whole pixel: where the rays start.
static func middle(size: Vector2) -> Vector2:
	return (size * 0.5).round()


## How long the rays are in a picture of `size` px: `length` of its diagonal.
static func reach(size: Vector2, length := RAY_LENGTH) -> float:
	return size.length() * length


## The angle of ray `ray` of `ray_count`, the whole fan turned `turn` radians.
static func ray_angle(turn: float, ray: int, ray_count := RAY_COUNT) -> float:
	return turn + TAU * ray / ray_count


## The triangle of one ray: from `middle`, `reach` px long, pointing along `angle` (radians),
## `ray_spread` radians wide to either side.
static func ray_triangle(from: Vector2, length: float, angle: float, ray_spread := RAY_SPREAD) -> PackedVector2Array:
	return PackedVector2Array([from,
			from + Vector2.from_angle(angle - ray_spread) * length,
			from + Vector2.from_angle(angle + ray_spread) * length])
