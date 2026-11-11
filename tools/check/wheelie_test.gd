extends SceneTree
## Wheelies (scripts/vehicles/wheelie.gd): the fatbikes, mopeds, scooters and motorbikes
## (TwoWheeler `wheelie_degrees`) and the wheelchairs (Pedestrian, MobilityAid.tilt) lift
## their front on the rear wheel, that wheel staying on the road; going into a corner or
## braking ends it; the riders have cocky lines (DriverShout, mood "wheelie").
## usage: tools/godot.sh --headless --script tools/check/wheelie_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Wheelie = preload("res://scripts/vehicles/wheelie.gd")
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	_check_helper()
	_check_lines()
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	for frame_index in 240:
		await physics_frame
	var riders: Array[TwoWheeler] = []
	for vehicle: Vehicle in Vehicle.all_vehicles:
		var two := vehicle as TwoWheeler
		if two and two._wheelie:
			riders.append(two)
	_check(riders.size() > 0, "tweewielers die een wheelie kunnen (%d)" % riders.size())
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var chairs := walkers.people().filter(func(person: Pedestrian) -> bool: return person._wheelie != null)
	_check(chairs.size() > 0, "rolstoelen die een wheelie kunnen (%d)" % chairs.size())
	# force one on every rider and chair, keep it up a while
	for rider in riders:
		_force(rider._wheelie)
	for person: Pedestrian in chairs:
		_force(person._wheelie)
	var most_pitch := 0.0
	var worst_rear_lift := 0.0
	var most_chair := 0.0
	for frame_index in 60:
		await process_frame
		for rider in riders:
			if rider._wheelie.angle < 0.05:
				continue
			# the body's front up compared with the vehicle itself
			var pitch := rider.global_basis.z.angle_to(rider._body.global_basis.z)
			most_pitch = maxf(most_pitch, pitch)
			# the rear wheel's contact point stays where it was
			var on_road := rider._body.global_transform * rider._rear_contact
			var unturned := rider._body.global_transform * rider._wheelie.tilt_about(rider._rear_contact).affine_inverse() * rider._rear_contact
			worst_rear_lift = maxf(worst_rear_lift, on_road.distance_to(unturned))
		for person: Pedestrian in chairs:
			var tilt: Node3D = person.aid._tilt
			most_chair = maxf(most_chair, absf(tilt.rotation.x))
	print("hoogste wheelie: %.1f graden, rolstoel %.1f graden, achterwiel verschoven %.3f m" % [rad_to_deg(most_pitch), rad_to_deg(most_chair), worst_rear_lift])
	_check(most_pitch > deg_to_rad(5.0), "tweewielers gaan op het achterwiel")
	_check(worst_rear_lift < 0.01, "achterwiel blijft op de weg")
	_check(most_chair > deg_to_rad(5.0), "rolstoelen gaan op de grote wielen")
	# in a wheelie a daredevil: far over its usual speed, braking for nothing
	var up := riders.filter(func(rider: TwoWheeler) -> bool: return rider._wheelie.is_up())
	var all_daredevils := not up.is_empty()
	var faster := true
	for rider: TwoWheeler in up:
		all_daredevils = all_daredevils and rider.daredevil
		var usual := minf(rider.top_speed_kmh / 3.6, rider.speed_limit)
		faster = faster and rider.daredevil_speed() > usual * 1.2
	_check(all_daredevils, "in een wheelie een waaghals (%d)" % up.size())
	_check(faster, "de waaghals rijdt veel harder dan normaal")
	var stunting := up[0] as TwoWheeler if not up.is_empty() else null
	if stunting:
		stunting._people_limit = 0.0
		stunting._traffic_limit = 0.0
		var target := stunting._target_speed(1.0 / 60.0)
		_check(target > 1.0, "de waaghals remt niet voor verkeer of voetgangers (%.1f m/s)" % target)
	for chair: Pedestrian in chairs:
		if chair._wheelie.is_up():
			_check(chair.is_daredevil() and chair.daredevil_pace() > 1.5, "een rolstoel in een wheelie scheurt (x%.1f)" % chair.daredevil_pace())
			break
	print("wheelie ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _force(wheelie: Wheelie) -> void:
	wheelie._up_left = 5.0
	wheelie._height = wheelie.most_angle


func _check_helper() -> void:
	var wheelie := Wheelie.new(deg_to_rad(30.0), 1)
	_force(wheelie)
	for step in 60:
		wheelie.step(1.0 / 60.0, true)
	_check(wheelie.angle > deg_to_rad(20.0), "voorkant omhoog (%.1f graden)" % rad_to_deg(wheelie.angle))
	for step in 90:
		wheelie.step(1.0 / 60.0, false)
	_check(wheelie.angle < deg_to_rad(1.0), "niet meer mogen: weer neer")
	var started := 0
	var fresh := Wheelie.new(deg_to_rad(30.0), 2)
	for step in 60 * 60 * 10:
		if fresh.step(1.0 / 60.0, true):
			started += 1
	_check(started > 3 and started < 40, "af en toe een wheelie (%d in 10 minuten)" % started)


func _check_lines() -> void:
	for kind: String in ["fatbike", "brommer", "motor", "rolstoel"]:
		var line := DriverShout.pick_line(kind, "wheelie")
		_check(line != "", "wheelie-tekst voor %s: %s" % [kind, line])


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
