extends RefCounted
## The floor plan of an interior for the minimap of the HUD (GameHud.show_interior_plan),
## read from the interior's own colliders, nothing drawn by hand: over the area of its
## GridMaps, every SAMPLE_METRES a probe at head height (a wall, a high counter), one at
## knee height (furniture) and a ray down (the floor, or lower ground such as the tracks).
## Only the static colliders count (GridMap shapes, StaticBody3D): not the player, people or
## trains. The physics of the interior must be live (it is visible and not resting).
## Graphics (docs/CODE_LAGEN.md): it paints the picture of what its probes find; what a
## probe makes of it is interior_plan_rules.gd.
##   const InteriorPlan = preload("res://scripts/ui/widgets/interior_plan.gd")
##   var plan := InteriorPlan.build(interior)   # {"texture", "origin", "metres_per_pixel", "extent"}

const InteriorPlanRules = preload("res://scripts/ui/widgets/interior_plan_rules.gd")
const SAMPLE_METRES := InteriorPlanRules.SAMPLE_METRES
const TOWN_LAYER := 1
## The colour of what a probe finds (InteriorPlanRules.kind).
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
	if not InteriorPlanRules.has_area(bounds.size):
		return {}
	var floor_height := interior.global_position.y
	var grid := InteriorPlanRules.grid_size(bounds.size)
	var image := Image.create(grid.x, grid.y, false, Image.FORMAT_RGB8)
	image.fill(COLOURS[InteriorPlanRules.EMPTY])
	var head_probe := PhysicsPointQueryParameters3D.new()
	head_probe.collision_mask = TOWN_LAYER
	var knee_probe := PhysicsPointQueryParameters3D.new()
	knee_probe.collision_mask = TOWN_LAYER
	for row in grid.y:
		for column in grid.x:
			var spot := InteriorPlanRules.spot(bounds.position, column, row)
			var knee := Vector3(spot.x, floor_height + InteriorPlanRules.KNEE_HEIGHT, spot.y)
			head_probe.position = Vector3(spot.x, floor_height + InteriorPlanRules.HEAD_HEIGHT, spot.y)
			knee_probe.position = knee
			# a wall needs no look lower down, furniture no look at the ground
			var head_blocked := _hits_static(space.intersect_point(head_probe, 8))
			var knee_blocked := not head_blocked and _hits_static(space.intersect_point(knee_probe, 8))
			var ground := NAN if head_blocked or knee_blocked \
					else _ground_below(space, knee, floor_height - InteriorPlanRules.GROUND_DEPTH)
			var kind := InteriorPlanRules.kind(head_blocked, knee_blocked, ground, floor_height)
			if kind != InteriorPlanRules.EMPTY:
				image.set_pixel(column, row, COLOURS[kind])
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
			var area := InteriorPlanRules.grown(lowest, highest, Vector2(centre.x, centre.z), half_cell)
			lowest = area[0]
			highest = area[1]
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
