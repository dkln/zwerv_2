extends SceneTree
## Lets the test figure (scripts/demo/walker.gd, node "Wandelaar") walk all its routes in
## every map part, headless and faster than real time, and prints one line per route
## (path length, stuck, falls, highest step, navmesh) plus the physics time.
## usage: Godot --headless --script tools/check/walk_test.gd -- [part] [routes per part]
## part 0 (default) = all parts.

const Common = preload("res://tools/tool_common.gd")
const WorldParts = preload("res://scripts/world/world_parts.gd")
## Simulated seconds per real second; the physics ticks go up with it, so every physics
## step stays 1/60 s (the same collision behaviour as in the game).
const SPEED := 8


func _init() -> void:
	Common.watchdog(self, 1500)
	var only := int(Common.arg_float(0, 0))
	var sc := Common.instantiate(Common.WORLD)
	# nothing to see headless: skip merging, smoke and grass
	for n in ["DetailNiveau", "Rook", "Grassprieten", "Rondleiding"]:
		if sc.has_node(n):
			sc.get_node(n).free()
	var walker := sc.get_node("Wandelaar")
	walker.auto = false
	if Common.arg_count() > 1:
		walker.max_routes = int(Common.arg_float(1))
	Engine.time_scale = SPEED
	Engine.physics_ticks_per_second = 60 * SPEED
	Engine.max_physics_steps_per_frame = 4 * SPEED
	get_root().add_child(sc)
	await process_frame
	print("physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	var physics_ms := 0.0
	var physics_steps := 0
	var totals := {"routes": 0, "stuck": 0, "falls": 0, "jumps": 0, "no_path": 0}
	for p in range(1, WorldParts.part_count(sc) + 1):
		if only > 0 and p != only:
			continue
		WorldParts.show_part(sc, p)
		await walker.routes_ready
		print("--- deel %d: %d routes" % [p, walker.routes.size()])
		for i in walker.routes.size():
			walker.walk(i)
			var limit := 240.0   # simulated seconds
			while not walker.is_done() and limit > 0.0:
				await physics_frame
				limit -= 1.0 / 60.0
				# the time of one physics step (the monitor measures the last one)
				if walker.stats.time > 0.0:
					physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
					physics_steps += 1
			if not walker.is_done():
				print("wandelaar: %s | NIET AANGEKOMEN | %s" % [walker.routes[i].title, walker._summary(walker.routes[i])])
				walker.stop()
			totals.routes += 1
			totals.stuck += walker.stats.stuck
			totals.falls += walker.stats.falls
			totals.jumps += walker.stats.jumps
			totals.no_path += 1 if walker.stats.no_path else 0
	print("TOTAAL: ", totals, " · fysica gemiddeld %.2f ms per stap (1/60 s)" % (physics_ms / maxi(physics_steps, 1)))
	quit()
