extends RefCounted
## Unit tests of picking at random with a seed (scripts/common/random_pick.gd): one of some
## options by their weights, and a list in a random order.
##   tests/run_unit_tests.sh common

const RandomPick = preload("res://scripts/common/random_pick.gd")


func _seeded(seed_number: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	return random


func test_weighted_follows_the_weights(test) -> void:
	var random := _seeded(5)
	var counts := [0, 0, 0]
	for draw in 3000:
		counts[RandomPick.weighted(random, [1.0, 3.0, 0.0])] += 1
	test.check(counts[2] == 0, "gewicht 0: nooit gekozen")
	var share := float(counts[1]) / 3000.0
	test.check(share > 0.7 and share < 0.8, "driemaal zo zwaar: ~75%% (%.2f)" % share)


func test_weighted_edges(test) -> void:
	var random := _seeded(1)
	test.check(RandomPick.weighted(random, []) == -1, "geen opties: -1")
	test.check(RandomPick.weighted(random, [2.0]) == 0, "één optie: die")
	var all_zero := RandomPick.weighted(random, [0.0, 0.0])
	test.check(all_zero == 0 or all_zero == 1, "alles 0: toch een geldige keuze")


func test_shuffle_keeps_everything(test) -> void:
	var random := _seeded(9)
	var names: Array = ["a", "b", "c", "d", "e"]
	var orders := {}
	for round_number in 30:
		RandomPick.shuffle(random, names)
		var sorted_names := names.duplicate()
		sorted_names.sort()
		test.check(sorted_names == ["a", "b", "c", "d", "e"], "niets kwijt, niets dubbel")
		orders[str(names)] = true
	test.check(orders.size() > 5, "verschillende volgordes (%d)" % orders.size())


func test_shuffle_handles_typed_short_and_empty_lists(test) -> void:
	var random := _seeded(3)
	var none: Array = []
	RandomPick.shuffle(random, none)
	test.check(none.is_empty(), "leeg blijft leeg")
	var one: Array[Vector3i] = [Vector3i(4, 0, 2)]
	RandomPick.shuffle(random, one)
	test.check(one == [Vector3i(4, 0, 2)], "één ding blijft staan")
	var cells: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	RandomPick.shuffle(random, cells)
	test.check(cells.size() == 3 and cells.has(Vector3i(0, 0, 0)) and cells.has(Vector3i(1, 0, 0)) and cells.has(Vector3i(2, 0, 0)), "een getypeerde lijst: alles nog aanwezig")


func test_the_same_seed_gives_the_same_picks(test) -> void:
	var first: Array = range(20)
	var second: Array = range(20)
	RandomPick.shuffle(_seeded(42), first)
	RandomPick.shuffle(_seeded(42), second)
	test.check(first == second, "zelfde seed: zelfde volgorde")
	var other: Array = range(20)
	RandomPick.shuffle(_seeded(43), other)
	test.check(other != first, "andere seed: andere volgorde")
	test.check(RandomPick.weighted(_seeded(7), [1.0, 1.0, 1.0, 1.0]) == RandomPick.weighted(_seeded(7), [1.0, 1.0, 1.0, 1.0]), "zelfde seed: zelfde gewogen keuze")
