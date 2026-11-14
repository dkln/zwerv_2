extends RefCounted
## How many steps from every cell to the nearest of some goal cells (breadth first): a field
## to walk down, step by step, to the nearest goal (Pedestrians: the station doors). Knows
## nothing of the town: the links are a Callable, so it is tested on small hand-made graphs.
##   const StepField = preload("res://scripts/pathfinding/step_field.gd")


## cell -> the steps from it to the nearest of `goals` (0 at a goal), for every cell within
## `most_steps` of one. `links`: Callable(cell) -> Array of the cells linked to it; the field
## is walked backwards from the goals, so a link is taken to go both ways. `blocked`:
## [from cell, to cell] -> true, steps one cannot take (no way through there).
static func measure(goals: Array, links: Callable, most_steps: int, blocked: Dictionary = {}) -> Dictionary:
	var steps_from := {}
	var frontier: Array[Vector3i] = []
	for goal: Vector3i in goals:
		if not steps_from.has(goal):
			steps_from[goal] = 0
			frontier.append(goal)
	while not frontier.is_empty():
		var next_frontier: Array[Vector3i] = []
		for cell in frontier:
			var steps: int = steps_from[cell] + 1
			if steps > most_steps:
				continue
			for way: Vector3i in links.call(cell):
				# walked backwards from the goals: one goes from `way` to `cell`
				if not steps_from.has(way) and not blocked.has([way, cell]):
					steps_from[way] = steps
					next_frontier.append(way)
		frontier = next_frontier
	return steps_from


## The steps from `cell` to the nearest goal in `field` (measure), -1 when out of it.
static func steps_at(field: Dictionary, cell: Vector3i) -> int:
	return int(field.get(cell, -1))


## The cells of `ways` (in their order) with fewer steps to a goal than `cell` in `field`;
## empty when `cell` is a goal or out of the field.
static func downhill(field: Dictionary, cell: Vector3i, ways: Array) -> Array[Vector3i]:
	var lower: Array[Vector3i] = []
	var here := steps_at(field, cell)
	if here <= 0:
		return lower
	for way: Vector3i in ways:
		var steps := steps_at(field, way)
		if steps >= 0 and steps < here:
			lower.append(way)
	return lower
