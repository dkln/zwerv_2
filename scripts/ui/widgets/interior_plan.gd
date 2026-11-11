extends RefCounted
## The floor plan of an interior for the minimap of the HUD (GameHud.show_interior_plan),
## read from the interior's own colliders, nothing drawn by hand: over the area of its
## GridMaps, every SAMPLE_METRES a probe at head height (a wall, a high counter), one at
## knee height (furniture) and a ray down (the floor, or lower ground such as the tracks).
## Only the static colliders count (GridMap shapes, StaticBody3D): not the player, people or
## trains. The physics of the interior must be live (it is visible and not resting).
##   var plan := InteriorPlan.build(interior)   # {"texture", "origin", "metres_per_pixel", "extent"}

const SAMPLE_METRES := 0.5
const TOWN_LAYER := 1
## Heights of the probes over the floor of the interior (its origin), metres.
const HEAD_HEIGHT := 1.7
const KNEE_HEIGHT := 0.6
## Ground this far below the floor counts as lower (the tracks, a pit).
const LOWER_FROM := -0.4
const COLOURS := {
	"empty": Color("#0B0D1A"),
	"wall": Color("#9AA3D6"),
	"furniture": Color("#2E3456"),
	"floor": Color("#4A5378"),
	"lower": Color("#262840"),
}


## The plan of `interior`; empty when it has no GridMaps or no physics world.
static func build(interior: Node3D) -> Dictionary:
	var world := interior.get_world_3d()
	if world == null:
		return {}
	var space := world.direct_space_state
	var bounds := _bounds(interior)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {}
	var floor_height := interior.global_position.y
	var width := int(ceil(bounds.size.x / SAMPLE_METRES))
	var depth := int(ceil(bounds.size.y / SAMPLE_METRES))
	var image := Image.create(width, depth, false, Image.FORMAT_RGB8)
	image.fill(COLOURS["empty"])
	var head_probe := PhysicsPointQueryParameters3D.new()
	head_probe.collision_mask = TOWN_LAYER
	var knee_probe := PhysicsPointQueryParameters3D.new()
	knee_probe.collision_mask = TOWN_LAYER
	for row in depth:
		for column in width:
			var spot := bounds.position + (Vector2(column, row) + Vector2(0.5, 0.5)) * SAMPLE_METRES
			head_probe.position = Vector3(spot.x, floor_height + HEAD_HEIGHT, spot.y)
			if _hits_static(space.intersect_point(head_probe, 8)):
				image.set_pixel(column, row, COLOURS["wall"])
				continue
			knee_probe.position = Vector3(spot.x, floor_height + KNEE_HEIGHT, spot.y)
			if _hits_static(space.intersect_point(knee_probe, 8)):
				image.set_pixel(column, row, COLOURS["furniture"])
				continue
			var ground := _ground_below(space, Vector3(spot.x, floor_height + KNEE_HEIGHT, spot.y), floor_height - 4.0)
			if is_nan(ground):
				continue
			image.set_pixel(column, row, COLOURS["lower"] if ground < floor_height + LOWER_FROM else COLOURS["floor"])
	return {"texture": ImageTexture.create_from_image(image), "origin": bounds.position,
		"metres_per_pixel": SAMPLE_METRES, "extent": bounds.size}


## The area (world x, z) the GridMaps of `interior` cover.
static func _bounds(interior: Node3D) -> Rect2:
	var lowest := Vector2(INF, INF)
	var highest := Vector2(-INF, -INF)
	for child in interior.find_children("*", "GridMap", true, false):
		var grid := child as GridMap
		var half_cell := Vector2(grid.cell_size.x, grid.cell_size.z) * 0.5
		for cell in grid.get_used_cells():
			var centre := grid.to_global(grid.map_to_local(cell))
			lowest = Vector2(minf(lowest.x, centre.x - half_cell.x), minf(lowest.y, centre.z - half_cell.y))
			highest = Vector2(maxf(highest.x, centre.x + half_cell.x), maxf(highest.y, centre.z + half_cell.y))
	if lowest.x == INF:
		return Rect2()
	return Rect2(lowest, highest - lowest)


static func _is_static(collider: Object) -> bool:
	return collider is GridMap or collider is StaticBody3D


static func _hits_static(hits: Array[Dictionary]) -> bool:
	for hit in hits:
		if _is_static(hit.get("collider")):
			return true
	return false


## The height of the first static ground under `from`, down to `lowest`; NAN if none.
static func _ground_below(space: PhysicsDirectSpaceState3D, from: Vector3, lowest: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(from.x, lowest, from.z), TOWN_LAYER)
	var skipped: Array[RID] = []
	for _attempt in 4:
		query.exclude = skipped
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return NAN
		if _is_static(hit.get("collider")):
			return (hit.position as Vector3).y
		skipped.append(hit.rid)
	return NAN
