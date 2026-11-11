extends SceneTree
## An idiot at the wheel (Vehicle.maniac): a few cars of the whole town made drunk or
## aggressive, the rest normal, driving headless and faster than real time. Per kind it
## prints how far over the speed limit they went, how far on average the body turned away from
## the road's own direction on a straight road (the weave is steered: the body turns, it does
## not slide sideways), and the crashes. The idiots should go faster and steer to and fro; the
## normal cars hardly. (Headless every vehicle counts as out of sight, so the front wheels are
## not turned here; in view they follow the front axle.) With a second argument it also prints
## the first idiot every quarter of a second.
## usage: tools/godot.sh --headless --script tools/check/maniac_test.gd -- [simulated seconds]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 4
const STEP := 1.0 / 60.0
const MANIACS := ["dronken", "dronken", "agressief", "agressief"]

var _problems: Array[String] = []


func _init() -> void:
	var seconds := Common.arg_float(0, 40.0)
	Common.watchdog(self, seconds + 240.0)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").whole_town = true
	Engine.time_scale = TIME_SCALE
	Engine.physics_ticks_per_second = 60 * TIME_SCALE
	Engine.max_physics_steps_per_frame = 4 * TIME_SCALE
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var kinds := {}   # vehicle -> "dronken", "agressief" or "gewoon"
	var made := 0
	for vehicle: Vehicle in Vehicle.all_vehicles:
		if vehicle.vehicle_kind == "auto" and not vehicle.emergency and made < MANIACS.size():
			vehicle.maniac = MANIACS[made]
			kinds[vehicle] = MANIACS[made]
			made += 1
		elif vehicle.vehicle_kind == "auto" and not vehicle.emergency:
			kinds[vehicle] = "gewoon"
	var over_limit := {}
	var body_turn := {}
	var straight_samples := {}
	var crashes := {}
	for kind in ["dronken", "agressief", "gewoon"]:
		over_limit[kind] = 0.0
		body_turn[kind] = 0.0
		straight_samples[kind] = 0
		crashes[kind] = 0
	var was_crashed := {}
	var elapsed := 0.0
	var watched: Vehicle = kinds.keys()[0]
	var printed_at := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += STEP
		if OS.get_cmdline_user_args().size() > 1 and elapsed - printed_at > 0.25:
			printed_at = elapsed
			var road_now := watched._rounded_route_point(watched._distance + watched._front_axle + 2.0) - watched._rounded_route_point(watched._distance + watched._front_axle - 2.0)
			print("%5.2f %s v %.1f weave %.2f zij %.2f stuur %.1f romp-weg %.1f bocht %.3f onzichtbaar %s" % [elapsed, watched.maniac, watched.speed, watched._weave, watched._side_offset,
				rad_to_deg(watched._steering), rad_to_deg(road_now.angle_to(Vector2(watched.global_basis.z.x, watched.global_basis.z.z))), watched._bend_ahead(watched._distance + watched._front_axle), watched.unseen])
		for vehicle: Vehicle in kinds:
			if not is_instance_valid(vehicle):
				continue
			var kind: String = kinds[vehicle]
			if vehicle.crashed:
				if not was_crashed.get(vehicle, false):
					crashes[kind] += 1
				was_crashed[vehicle] = true
				continue
			was_crashed[vehicle] = false
			var limit := vehicle.network.speed_limit(vehicle._cell_under()) if vehicle.network else 0.0
			if limit > 0.5:
				over_limit[kind] = maxf(over_limit[kind], vehicle.speed / limit)
			if vehicle.speed < 3.0 or not _straight_ahead(vehicle):
				continue
			var road := vehicle._rounded_route_point(vehicle._distance + vehicle._front_axle + 2.0) \
				- vehicle._rounded_route_point(vehicle._distance + vehicle._front_axle - 2.0)
			var body := Vector2(vehicle.global_basis.z.x, vehicle.global_basis.z.z)
			if road.length_squared() > 0.01 and body.length_squared() > 0.01:
				body_turn[kind] += rad_to_deg(absf(road.angle_to(body)))
				straight_samples[kind] += 1
	for kind in ["dronken", "agressief", "gewoon"]:
		body_turn[kind] /= maxf(straight_samples[kind], 1)
		print("%-10s harder dan de limiet tot %.2fx, carrosserie gemiddeld %4.1f graden van de weg (rechtdoor), botsingen %d" % [
			kind, over_limit[kind], body_turn[kind], crashes[kind]])
	_check(over_limit.dronken > 1.15 and over_limit.agressief > 1.4, "idioten rijden harder dan de limiet")
	_check(over_limit.gewoon < 1.1, "gewone auto's niet")
	_check(body_turn.dronken > 1.5 and body_turn.dronken > body_turn.gewoon * 2.0, "de dronkaard stuurt heen en weer (de carrosserie draait mee)")
	_check(body_turn.agressief > body_turn.gewoon * 1.5, "de agressieveling ook, wat minder")
	print("idioten ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


## True if the road runs straight from a few metres behind its front axle to a few ahead (no
## corner there, so any turn of the body or the wheels is steering of its own).
func _straight_ahead(vehicle: Vehicle) -> bool:
	return absf(vehicle._bend_ahead(vehicle._distance + vehicle._front_axle)) < 0.01 \
		and absf(vehicle._bend_ahead(vehicle._distance + vehicle._front_axle + 6.0)) < 0.01


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
