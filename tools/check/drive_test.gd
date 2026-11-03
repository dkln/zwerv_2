extends SceneTree
## Lets the car of scenes/stad.tscn (node "Auto", scripts/characters/car.gd, a Vehicle)
## drive on its own, headless and faster than real time, and prints what it did:
## distance, cells visited, stops, its top speed and time per kind of road (against the
## speed limit), the lowest level it reached (the A12 trough is -6), and every moment it
## was off its lanes, above or below the road surface, too fast, or turned more sharply
## than a corner allows.
## usage: Godot --headless --script tools/check/drive_test.gd -- [simulated seconds]
##        [start x] [start z] [heading x] [heading z]
## e.g. the A12 eastbound from the Koningskade: -- 300 70 24 1 0

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8
const STEP := 1.0 / 60.0
const MAX_TURN_RATE := 3.0     # rad/s
const KIND_NAMES := ["straat", "hoofdweg", "tunnel", "snelweg"]


func _init() -> void:
	Common.watchdog(self, 900)
	var seconds := Common.arg_float(0, 300.0)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Rondvlucht"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	var car: Vehicle = scene.get_node("Auto")
	if Common.arg_count() >= 5:
		car.start_cell = Vector2i(int(Common.arg_float(1)), int(Common.arg_float(2)))
		car.start_heading = Vector2i(int(Common.arg_float(3)), int(Common.arg_float(4)))
	Engine.time_scale = TIME_SCALE
	Engine.physics_ticks_per_second = 60 * TIME_SCALE
	Engine.max_physics_steps_per_frame = 4 * TIME_SCALE
	get_root().add_child(scene)
	await process_frame
	var network := car.network
	if not car.has_node("Carrosserie/Model"):
		print("FOUT: auto zonder model")
	var elapsed := 0.0
	var distance := 0.0
	var last_position := car.global_position
	var last_yaw := car.rotation.y
	var visited := {}
	var problems := {"naast de weg": 0, "hoogte": 0, "te snel": 0, "ruk": 0}
	var stops := 0
	var standing := 0.0
	var longest_stop := 0.0
	var lowest_level := 0
	var time_per_kind := [0.0, 0.0, 0.0, 0.0]
	var top_per_kind := [0.0, 0.0, 0.0, 0.0]
	while elapsed < seconds:
		await physics_frame
		elapsed += STEP
		var position_now := car.global_position
		distance += (position_now - last_position).length()
		last_position = position_now
		var cell := car._cell_under()
		visited[cell] = true
		lowest_level = mini(lowest_level, cell.y)
		var kind := network.kind(cell)
		time_per_kind[kind] += STEP
		top_per_kind[kind] = maxf(top_per_kind[kind], car.speed)
		if not network.has(cell):
			_problem(problems, "naast de weg", "t=%.1f cel %s" % [elapsed, cell])
		# the road right under the car (moving over, it crosses cells off its route)
		var under := network.find(floori(position_now.x / RoadNetwork.CELL), floori(position_now.z / RoadNetwork.CELL), cell.y, cell, 2)
		var surface := network.height(under if under != RoadNetwork.NONE else cell, Vector2(position_now.x, position_now.z))
		if absf(position_now.y - surface) > 0.15:
			_problem(problems, "hoogte", "t=%.1f cel %s: %.2f m, wegdek %.2f m" % [elapsed, cell, position_now.y, surface])
		if car.speed > network.speed_limit(cell) + 0.5:
			_problem(problems, "te snel", "t=%.1f cel %s: %.0f km/u, max %.0f" % [elapsed, cell, car.speed * 3.6, network.speed_limit(cell) * 3.6])
		var turn_rate := absf(wrapf(car.rotation.y - last_yaw, -PI, PI)) / STEP
		last_yaw = car.rotation.y
		if turn_rate > MAX_TURN_RATE:
			_problem(problems, "ruk", "t=%.1f %.1f rad/s bij %s" % [elapsed, turn_rate, cell])
		if car.speed < 0.05:
			if standing == 0.0:
				stops += 1
			standing += STEP
			longest_stop = maxf(longest_stop, standing)
		else:
			standing = 0.0
	print("AUTO: %.0f s, %.0f m (gem. %.1f m/s), %d cellen, %d stops (langste %.1f s), laagste niveau %d" % [
		seconds, distance, distance / seconds, visited.size(), stops, longest_stop, lowest_level])
	for kind in KIND_NAMES.size():
		if time_per_kind[kind] > 0.0:
			print("  %-9s %5.0f s, top %3.0f km/u (max %3.0f)" % [KIND_NAMES[kind], time_per_kind[kind],
				top_per_kind[kind] * 3.6, RoadNetwork.SPEED_LIMIT_KMH[kind]])
	print("  problemen: ", problems)
	quit()


## Counts a problem and prints the first five of each sort.
func _problem(problems: Dictionary, sort: String, message: String) -> void:
	problems[sort] += 1
	if problems[sort] <= 5:
		print(sort, ": ", message)
