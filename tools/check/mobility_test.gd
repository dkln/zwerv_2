extends SceneTree
## Wheelchairs and mobility scooters (scripts/world/mobility_aid.gd, Pedestrian `mobility`):
## some townspeople ride them; they ride about (the wheels rolling through the wheel shader,
## the casters swivelling round their upright axle, the scooter's front wheel steering), the
## rider sits with the feet on the footrests and the hands on the rims or grips, the collider
## holds chair and rider, a scooter someone stands in front of hoots, and the bicycle paths
## are open to the scooters (not to people on foot).
## usage: tools/godot.sh --headless --script tools/check/mobility_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	# no camera: nothing is out of sight, so everyone is drawn moving
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	for frame_index in 300:
		await physics_frame
		if not walkers.people().is_empty():
			break
	var riders := walkers.people().filter(func(person: Pedestrian) -> bool: return person.aid != null)
	var chairs := riders.filter(func(person: Pedestrian) -> bool: return person.mobility == "rolstoel")
	var scooters := riders.filter(func(person: Pedestrian) -> bool: return person.mobility == "scootmobiel")
	_check(chairs.size() > 0 and scooters.size() > 0, "rolstoelen (%d) en scootmobielen (%d) in de stad" % [chairs.size(), scooters.size()])
	_check(walkers._ride.size() > 0, "fietspaden voor de scootmobiel (%d cellen)" % walkers._ride.size())
	var ride_cell: Vector3i = walkers._ride.keys()[0] if walkers._ride.size() > 0 else Vector3i.ZERO
	_check(walkers.may_use(ride_cell, "scootmobiel") and not walkers.may_use(ride_cell, ""), "fietspad wel voor de scootmobiel, niet voor wie loopt")
	for person: Pedestrian in riders:
		_check_seated(person)
		_check_collider(person)
	# ride a while: wheels, casters, steering
	var start := {}
	for person: Pedestrian in riders:
		start[person] = person.global_position
	var swivelled := 0.0
	var steered := 0.0
	for frame_index in 60 * 20:
		await physics_frame
		for person: Pedestrian in riders:
			for caster: Array in person.aid._casters:
				swivelled = maxf(swivelled, absf((caster[0] as Node3D).rotation.y))
			if person.aid._steering:
				steered = maxf(steered, absf(person.aid._steering.rotation.y))
	var moved := 0
	var rolled := 0
	for person: Pedestrian in riders:
		if person.global_position.distance_to(start[person]) > 3.0:
			moved += 1
		var wheel: Array = person.aid._wheels[0]
		if absf(wheel[2]) > 0.5 and (wheel[0] as GeometryInstance3D).material_override is ShaderMaterial:
			rolled += 1
	_check(moved >= riders.size() - 1, "ze rijden rond (%d van %d meer dan 3 m)" % [moved, riders.size()])
	_check(rolled >= riders.size() - 1, "de wielen rollen (wielshader, %d van %d)" % [rolled, riders.size()])
	_check(swivelled > 0.3, "zwenkwieltjes draaien om hun as (tot %.2f rad)" % swivelled)
	_check(steered > 0.1, "het voorwiel van de scootmobiel stuurt in (tot %.2f rad)" % steered)
	# someone in front of a scooter: it hoots
	var scooter: Pedestrian = scooters[0]
	var player: Node3D = scene.get_node("Speler")
	var hooted := false
	for frame_index in 180:
		var ahead := Vector3(sin(scooter.rotation.y), 0.0, cos(scooter.rotation.y))
		player.global_position = scooter.global_position + ahead * 1.0
		await physics_frame
		if scooter._horn_clock > 0.0:
			hooted = true
			break
	_check(hooted, "de scootmobiel toetert naar wie voor hem staat")
	print("rolstoel en scootmobiel ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


## Feet on the footrests and hands on the rims or grips.
func _check_seated(person: Pedestrian) -> void:
	var aid := person.aid
	var rider := aid.rider
	aid.pose()
	var worst_foot := 0.0
	var worst_hand := 0.0
	for side: String in ["left", "right"]:
		var shin: Node3D = rider._joints["shin_" + side]
		var foot := rider.position + shin.position + shin.basis * Vector3(0.0, -TownsfolkFigure.shin_length(), 0.0)
		var on_left := rider.rest_joint("thigh_" + side).x > 0.0
		var wanted := Vector3(aid.foot.x if on_left else -aid.foot.x, aid.foot.y, aid.foot.z)
		worst_foot = maxf(worst_foot, foot.distance_to(wanted))
		var arm: Node3D = rider._joints["arm_" + side]
		var hand := rider.position + arm.position + arm.basis * Vector3(0.0, -TownsfolkFigure.arm_length(), 0.0)
		worst_hand = maxf(worst_hand, hand.distance_to(aid._hand(rider.rest_joint("arm_" + side).x > 0.0)))
	_check(worst_foot < 0.05, "%s (%s): voeten op de voetsteunen (%.3f m ernaast)" % [person.name, person.mobility, worst_foot])
	_check(worst_hand < 0.06, "%s (%s): handen aan %s (%.3f m ernaast)" % [person.name, person.mobility,
			"de hoepels" if person.mobility == "rolstoel" else "het stuur", worst_hand])


## The collider holds the chair or scooter and its rider.
func _check_collider(person: Pedestrian) -> void:
	var drawn := Vehicle._mesh_bounds(person.aid, person.aid.transform)
	var shape: CollisionShape3D = person._body.get_node("Doos")
	var box := AABB(shape.position - (shape.shape as BoxShape3D).size * 0.5, (shape.shape as BoxShape3D).size)
	var fits := box.grow(0.02).encloses(drawn) and (box.size - drawn.size).length() < 0.3
	_check(fits, "%s (%s): botsvorm %s om %s" % [person.name, person.mobility, box.size, drawn.size])


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
