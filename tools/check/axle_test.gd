extends SceneTree
## Checks that the vehicles turn about their rear axle and that what counts as their outer
## size covers what is drawn. Lets the traffic drive headless, faster than real time, and
## prints per kind, in corners: the sideways slip of the rear axle (should be about 0), of the
## front wheels against where the front axle moves, the corner radius and how far the
## steering goes; for a trailer the slip of its axle and the largest angle to its vehicle.
## Fails (exit code 1) if a rear axle slips or a mesh sticks out of a footprint.
## usage: Godot --headless --script tools/check/axle_test.gd -- [simulated seconds]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8
const STEP := 1.0 / 60.0
const MIN_SPEED := 1.5
const LEAST_TURN_RADIANS_PER_METRE := 0.08
const MOST_REAR_SLIP_DEGREES := 5.0
const FOOTPRINT_TOLERANCE := 0.01
const LEAST_REAR_MOTION := 0.1

var _failures := 0


func _init() -> void:
	Common.watchdog(self, 600)
	var seconds := Common.arg_float(0, 150.0)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	Engine.time_scale = TIME_SCALE
	Engine.physics_ticks_per_second = 60 * TIME_SCALE
	Engine.max_physics_steps_per_frame = 4 * TIME_SCALE
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var last := {}
	var last_trailer := {}
	var stats := {}
	var elapsed := 0.0
	var footprints_checked := false
	while elapsed < seconds:
		await physics_frame
		elapsed += STEP
		if not footprints_checked and elapsed > 2.0:
			footprints_checked = true
			for vehicle: Vehicle in Vehicle.all_vehicles:
				_check_footprints(vehicle)
		for vehicle: Vehicle in Vehicle.all_vehicles:
			if vehicle.crashed or vehicle is RailVehicle:
				last.erase(vehicle)
				last_trailer.erase(vehicle)
				continue
			_measure(vehicle, last, last_trailer, stats)
	for kind: String in stats:
		var entry: Dictionary = stats[kind]
		print("%-15s n=%5d | straal %4.1f m | slip achteras %4.1f (max %4.1f) | vooras t.o.v. wiel %4.1f | stuurhoek %4.1f | aanhanger: slip %4.1f, hoek max %5.1f | achteruit %4.1f%% (bij keren %d van %d)" % [
			kind, entry.rear.size(), _median(entry.radius), _median(entry.rear), entry.rear_most, _median(entry.wheel_off),
			_median(entry.steering), _median(entry.trailer_slip) if not entry.trailer_slip.is_empty() else 0.0, entry.trailer_angle, 100.0 * entry.backwards / maxf(entry.rear.size(), 1), entry.backwards_turning_round, entry.backwards])
		_check(entry.rear_most < MOST_REAR_SLIP_DEGREES, "%s: the rear axle slips %.1f degrees" % [kind, entry.rear_most])
	print("KLAAR, mislukt: ", _failures)
	Engine.time_scale = 1.0
	quit(1 if _failures else 0)


func _measure(vehicle: Vehicle, last: Dictionary, last_trailer: Dictionary, stats: Dictionary) -> void:
	var frame: Transform3D = vehicle.global_transform
	if last.has(vehicle) and vehicle.speed > MIN_SPEED:
		var previous: Transform3D = last[vehicle]
		var kind: String = vehicle.get_script().resource_path.get_file()
		if not stats.has(kind):
			stats[kind] = {"rear": [], "rear_most": 0.0, "backwards": 0, "backwards_turning_round": 0, "wheel_off": [], "steering": [], "radius": [], "trailer_slip": [], "trailer_angle": 0.0}
		var entry: Dictionary = stats[kind]
		var moved := frame.origin - previous.origin
		var path := Vector2(moved.x, moved.z).length()
		var turned := wrapf(frame.basis.get_euler().y - previous.basis.get_euler().y, -PI, PI)
		if path > 0.001 and absf(turned) / path > LEAST_TURN_RADIANS_PER_METRE:
			var rear_slip := _slip(frame, previous, vehicle._rear_axle)
			if rear_slip > 90.0:
				entry.backwards += 1
				if _turning_round(vehicle):
					entry.backwards_turning_round += 1
				rear_slip = 180.0 - rear_slip
			# a rear axle that hardly moves (the front axle moving across it) has no direction
			var rear_moved: Vector3 = frame * Vector3(0.0, 0.0, vehicle._rear_axle) - previous * Vector3(0.0, 0.0, vehicle._rear_axle)
			if Vector2(rear_moved.x, rear_moved.z).length() < path * LEAST_REAR_MOTION:
				rear_slip = 0.0
			entry.rear.append(rear_slip)
			entry.rear_most = maxf(entry.rear_most, rear_slip)
			entry.wheel_off.append(absf(_slip(frame, previous, vehicle._front_axle) - absf(rad_to_deg(vehicle._steering))))
			entry.steering.append(absf(rad_to_deg(vehicle._steering)))
			entry.radius.append(path / absf(turned))
			if vehicle._trailer:
				var trailer_frame: Transform3D = vehicle._trailer_current
				if last_trailer.has(vehicle):
					entry.trailer_slip.append(_slip(trailer_frame, last_trailer[vehicle], -vehicle.trailer_axle_distance))
		if vehicle._trailer:
			var trailer_axis := Vector2(vehicle._trailer_current.basis.z.x, vehicle._trailer_current.basis.z.z)
			var body_axis := Vector2(frame.basis.z.x, frame.basis.z.z)
			entry.trailer_angle = maxf(entry.trailer_angle, absf(rad_to_deg(trailer_axis.angle_to(body_axis))))
	last[vehicle] = frame
	if vehicle._trailer:
		last_trailer[vehicle] = vehicle._trailer_current


## True if the route around it turns right back on itself within a few cells.
func _turning_round(vehicle: Vehicle) -> bool:
	var here: int = vehicle._current_index()
	var headings: Array = vehicle._route_headings
	for first in range(maxi(here - 3, 0), mini(here + 3, headings.size())):
		for second in range(first + 1, mini(first + 5, headings.size())):
			if headings[first] == -headings[second]:
				return true
	return false


## The angle between where a point on the body's middle line moves and where the body points.
func _slip(frame: Transform3D, previous: Transform3D, along: float) -> float:
	var move: Vector3 = frame * Vector3(0.0, 0.0, along) - previous * Vector3(0.0, 0.0, along)
	var axis := Vector2(frame.basis.z.x, frame.basis.z.z)
	return absf(rad_to_deg(axis.angle_to(Vector2(move.x, move.z))))


## Every corner of every mesh on the vehicle lies within one of its footprints.
func _check_footprints(vehicle: Vehicle) -> void:
	# the footprint is flat: a vehicle on a ramp leans over it
	if absf(vehicle.global_basis.z.y) > 0.01:
		return
	var parts: Array = [[vehicle._body, vehicle.global_transform]]
	if vehicle._trailer:
		parts.append([vehicle._trailer, vehicle._trailer_current])
	if vehicle is RailVehicle:
		for index in vehicle._cars.size():
			parts.append([vehicle._cars[index], vehicle._car_current[index]])
	var rectangles: Array = vehicle._footprints(FOOTPRINT_TOLERANCE)
	for part: Array in parts:
		_check_meshes(part[0], part[1], rectangles, vehicle.name)


func _check_meshes(node: Node3D, to_world: Transform3D, rectangles: Array, label: String) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		# measured with the wheels straight: a steered wheel may stick out a little
		var part_transform: Transform3D = Transform3D(Basis.IDENTITY, child.position) if child.name.begins_with("Wiel") else child.transform
		var child_to_world: Transform3D = to_world * part_transform
		if child is MeshInstance3D and child.mesh:
			var box: AABB = child.mesh.get_aabb()
			for corner_index in 8:
				var corner: Vector3 = child_to_world * box.get_endpoint(corner_index)
				if not _inside_any(Vector2(corner.x, corner.z), rectangles):
					_check(false, "%s: %s sticks out of its footprint" % [label, child.name])
					break
		_check_meshes(child, child_to_world, rectangles, label)


func _inside_any(point: Vector2, rectangles: Array) -> bool:
	for rectangle: Array[Vector2] in rectangles:
		var side_a := rectangle[0] - rectangle[1]
		var side_b := rectangle[0] - rectangle[2]
		var offset := point - rectangle[0]
		var along_a := offset.dot(side_a) / side_a.length_squared()
		var along_b := offset.dot(side_b) / side_b.length_squared()
		if along_a <= 0.0 and along_a >= -1.0 and along_b <= 0.0 and along_b >= -1.0:
			return true
	return false


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("MISLUKT: ", what)
