extends "res://tests/integration/support/town_test.gd"
## Far out the people and vehicles are blocks (scripts/world/far_boxes.gd): zoomed out (the
## arrival, 300 m in view) their own models are hidden and there is one block for each; zoomed
## in again their models are back and the blocks gone. The town with its traffic.
##   tests/run_integration_tests.sh far_boxes

## Metres in view from which everything is a block, and at which it is itself again.
const FAR_VIEW := 300.0
const NEAR_VIEW := 20.0


static func world_options() -> Dictionary:
	return {"traffic": true}


## The view held on the player with `view_size` metres in view, a few frames on so the
## blocks have followed.
func _look_from(view_size: float) -> void:
	hold_view(player.global_position, view_size)
	await frames(5)


## The vehicles that still drive (a wreck keeps its own model).
func _driving_vehicles() -> Array:
	return Vehicle.all_vehicles.filter(func(vehicle: Vehicle) -> bool: return not vehicle.crashed)


## Zoomed far out every pedestrian's own figure is hidden: they are blocks.
func test_far_away_people_are_blocks(test) -> void:
	await _look_from(FAR_VIEW)
	var boxes: Node = scene.get_node("VerreBlokjes")
	var people: Array = scene.get_node("Voetgangers").people()
	var hidden_people: int = people.filter(func(person: Node) -> bool: return person._drawn and not person._drawn.visible).size()
	print("ver: %d van %d voetgangers als blokje" % [hidden_people, people.size()])
	test.check(boxes.far and hidden_people == people.size() and people.size() > 0, "ver weg: voetgangers zijn blokjes")


## Zoomed far out every driving vehicle's own model is hidden: they are blocks.
func test_far_away_vehicles_are_blocks(test) -> void:
	await _look_from(FAR_VIEW)
	var vehicles := _driving_vehicles()
	var hidden_vehicles := vehicles.filter(func(vehicle: Vehicle) -> bool: return not vehicle._body.visible).size()
	print("ver: %d van %d voertuigen als blokje" % [hidden_vehicles, vehicles.size()])
	test.check(hidden_vehicles == vehicles.size() and vehicles.size() > 0, "ver weg: voertuigen zijn blokjes")


## Far out there is exactly one block per pedestrian and per driving vehicle.
func test_one_block_each(test) -> void:
	await _look_from(FAR_VIEW)
	var boxes: Node = scene.get_node("VerreBlokjes")
	var people_count: int = scene.get_node("Voetgangers").people().size()
	var vehicle_count := _driving_vehicles().size()
	print("blokjes %d + %d, voetgangers %d, voertuigen %d" % [boxes._people.multimesh.visible_instance_count,
		boxes._vehicles.multimesh.visible_instance_count, people_count, vehicle_count])
	test.check(boxes._people.multimesh.visible_instance_count == people_count and boxes._vehicles.multimesh.visible_instance_count == vehicle_count,
		"één blokje per voetganger en voertuig")


## Zoomed in again after being far: the real figures and models are back, the blocks gone.
func test_near_again_the_real_figures(test) -> void:
	await _look_from(FAR_VIEW)
	await _look_from(NEAR_VIEW)
	var boxes: Node = scene.get_node("VerreBlokjes")
	var walkers: Node = scene.get_node("Voetgangers")
	var shown_people: int = walkers.people().filter(func(person: Node) -> bool: return person._drawn and person._drawn.visible).size()
	var shown_vehicles := Vehicle.all_vehicles.filter(func(vehicle: Vehicle) -> bool: return vehicle._body.visible).size()
	test.check(not boxes.far and not boxes._people.visible and shown_people == walkers.people().size() and shown_vehicles == Vehicle.all_vehicles.size(),
		"dichtbij weer de echte figuren")
