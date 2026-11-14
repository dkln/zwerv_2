extends RefCounted
## Unit tests of the memory of cells gone over (scripts/pathfinding/visit_memory.gd): counts
## per cell that fade once it holds too many.
##   tests/run_unit_tests.sh visit_memory

const VisitMemory = preload("res://scripts/pathfinding/visit_memory.gd")


func test_visit_memory_counts_and_fades(test) -> void:
	var memory := VisitMemory.new(3)
	var a := Vector3i(0, 0, 0)
	memory.remember(a)
	memory.remember(a)
	memory.remember(a)
	memory.remember(Vector3i(1, 0, 0))
	test.check(memory.times(a) == 3 and memory.times(Vector3i(9, 0, 9)) == 0, "telt per cel")
	test.check(is_equal_approx(memory.average([a, Vector3i(1, 0, 0)], 4), 1.0), "gemiddelde over 4 cellen: (3+1)/4")
	test.check(memory.average([a], 0) == 0.0, "over 0 cellen: 0")
	memory.remember(Vector3i(2, 0, 0))
	memory.remember(Vector3i(3, 0, 0))   # a fourth cell: more than 3, all halved
	test.check(memory.times(a) == 1, "gehalveerd (%d)" % memory.times(a))
	test.check(memory.size() == 1, "de cellen op 0 vergeten (%d)" % memory.size())
	memory.clear()
	test.check(memory.size() == 0, "leeg na clear")


func test_visit_memory_keeps_a_thousand_cells_by_default(test) -> void:
	var memory := VisitMemory.new()
	test.check(memory.most_cells == 1000, "standaard 1000 cellen")
	for column in 1000:
		memory.remember(Vector3i(column, 0, 0))
	memory.remember(Vector3i(0, 0, 0))
	test.check(memory.size() == 1000 and memory.times(Vector3i(0, 0, 0)) == 2, "tot en met 1000 cellen: niets vervaagt")
	memory.remember(Vector3i(5000, 0, 0))
	test.check(memory.size() == 1 and memory.times(Vector3i(0, 0, 0)) == 1, "de 1001e: alles gehalveerd, wat op 0 komt vergeten")
