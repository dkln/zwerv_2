extends RefCounted
## Unit tests of choosing a way (scripts/pathfinding/way_choice.gd) and the memory of cells
## gone over (visit_memory.gd), shared by people and vehicles.
##   tests/run_unit_tests.sh pathfinding

const WayChoice = preload("res://scripts/pathfinding/way_choice.gd")
const VisitMemory = preload("res://scripts/pathfinding/visit_memory.gd")


func test_weighted_follows_the_weights(test) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 5
	var counts := [0, 0, 0]
	for draw in 3000:
		counts[WayChoice.weighted(random, [1.0, 3.0, 0.0])] += 1
	test.check(counts[2] == 0, "gewicht 0: nooit gekozen")
	var share := float(counts[1]) / 3000.0
	test.check(share > 0.7 and share < 0.8, "driemaal zo zwaar: ~75%% (%.2f)" % share)


func test_weighted_edges(test) -> void:
	var random := RandomNumberGenerator.new()
	test.check(WayChoice.weighted(random, []) == -1, "geen opties: -1")
	test.check(WayChoice.weighted(random, [2.0]) == 0, "één optie: die")
	random.seed = 1
	var all_zero := WayChoice.weighted(random, [0.0, 0.0])
	test.check(all_zero == 0 or all_zero == 1, "alles 0: toch een geldige keuze")


func test_shuffle_keeps_everything(test) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 9
	var cells: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)]
	var before := cells.duplicate()
	var orders := {}
	for round_number in 30:
		WayChoice.shuffle(random, cells)
		test.check(cells.size() == 4 and before.all(func(cell: Vector3i) -> bool: return cells.has(cell)), "niets kwijt, niets dubbel")
		orders[str(cells)] = true
	test.check(orders.size() > 5, "verschillende volgordes (%d)" % orders.size())


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
