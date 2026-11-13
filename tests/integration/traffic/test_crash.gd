extends "res://tests/integration/support/town_test.gd"
## A heavy and a light vehicle run head on into each other on an empty stretch of the A12
## (no other traffic): what the hit does goes by their weights (the health each loses, which
## one is only bumped and which one becomes a wreck: on fire, or blown up), and the wreck
## is towed back, as good as new, once it has burnt out. Prints the blows.
##   tests/run_integration_tests.sh crash

const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const VehicleFireTime: float = preload("res://scripts/effects/vehicle_fire.gd").BURN_SECONDS
const START_CELL := Vector2i(150, 20)
## Game seconds the two drive before one is sent into the other, and the most the hit may take.
const RUN_UP_SECONDS := 6.0
const HIT_WITHIN_SECONDS := 34.0


## A city bus and a hatchback on the A12; the heavy one sent into the light one
## (`sent_heavy`) or the other way round. Checks that one of them ends as a wreck and that
## it is towed away once it has burnt out.
func _head_on(test, sent_heavy: bool) -> void:
	var heavy := TrafficHelp.new_vehicle("city_bus", START_CELL, Vector2i(-1, 0))
	var light := TrafficHelp.new_vehicle("hatchback", START_CELL, Vector2i(-1, 0))
	var target := light if sent_heavy else heavy
	var sent := heavy if sent_heavy else light
	sent.start_cell = START_CELL + Vector2i(0, 10)
	scene.add_child(heavy)
	scene.add_child(light)
	var elapsed := 0.0
	while elapsed < RUN_UP_SECONDS:
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
	print("DBG before: sent %s speed %.1f route %d reckless %s | target %s speed %.1f route %d unseen %s" % [sent.global_position, sent.speed, sent._route_cells.size(), sent.reckless, target.global_position, target.speed, target._route_cells.size(), target.unseen])
	sent.drive_into(target)
	print("DBG after: sent %s speed %.1f route %d reckless %s" % [sent.global_position, sent.speed, sent._route_cells.size(), sent.reckless])
	var heavy_health := heavy.health
	var light_health := light.health
	while not heavy.crashed and not light.crashed and elapsed < RUN_UP_SECONDS + HIT_WITHIN_SECONDS:
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
		if int(elapsed * 60) % 180 == 0:
			print("DBG %.1f sent %s v %.1f target %s v %.1f" % [elapsed, sent.global_position, sent.speed, target.global_position, target.speed])
		if heavy.health < heavy_health or light.health < light_health:
			print("klap: zwaar %.0f -> %.0f HP, licht %.0f -> %.0f HP" % [heavy_health, heavy.health, light_health, light.health])
			heavy_health = heavy.health
			light_health = light.health
	test.check(heavy.crashed or light.crashed, "de botsing geeft een wrak (niet alleen tikken, of geen botsing)")
	if heavy.crashed or light.crashed:
		# the one whose health ran out is a wreck (on fire, or blown up); the other was bumped
		for vehicle: Vehicle in [heavy, light]:
			var role := "zwaar" if vehicle == heavy else "licht"
			if vehicle.crashed:
				print("%s %.0f kg: wrak, %.0f HP, brand: %s, ontploft: %s, wrak %.1f m/s" % [role, vehicle.total_mass(), vehicle.health,
						vehicle._fire != null, vehicle.health <= Vehicle.EXPLODE_HEALTH, vehicle._wreck.linear_velocity.length()])
			else:
				print("%s %.0f kg: getikt, %.0f HP, %.1f m/s" % [role, vehicle.total_mass(), vehicle.health, vehicle.velocity.length()])
		var burning: Vehicle = heavy if heavy.crashed else light
		var burnt_out := elapsed + VehicleFireTime + 1.0
		while elapsed < burnt_out and burning.crashed:
			await tree.physics_frame
			elapsed += TrafficHelp.STEP
		test.check(not burning.crashed, "na de brand weggesleept (%.0f HP)" % burning.health)
	heavy.queue_free()
	light.queue_free()
	await frames(2)


## The bus sent into the hatchback: a wreck, towed away after the fire.
func test_heavy_runs_into_light(test) -> void:
	await _head_on(test, true)


## The hatchback sent into the bus: a wreck, towed away after the fire.
func test_light_runs_into_heavy(test) -> void:
	await _head_on(test, false)
