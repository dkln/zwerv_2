extends SceneTree
## Two-wheelers going down (scripts/vehicles/two_wheeler.gd, _become_wreck): a cyclist and a
## moped are hit hard from the side. Each wreck must
## tip over onto its side, the rider must come off (a body of their own, away from the
## vehicle), a bicycle must not burn, and once towed the rider sits on it again.
## usage: tools/godot.sh --headless --script tools/check/two_wheeler_fall_test.gd

const Common = preload("res://tools/tool_common.gd")
const START_CELL := Vector2i(150, 20)
## Tipped over: its up axis at least this many degrees off the vertical.
const DOWN_DEGREES := 55.0

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	await process_frame
	await process_frame
	scene.get_node("Auto").queue_free()
	scene.get_node("SUV").queue_free()
	for script_path in ["res://scripts/vehicles/moped.gd", "res://scripts/vehicles/cyclist.gd", "res://scripts/vehicles/motorbike.gd"]:
		await _crash_into(scene, script_path)
	print("tweewielers vallen ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _crash_into(scene: Node, script_path: String) -> void:
	var rider: TwoWheeler = load(script_path).new()
	rider.start_cell = START_CELL
	rider.start_heading = Vector2i(-1, 0)
	scene.add_child(rider)
	var name_of := script_path.get_file().get_basename()
	for wait in 30:
		await physics_frame
	# hit from the side at speed, as by a car coming out of a side street (the crash itself,
	# Vehicle._crash_with, is the same for every vehicle: this is about what follows)
	rider.velocity = rider.global_basis.z * 6.0
	rider._become_wreck(rider.velocity * 0.4 + Vector3(0.0, 0.0, 3.0), 0.6, Vector3(0.0, 0.0, 1.0), 9.0)
	rider._catch_fire()
	_check(rider.crashed, "%s: neergehaald" % name_of)
	for wait in 150:
		paused = false   # nothing may hold the town still (a story page, a death screen)
		await physics_frame
	var up := rider._wreck.global_basis.y.normalized()
	var off_vertical := rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
	var thrown: RigidBody3D = rider._thrown_rider
	var apart := thrown.global_position.distance_to(rider._wreck.global_position) if thrown else 0.0
	print("  %s: %.0f graden om, berijder %.1f m van het voertuig, brand %s" % [name_of, off_vertical, apart, rider._fire != null])
	_check(off_vertical > DOWN_DEGREES, "%s: op zijn kant (%.0f graden)" % [name_of, off_vertical])
	_check(thrown != null and rider._rider.get_parent() == thrown, "%s: de berijder eraf, een lichaam apart" % name_of)
	if thrown:
		var shape_size: Vector3 = (thrown.get_child(0) as CollisionShape3D).shape.size if thrown.get_child(0) is CollisionShape3D else Vector3.ZERO
		var mesh_size := Vehicle._mesh_bounds(rider._rider).size
		print("  %s: botsvorm berijder %s, mesh %s" % [name_of, shape_size.snapped(Vector3.ONE * 0.01), mesh_size.snapped(Vector3.ONE * 0.01)])
	for child in rider._wreck.get_children():
		if child is CollisionShape3D:
			print("  %s: botsvorm wrak %s, mesh voertuig %s" % [name_of, (child.shape.size as Vector3).snapped(Vector3.ONE * 0.01),
					Vehicle._mesh_bounds(rider._body).size.snapped(Vector3.ONE * 0.01)])
	_check(apart > 0.6, "%s: de berijder ligt los van het voertuig (%.1f m)" % [name_of, apart])
	if rider.bicycle:
		_check(rider._fire == null, "%s: een fiets brandt niet" % name_of)
	rider._tow()
	await physics_frame
	_check(not rider.crashed and rider._rider.get_parent() == rider._body, "%s: weggesleept, de berijder weer erop" % name_of)
	rider.queue_free()
	await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
