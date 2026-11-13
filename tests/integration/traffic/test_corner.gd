extends "res://tests/integration/support/town_test.gd"
## Every square road corner of the city (tools/voxgen/tiles/ground_corners.py): a lane
## leads into it where the tile is entered, one lane leads on where it comes out, and it
## is not taken for a crossing.
##   tests/run_integration_tests.sh corner


## The road network of the town and its corner cells (tiles named "..._hoek_...").
func _corners() -> Dictionary:
	var network := RoadNetwork.of(scene)
	var cells: Array[Vector3i] = []
	for cell: Vector3i in network.cells():
		if network.tile_name(cell).contains("_hoek_"):
			cells.append(cell)
	return {"network": network, "cells": cells}


## Checks that the town has corners and that `problem_of` (network, cell -> "" or what is
## wrong) finds nothing wrong with any of them; `what` names the check.
func _check_every_corner(test, what: String, problem_of: Callable) -> void:
	var corners := _corners()
	var network: RoadNetwork = corners.network
	var problems := 0
	for cell: Vector3i in corners.cells:
		var problem: String = problem_of.call(network, cell)
		if problem != "":
			problems += 1
			print("FAIL ", cell, " ", network.tile_name(cell), ": ", problem)
	test.check(not (corners.cells as Array).is_empty(), "de stad heeft hoeken (%d)" % corners.cells.size())
	test.check(problems == 0, "%s (%d hoeken, %d fout)" % [what, corners.cells.size(), problems])


## A corner has exactly one lane: the one it leaves by.
func test_a_corner_has_one_lane(test) -> void:
	_check_every_corner(test, "elke hoek heeft één rijrichting", func(network: RoadNetwork, cell: Vector3i) -> String:
		var lane_count := network.lanes(cell).size()
		return "" if lane_count == 1 else "has %d lanes" % lane_count)


## A corner is not taken for a crossing.
func test_a_corner_is_not_a_crossing(test) -> void:
	_check_every_corner(test, "geen hoek telt als kruising", func(network: RoadNetwork, cell: Vector3i) -> String:
		return "counts as a crossing" if network.is_crossing(cell) else "")


## A lane leads into the corner on the side where the tile is entered.
func test_a_lane_leads_into_every_corner(test) -> void:
	_check_every_corner(test, "naar elke hoek leidt een rijstrook", func(network: RoadNetwork, cell: Vector3i) -> String:
		var entering := network.heading_of_side(cell, "N")
		var before := network.step(cell, -entering)
		if before == RoadNetwork.NONE or not network.lanes(before).has(entering):
			return "no lane leads into it, heading %s" % entering
		return "")


## A lane leads on from the corner the way it comes out.
func test_a_lane_leads_on_from_every_corner(test) -> void:
	_check_every_corner(test, "uit elke hoek leidt een rijstrook verder", func(network: RoadNetwork, cell: Vector3i) -> String:
		var leaving: Array[Vector2i] = network.lanes(cell)
		if leaving.size() != 1:
			return ""   # (test_a_corner_has_one_lane reports that)
		var after := network.step(cell, leaving[0])
		if after == RoadNetwork.NONE or not network.lanes(after).has(leaving[0]):
			return "no lane leads on, heading %s" % leaving[0]
		return "")
