extends "res://tests/integration/support/town_test.gd"
## The city hall on the Spui (scripts/world/interiors/city_hall.gd, Interiors KINDS "stadhuis"): the doors
## in the ground floor of its two white slabs are ways in (out again where you came in); inside
## you are on floor 0 by the entrance (only that floor shown), the reception staffed; at the
## lift [E] Lift asks which floor; the ride is a scene of its own (the cabin, the camera from
## the front, close in, you in it, the motor humming, the display showing the floor the lift
## is at); out at that floor (the floor shown, you before its doors, the doors open, the
## minimap the plan of that floor, the people of that floor there: Burgerzaken its civil
## servants at the counters, the council chamber its mayor); a number from the machine; back
## down and out of the door. The plans themselves: tests/unit/interiors/test_city_hall_layout.gd.
##   tests/run_integration_tests.sh city_hall

const Layout = preload("res://scripts/world/interiors/city_hall_layout.gd")


## Into the city hall through its last door, at once; returns the hall (null if that failed).
func _into_the_hall() -> Node3D:
	await enter("stadhuis", -1)
	var hall: Node3D = interiors._interior
	return hall if hall != null and hall.has_method("ride") else null


## The people (InteriorPerson) of `floor_node` with `role`.
static func _people_with_role(floor_node: Node3D, role: String) -> Array:
	return floor_node.get_children().filter(func(node: Node) -> bool: return node is InteriorPerson and node.role == role)


## The lift to floor `number` (at once), and what should be true there: only that floor
## shown, the player free before the lift, its doors open, the minimap that floor's plan,
## and the people that belong there.
func _ride_and_check(test, hall: Node3D, number: int) -> void:
	hall.ride(number, false)
	for step_index in 6:
		await tree.physics_frame
	var floor_node: Node3D = hall.floor_node(number)
	var lift: Node3D = floor_node.get_node("Lift")
	var others_hidden := true
	for floor_index in hall.floor_count():
		if floor_index != number and hall.floor_node(floor_index).visible:
			others_hidden = false
	print("etage %d (%s): %d mensen" % [number, Layout.NAMES[number],
		floor_node.get_children().filter(func(node: Node) -> bool: return node is InteriorPerson).size()])
	test.check(hall.current_floor == number and floor_node.visible and others_hidden, "  de lift naar etage %d: alleen die te zien" % number)
	test.check(player.global_position.distance_to(lift.global_position) < 0.6, "  de speler voor de lift")
	test.check(player._fits(player.global_position), "  daar staat de speler vrij")
	test.check(hall.doors_open(number), "  de liftdeuren open")
	test.check(hall.plan_root() == floor_node, "  het kaartje toont deze etage")
	match number:
		1:
			var at_counters := _people_with_role(floor_node, "ambtenaar").filter(func(person: Node) -> bool: return person.sitting)
			test.check(at_counters.size() == 4, "  ambtenaren achter de vier loketten (%d)" % at_counters.size())
		2:
			var at_desks := _people_with_role(floor_node, "ambtenaar")
			test.check(at_desks.size() >= 12, "  de kantoortuin bemand (%d)" % at_desks.size())
		4:
			test.check(not _people_with_role(floor_node, "burgemeester").is_empty(), "  de burgemeester in de raadzaal")


## The doors of the two white slabs are ways in, and at one the HUD offers [E] Naar binnen,
## which takes you into the city hall.
func test_in_through_a_door_of_the_slabs(test) -> void:
	var ways_in: Array = interiors.ways_in().filter(func(way_in: Dictionary) -> bool: return way_in.kind == "stadhuis")
	test.check(ways_in.size() >= 2, "ingangen van het stadhuis: de deuren van de twee witte schijven (%d)" % ways_in.size())
	if ways_in.is_empty():
		return
	var way_in: Dictionary = ways_in[-1]
	var places: Dictionary = scene.get_meta("places")
	print("ingang %s, het stadhuis op de kaart %s" % [(way_in.door as Vector3).snapped(Vector3.ONE * 0.1), places.get("stadhuis")])
	await stand_at(way_in.door)
	test.check(prompts() == [["E", "Naar binnen"]], "bij de deur: [E] Naar binnen")
	await use_door()
	var hall: Node3D = interiors._interior
	test.check(interiors.is_inside() and hall != null and hall.has_method("ride"), "binnen in het stadhuis")


## Inside you stand free by the entrance on the ground floor, only that floor shown, two
## receptionists behind the desk and a guard by the door.
func test_ground_floor_by_the_entrance_with_reception(test) -> void:
	var hall := await _into_the_hall()
	test.check(hall != null, "binnen in het stadhuis")
	if hall == null:
		return
	test.check(hall.current_floor == 0 and hall.floor_node(0).visible and not hall.floor_node(1).visible, "op de begane grond, alleen die te zien")
	test.check(player.global_position.distance_to(hall.to_global(Vector3(0.0, 0.0, -13.1))) < 1.5, "binnen bij de ingang")
	var receptionists: Array = hall.people().filter(func(person: Node) -> bool: return person.role == "receptioniste")
	test.check(receptionists.size() == 2, "twee receptionistes achter de balie (%d)" % receptionists.size())
	test.check(hall.people().any(func(person: Node) -> bool: return person.role == "beveiliger"), "een beveiliger bij de deur")
	test.check(player._fits(player.global_position), "binnen staat de speler vrij")


## At the lift the HUD offers [E] Lift, and using it asks which of the five floors.
func test_lift_asks_which_floor(test) -> void:
	var hall := await _into_the_hall()
	test.check(hall != null, "binnen in het stadhuis")
	if hall == null:
		return
	await stand_at((hall.floor_node(0).get_node("Lift") as Node3D).global_position)
	test.check(prompts() == [["E", "Lift"]], "bij de lift: [E] Lift (%s)" % [prompts()])
	use_prompt()
	await frames(1)
	var box: Control = hud._story_box
	test.check(box.is_showing() and box._current_choices().size() == 5, "de lift vraagt welke etage (5 keuzes)")
	print("  ", box._current_choices())
	# the question away without choosing a floor
	box.hide()
	box._pages = []
	tree.paused = false


## The ride as it goes: a scene of its own with the lift's camera close in from the front,
## a stand-in of you in the cabin, the motor humming, the display counting the floors; then
## out at the floor with the usual camera back and the motor still.
func test_ride_is_a_scene_of_its_own(test) -> void:
	var hall := await _into_the_hall()
	test.check(hall != null, "binnen in het stadhuis")
	if hall == null:
		return
	var cabin: Node3D = hall.lift()
	var camera_before := tree.root.get_viewport().get_camera_3d()
	hall.ride(2, true)
	await wait_until(func() -> bool: return hall.in_cabin(), 3.0)
	await seconds(0.6)
	var camera := tree.root.get_viewport().get_camera_3d()
	test.check(hall.in_cabin() and cabin.visible, "in de lift: de liftscène")
	test.check(camera != null and camera.name == "Liftcamera", "met de camera van de lift (%s)" % (camera.name if camera else "geen"))
	test.check(cabin.has_node("Speler") and not player.visible, "jij in de lift (een stand-in), de echte speler weg")
	if camera and cabin.has_node("Speler"):
		var to_player := (cabin.get_node("Speler") as Node3D).global_position - camera.global_position
		test.check(to_player.length() < 3.0 and camera.global_basis.z.dot(Vector3(0.0, 0.0, 1.0)) < -0.8,
			"ingezoomd, van voren (%.1f m)" % to_player.length())
	await wait_until(func() -> bool: return hall.motor_running(), 2.0)
	test.check(hall.motor_running(), "de liftmotor zoemt (zodra de swipe weg is)")
	var seen := {}
	await wait_until(func() -> bool:
		seen[hall.display_text()] = true
		return not hall.is_riding(), 8.0)
	print("  display onderweg: ", seen.keys())
	test.check(seen.has("▲ 0") and seen.has("▲ 1") and seen.has("2"), "het display toont waar de lift is: ▲ 0, ▲ 1, 2")
	test.check(not hall.in_cabin() and hall.current_floor == 2 and player.visible, "uitgestapt op etage 2")
	test.check(tree.root.get_viewport().get_camera_3d() == camera_before, "de gewone camera weer")
	test.check(not hall.motor_running(), "de motor stil")


## Every floor the lift goes to: only that floor shown, the player free before the open
## lift doors, the minimap that floor's plan, and its people there (the civil servants at
## the counters of Burgerzaken, the open-plan office staffed, the mayor in the council chamber).
func test_every_floor_is_shown_with_its_people(test) -> void:
	var hall := await _into_the_hall()
	test.check(hall != null, "binnen in het stadhuis")
	if hall == null:
		return
	for floor_number: int in [2, 1, 4, 2, 3, 0]:
		await _ride_and_check(test, hall, floor_number)


## At Burgerzaken (floor 1) the number machine offers [E] Nummertje trekken and gives a number.
func test_taking_a_number_at_burgerzaken(test) -> void:
	var hall := await _into_the_hall()
	test.check(hall != null, "binnen in het stadhuis")
	if hall == null:
		return
	await _ride_and_check(test, hall, 1)
	await stand_at((hall.floor_node(1).get_node("Nummerautomaat") as Node3D).global_position)
	test.check(prompts() == [["E", "Nummertje trekken"]], "bij de automaat: [E] Nummertje trekken")
	use_prompt()
	test.check(hall.number_taken() > 0, "een nummertje: B %03d" % hall.number_taken())


## Back on the ground floor after a ride, the door inside offers [E] Naar buiten and puts
## you outside where you came in.
func test_down_again_and_out_of_the_door(test) -> void:
	var way_in: Dictionary = await enter("stadhuis", -1)
	var hall: Node3D = interiors._interior
	test.check(hall != null and hall.has_method("ride"), "binnen in het stadhuis")
	if hall == null or not hall.has_method("ride"):
		return
	await _ride_and_check(test, hall, 1)
	await _ride_and_check(test, hall, 0)
	await stand_at((hall.get_node("Deur") as Node3D).global_position)
	test.check(prompts() == [["E", "Naar buiten"]], "bij de deur binnen: [E] Naar buiten")
	await use_door()
	test.check(not interiors.is_inside() and player.global_position.distance_to(way_in.door) < 2.0, "weer buiten op het Spui")
