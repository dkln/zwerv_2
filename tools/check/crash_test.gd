extends SceneTree

## Lets a heavy and a light vehicle run head on into each other on an empty stretch of the
## A12 (no other traffic) and prints what the hit does by their weights: the health each
## loses, which one is only bumped and which one becomes a wreck (on fire, or blown up), and
## that the wreck is towed back, as good as new, once it has burnt out.
## usage: Godot --headless --script tools/check/crash_test.gd -- [who is sent: heavy|light]

const VehicleFireTime: float = preload("res://scripts/effects/vehicle_fire.gd").BURN_SECONDS
const Common = preload("res://tools/tool_common.gd")
const START_CELL := Vector2i(150, 20)


func _init() -> void:
	Common.watchdog(self, 100)
	var sent_heavy := Common.arg(0, "heavy") == "heavy"
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Rondvlucht"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	var heavy: Vehicle = load("res://scripts/vehicles/city_bus.gd").new()
	var light: Vehicle = load("res://scripts/vehicles/hatchback.gd").new()
	var target := light if sent_heavy else heavy
	var sent := heavy if sent_heavy else light
	target.start_cell = START_CELL
	target.start_heading = Vector2i(-1, 0)
	sent.start_cell = START_CELL + Vector2i(0, 10)
	sent.start_heading = Vector2i(-1, 0)
	get_root().add_child(scene)
	await process_frame
	await process_frame
	scene.get_node("Auto").queue_free()
	scene.get_node("SUV").queue_free()
	scene.add_child(heavy)
	scene.add_child(light)
	var elapsed := 0.0
	while elapsed < 6.0:
		await physics_frame
		elapsed += 1.0 / 60.0
	sent.drive_into(target)
	var heavy_health := heavy.health
	var light_health := light.health
	while not heavy.crashed and not light.crashed and elapsed < 40.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		if heavy.health < heavy_health or light.health < light_health:
			print("klap: zwaar %.0f -> %.0f HP, licht %.0f -> %.0f HP" % [heavy_health, heavy.health, light_health, light.health])
			heavy_health = heavy.health
			light_health = light.health
	if not heavy.crashed and not light.crashed:
		print("geen wrak (alleen tikken, of geen botsing)")
		quit()
		return
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
		await physics_frame
		elapsed += 1.0 / 60.0
	print("na de brand: %s" % ("weggesleept, %.0f HP" % burning.health if not burning.crashed else "FOUT: nog een wrak"))
	quit()
