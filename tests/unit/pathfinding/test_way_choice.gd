extends RefCounted
## Unit tests of choosing a way (scripts/pathfinding/way_choice.gd), shared by people and
## vehicles.
##   tests/run_unit_tests.sh way_choice

const WayChoice = preload("res://scripts/pathfinding/way_choice.gd")


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
