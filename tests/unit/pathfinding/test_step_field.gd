extends RefCounted
## Unit tests of the step field (scripts/pathfinding/step_field.gd): the steps from every cell
## to the nearest goal, on small hand-made graphs.
##   tests/run_unit_tests.sh step_field

const StepField = preload("res://scripts/pathfinding/step_field.gd")
## The hand-drawn graphs of the route finder's tests (grid_links).
const Graphs = preload("res://tests/unit/pathfinding/test_cell_routes.gd")


func test_step_field_counts_steps_to_the_nearest_goal(test) -> void:
	var links := Graphs.grid_links([
		".....",
		".###.",
		".....",
	])
	var links_of := func(cell: Vector3i) -> Array: return links.get(cell, [])
	var field := StepField.measure([Vector3i(0, 0, 0), Vector3i(4, 0, 2)], links_of, 20)
	test.check(StepField.steps_at(field, Vector3i(0, 0, 0)) == 0, "een doel: 0")
	test.check(StepField.steps_at(field, Vector3i(2, 0, 0)) == 2, "2 stappen van het eerste doel")
	test.check(StepField.steps_at(field, Vector3i(2, 0, 2)) == 2, "2 stappen van het tweede doel")
	test.check(StepField.steps_at(field, Vector3i(2, 0, 1)) == -1, "een muur: buiten het veld")
	var short := StepField.measure([Vector3i(0, 0, 0)], links_of, 2)
	test.check(short.has(Vector3i(2, 0, 0)) and not short.has(Vector3i(3, 0, 0)), "niet verder dan het maximum")


func test_step_field_goes_round_a_blocked_step(test) -> void:
	var links := Graphs.grid_links([
		"...",
		"...",
	])
	var links_of := func(cell: Vector3i) -> Array: return links.get(cell, [])
	var goal := Vector3i(0, 0, 0)
	# from (1,0) straight to the goal is blocked: round by the second row
	var field := StepField.measure([goal], links_of, 20, {[Vector3i(1, 0, 0), goal]: true})
	test.check(StepField.steps_at(field, Vector3i(1, 0, 0)) == 3, "geblokkeerde stap: omweg van 3 (%d)" % StepField.steps_at(field, Vector3i(1, 0, 0)))
	var downhill := StepField.downhill(field, Vector3i(1, 0, 1), links_of.call(Vector3i(1, 0, 1)))
	test.check(downhill == ([Vector3i(0, 0, 1)] as Array[Vector3i]), "omlaag: alleen de cel dichter bij het doel")
	test.check(StepField.downhill(field, goal, links_of.call(goal)).is_empty(), "op het doel: nergens heen")


func test_step_field_edges(test) -> void:
	var links := Graphs.grid_links(["..."])
	var links_of := func(cell: Vector3i) -> Array: return links.get(cell, [])
	test.check(StepField.measure([], links_of, 5).is_empty(), "geen doelen: een leeg veld")
	var goal := Vector3i(0, 0, 0)
	var field := StepField.measure([goal, goal], links_of, 0)
	test.check(field.size() == 1 and StepField.steps_at(field, goal) == 0, "0 stappen: alleen het doel (ook dubbel genoemd)")
	test.check(StepField.steps_at(field, Vector3i(7, 0, 7)) == -1, "buiten het veld: -1")
	test.check(StepField.downhill(field, Vector3i(7, 0, 7), [goal]).is_empty(), "van buiten het veld: nergens heen")
	var whole := StepField.measure([goal], links_of, 9)
	test.check(StepField.downhill(whole, Vector3i(1, 0, 0), [Vector3i(2, 0, 0), goal, Vector3i(9, 0, 9)]) == ([goal] as Array[Vector3i]),
			"verder weg en buiten het veld vallen af")
