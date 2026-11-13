extends "res://tests/integration/support/town_test.gd"
## Two-wheelers going down (scripts/vehicles/two_wheeler.gd, _become_wreck): a moped, a
## cyclist and a motorbike are hit hard from the side. Each wreck must tip over onto its
## side, the rider must come off (a body of their own, away from the vehicle), a bicycle
## must not burn, and once towed the rider sits on it again.
##   tests/run_integration_tests.sh two_wheeler_fall

const START_CELL := Vector2i(150, 20)
## Tipped over: its up axis at least this many degrees off the vertical.
const DOWN_DEGREES := 55.0
## The town's own two cars, kept still meanwhile so they cannot drive into the scene.
const TOWN_CARS := ["Auto", "SUV"]


## The town's own cars standing still (`still`) or driving on again.
func _hold_town_cars(still: bool) -> void:
	for car_name: String in TOWN_CARS:
		if scene.has_node(car_name):
			scene.get_node(car_name).process_mode = Node.PROCESS_MODE_DISABLED if still else Node.PROCESS_MODE_INHERIT


## A two-wheeler of `script_path` put on the road, hit from the side at speed and set on
## fire, then towed: checks how it and its rider end up.
func _crash_and_tow(test, script_path: String) -> void:
	_hold_town_cars(true)
	var rider: TwoWheeler = load(script_path).new()
	rider.start_cell = START_CELL
	rider.start_heading = Vector2i(-1, 0)
	scene.add_child(rider)
	var name_of := script_path.get_file().get_basename()
	for wait in 30:
		await tree.physics_frame
	# hit from the side at speed, as by a car coming out of a side street (the crash itself,
	# Vehicle._crash_with, is the same for every vehicle: this is about what follows)
	rider.velocity = rider.global_basis.z * 6.0
	rider._become_wreck(rider.velocity * 0.4 + Vector3(0.0, 0.0, 3.0), 0.6, Vector3(0.0, 0.0, 1.0), 9.0)
	rider._catch_fire()
	test.check(rider.crashed, "%s: neergehaald" % name_of)
	for wait in 150:
		tree.paused = false   # nothing may hold the town still (a story page, a death screen)
		await tree.physics_frame
	var up := rider._wreck.global_basis.y.normalized()
	var off_vertical := rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
	var thrown: RigidBody3D = rider._thrown_rider
	var apart := thrown.global_position.distance_to(rider._wreck.global_position) if thrown else 0.0
	print("  %s: %.0f graden om, berijder %.1f m van het voertuig, brand %s" % [name_of, off_vertical, apart, rider._fire != null])
	test.check(off_vertical > DOWN_DEGREES, "%s: op zijn kant (%.0f graden)" % [name_of, off_vertical])
	test.check(thrown != null and rider._rider.get_parent() == thrown, "%s: de berijder eraf, een lichaam apart" % name_of)
	if thrown:
		var shape_size: Vector3 = (thrown.get_child(0) as CollisionShape3D).shape.size if thrown.get_child(0) is CollisionShape3D else Vector3.ZERO
		var mesh_size := Vehicle._mesh_bounds(rider._rider).size
		print("  %s: botsvorm berijder %s, mesh %s" % [name_of, shape_size.snapped(Vector3.ONE * 0.01), mesh_size.snapped(Vector3.ONE * 0.01)])
	for child in rider._wreck.get_children():
		if child is CollisionShape3D:
			print("  %s: botsvorm wrak %s, mesh voertuig %s" % [name_of, (child.shape.size as Vector3).snapped(Vector3.ONE * 0.01),
					Vehicle._mesh_bounds(rider._body).size.snapped(Vector3.ONE * 0.01)])
	test.check(apart > 0.6, "%s: de berijder ligt los van het voertuig (%.1f m)" % [name_of, apart])
	if rider.bicycle:
		test.check(rider._fire == null, "%s: een fiets brandt niet" % name_of)
	rider._tow()
	await tree.physics_frame
	test.check(not rider.crashed and rider._rider.get_parent() == rider._body, "%s: weggesleept, de berijder weer erop" % name_of)
	rider.queue_free()
	await tree.physics_frame
	_hold_town_cars(false)


## A moped hit from the side: on its side, the rider off and apart, back on once towed.
func test_moped_falls_and_rider_comes_off(test) -> void:
	await _crash_and_tow(test, "res://scripts/vehicles/moped.gd")


## A cyclist hit from the side: as the moped, and the bicycle does not burn.
func test_cyclist_falls_and_bicycle_does_not_burn(test) -> void:
	await _crash_and_tow(test, "res://scripts/vehicles/cyclist.gd")


## A motorbike hit from the side: on its side, the rider off and apart, back on once towed.
func test_motorbike_falls_and_rider_comes_off(test) -> void:
	await _crash_and_tow(test, "res://scripts/vehicles/motorbike.gd")
