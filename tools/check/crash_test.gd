extends SceneTree
## Lets a heavy and a light vehicle run head on into each other on an empty stretch of the
## A12 (no other traffic) and prints what the weights and the torque do: the speeds before
## and after, and how far each went in the seconds after.
## usage: Godot --headless --script tools/check/crash_test.gd -- [who is sent: heavy|light]

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
	var heavy: Vehicle = load("res://scripts/characters/city_bus.gd").new()
	var light: Vehicle = load("res://scripts/characters/hatchback.gd").new()
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
	while not heavy.crashed and elapsed < 40.0:
		await physics_frame
		elapsed += 1.0 / 60.0
	if not heavy.crashed:
		print("geen botsing")
		quit()
		return
	print("op %s (%s): zwaar %.0f kg %.1f m/s -> %.1f, licht %.0f kg %.1f m/s -> %.1f, draaiing %.2f / %.2f rad/s" % [heavy.global_position, sent.name,
			heavy.total_mass(), heavy.velocity.length(), heavy._wreck.linear_velocity.length(),
			light.total_mass(), light.velocity.length(), light._wreck.linear_velocity.length(),
			heavy._wreck.angular_velocity.y, light._wreck.angular_velocity.y])
	var heavy_start := heavy._wreck.global_position
	var light_start := light._wreck.global_position
	for second in range(1, 7):
		var until := elapsed + 1.0
		while elapsed < until and heavy.crashed:
			await physics_frame
			elapsed += 1.0 / 60.0
		if heavy.crashed:
			print("+%d s: zwaar %.1f m, %.1f m/s; licht %.1f m, %.1f m/s" % [second, (heavy._wreck.global_position - heavy_start).length(), heavy._wreck.linear_velocity.length(),
					(light._wreck.global_position - light_start).length(), light._wreck.linear_velocity.length()])
	quit()
