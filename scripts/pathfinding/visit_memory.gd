extends RefCounted
## How often someone went over each cell, fading: once it holds more than `most_cells` cells
## every count is halved (and the ones at 0 forgotten). Who chooses a way can then go where it
## went least (Vehicle: so it does not drive the same few blocks round and round).
##   const VisitMemory = preload("res://scripts/pathfinding/visit_memory.gd")

var most_cells: int
var _counts := {}              # cell -> times gone over


func _init(cells_kept := 1000) -> void:
	most_cells = cells_kept


## Counts once more that it went over `cell`.
func remember(cell: Vector3i) -> void:
	_counts[cell] = int(_counts.get(cell, 0)) + 1
	if _counts.size() > most_cells:
		for key: Vector3i in _counts.keys():
			_counts[key] = int(_counts[key]) / 2
			if _counts[key] == 0:
				_counts.erase(key)


## How often it went over `cell` (as remembered now).
func times(cell: Vector3i) -> int:
	return int(_counts.get(cell, 0))


## The average of times() over `cells`, counted as `out_of` cells (0 if `out_of` is 0).
func average(cells: Array, out_of: int) -> float:
	if out_of <= 0:
		return 0.0
	var total := 0.0
	for cell: Vector3i in cells:
		total += times(cell)
	return total / out_of


## How many cells it remembers.
func size() -> int:
	return _counts.size()


func clear() -> void:
	_counts.clear()
