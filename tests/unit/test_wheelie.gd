extends RefCounted
## Unit tests of Wheelie (scripts/vehicles/wheelie.gd): the front up on the rear wheel now and
## then, down again when it may not, the rear wheel's contact point staying where it is.

const Wheelie = preload("res://scripts/vehicles/wheelie.gd")


func _forced(most_degrees: float) -> Wheelie:
	var wheelie := Wheelie.new(deg_to_rad(most_degrees), 1)
	wheelie._up_left = 5.0
	wheelie._height = wheelie.most_angle
	return wheelie


func test_the_front_comes_up_and_down_again(test) -> void:
	var wheelie := _forced(30.0)
	for step in 60:
		wheelie.step(1.0 / 60.0, true)
	test.check(wheelie.angle > deg_to_rad(20.0), "voorkant omhoog (%.1f graden)" % rad_to_deg(wheelie.angle))
	for step in 120:
		wheelie.step(1.0 / 60.0, false)
	test.check(wheelie.angle < deg_to_rad(1.0), "niet meer mogen: weer neer (%.2f graden)" % rad_to_deg(wheelie.angle))


func test_the_rear_contact_stays_put(test) -> void:
	var wheelie := _forced(30.0)
	for step in 60:
		wheelie.step(1.0 / 60.0, true)
	var pivot := Vector3(0.0, 0.0, -0.6)
	var turned := wheelie.tilt_about(pivot)
	test.check((turned * pivot).distance_to(pivot) < 0.0001, "het achterwiel blijft op zijn plek")
	test.check((turned * Vector3(0.0, 0.0, 0.6)).y > 0.3, "het voorwiel gaat omhoog")


func test_stop_ends_it_at_once(test) -> void:
	var wheelie := _forced(30.0)
	for step in 30:
		wheelie.step(1.0 / 60.0, true)
	wheelie.stop()
	test.check(wheelie.angle == 0.0 and not wheelie.is_up(), "meteen plat")


func test_it_happens_now_and_then(test) -> void:
	var wheelie := Wheelie.new(deg_to_rad(30.0), 2)
	var started := 0
	for step in 60 * 60 * 10:
		if wheelie.step(1.0 / 60.0, true):
			started += 1
	test.check(started >= 3 and started <= 40, "af en toe: %d keer in 10 minuten" % started)
