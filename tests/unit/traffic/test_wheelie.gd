extends RefCounted
## Unit tests of Wheelie (scripts/vehicles/wheelie.gd): the front up on the rear wheel now and
## then, down again when it may not, the rear wheel's contact point staying where it is.
##   tests/run_unit_tests.sh test_wheelie

const Wheelie = preload("res://scripts/vehicles/wheelie.gd")


func _forced(most_degrees: float) -> Wheelie:
	var wheelie := Wheelie.new(deg_to_rad(most_degrees), 1)
	wheelie._up_left = 5.0
	wheelie._height = wheelie.most_angle
	return wheelie


## The front comes up in a wheelie, and down again once it may not.
func test_the_front_comes_up_and_down_again(test) -> void:
	var wheelie := _forced(30.0)
	for step in 60:
		wheelie.step(1.0 / 60.0, true)
	test.check(wheelie.angle > deg_to_rad(20.0), "voorkant omhoog (%.1f graden)" % rad_to_deg(wheelie.angle))
	for step in 120:
		wheelie.step(1.0 / 60.0, false)
	test.check(wheelie.angle < deg_to_rad(1.0), "niet meer mogen: weer neer (%.2f graden)" % rad_to_deg(wheelie.angle))


## In a wheelie the rear wheel's contact point stays where it is while the front rises.
func test_the_rear_contact_stays_put(test) -> void:
	var wheelie := _forced(30.0)
	for step in 60:
		wheelie.step(1.0 / 60.0, true)
	var pivot := Vector3(0.0, 0.0, -0.6)
	var turned := wheelie.tilt_about(pivot)
	test.check((turned * pivot).distance_to(pivot) < 0.0001, "het achterwiel blijft op zijn plek")
	test.check((turned * Vector3(0.0, 0.0, 0.6)).y > 0.3, "het voorwiel gaat omhoog")


## stop() puts the vehicle flat at once.
func test_stop_ends_it_at_once(test) -> void:
	var wheelie := _forced(30.0)
	for step in 30:
		wheelie.step(1.0 / 60.0, true)
	wheelie.stop()
	test.check(wheelie.angle == 0.0 and not wheelie.is_up(), "meteen plat")


## Left to chance a wheelie happens now and then: a few times in ten minutes.
func test_it_happens_now_and_then(test) -> void:
	var wheelie := Wheelie.new(deg_to_rad(30.0), 2)
	var started := 0
	for step in 60 * 60 * 10:
		if wheelie.step(1.0 / 60.0, true):
			started += 1
	test.check(started >= 3 and started <= 40, "af en toe: %d keer in 10 minuten" % started)


## Nothing starts while it may not, and a wheelie is cut short when it may no more.
func test_no_wheelie_while_not_allowed(test) -> void:
	var wheelie := Wheelie.new(deg_to_rad(30.0), 3)
	var started := 0
	for step in 60 * 60 * 5:
		if wheelie.step(1.0 / 60.0, false):
			started += 1
	test.check(started == 0 and not wheelie.is_up() and wheelie.angle == 0.0, "niet mogen: vijf minuten lang niets")
	var forced := _forced(30.0)
	forced.step(1.0 / 60.0, true)
	test.check(forced.is_up(), "bezig: omhoog")
	forced.step(1.0 / 60.0, false)
	test.check(forced._up_left == 0.0 and forced._bounce >= 0.0, "afgebroken: de landing begint")


## The same seed gives the same wheelies: every step the same angle as the sums of the
## rules give with the same draws in the same order (the chance, the seconds, the height).
func test_the_same_seed_gives_the_same_wheelies(test) -> void:
	var delta := 1.0 / 60.0
	var wheelie := Wheelie.new(deg_to_rad(28.0), 7)
	var draws := RandomNumberGenerator.new()
	draws.seed = 7 * 31 + 17
	var angle := 0.0
	var height := 0.0
	var up_left := 0.0
	var clock := 0.0
	var bounce := -1.0
	var same := true
	var started := 0
	for step in 60 * 60 * 10:
		var allowed := step % 1500 < 1300   # now and then a bend
		var began := false
		clock += delta
		if up_left > 0.0:
			up_left -= delta
			if not allowed:
				up_left = 0.0
			if up_left <= 0.0:
				bounce = 0.0
		elif allowed and angle < 0.01 and draws.randf() < delta / 45.0:
			up_left = draws.randf_range(4.0, 7.0)
			height = deg_to_rad(28.0) * draws.randf_range(0.9, 1.0)
			began = true
		if up_left > 0.0:
			angle = lerpf(angle, height * (1.0 + 0.12 * sin(clock * 6.0)), 1.0 - exp(-5.0 * delta))
		else:
			angle = lerpf(angle, 0.0, 1.0 - exp(-7.0 * delta))
			if bounce >= 0.0:
				bounce += delta
				var spring := absf(sin(bounce * 14.0)) * exp(-bounce * 9.0) * 0.18 * height
				if angle < 0.02:
					angle = maxf(angle, spring)
				if bounce > 0.8:
					bounce = -1.0
		var stepped := wheelie.step(delta, allowed)
		started += 1 if stepped else 0
		same = same and stepped == began and wheelie.angle == angle
	test.check(same, "tien minuten lang elke stap dezelfde hoek en hetzelfde begin")
	test.check(started >= 3, "en er waren wheelies bij (%d)" % started)
	test.check(Wheelie.MEAN_PAUSE == 45.0 and Wheelie.UP_SECONDS == Vector2(4.0, 7.0) and Wheelie.RISE_RATE == 5.0 and Wheelie.DROP_RATE == 7.0, "de getallen onder hun oude naam")
	test.check(Wheelie.WOBBLE_SHARE == 0.12 and Wheelie.WOBBLE_SPEED == 6.0 and Wheelie.BOUNCE_SHARE == 0.18 and Wheelie.BOUNCE_DAMPING == 9.0, "ook de wiebel en de stuit")
