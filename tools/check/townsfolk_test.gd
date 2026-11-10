extends SceneTree
## Checks the townspeople, headless: the figures (TownsfolkFigure) and the player figure
## are in proportion, the riders sit on their two-wheelers (hips on the seat, feet on the
## pedals or footrests, hands on the grips), a cyclist pedals with the rear wheel and its
## bars turn with the front wheel, the two-wheelers countersteer into their corners, the
## pedestrians walk round on the ground without walking into the town and cross at the
## zebras, and every collider is the size of what it stands for (player, pedestrians, the
## two-wheelers and their wrecks).
## usage: Godot --headless --script tools/check/townsfolk_test.gd [-- <seconds>]

const Common = preload("res://tools/tool_common.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 420)
	var seconds := Common.arg_float(0, 24.0)
	await _check_figures()
	PlayerCharacter.choose("martin")
	# no camera: nothing is out of sight, so every vehicle steers and pedals as when seen
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	for frame_index in 300:
		await physics_frame
		if player._placed and not walkers.people().is_empty():
			break
	_check(player._placed, "speler staat")
	_check_player_collider(player)
	var people := walkers.people()
	print("voetgangers: %d, beloopbare cellen %d, zebra-overgangen %d" % [people.size(), walkers._walkable_cells.size(),
			walkers._links.keys().filter(func(cell: Vector3i) -> bool: return walkers.is_zebra(cell)).size()])
	_check(people.size() == walkers.count, "alle voetgangers geplaatst (%d)" % people.size())
	var two_wheelers: Array[TwoWheeler] = []
	for vehicle in Vehicle.all_vehicles:
		if vehicle is TwoWheeler:
			two_wheelers.append(vehicle)
	print("tweewielers: ", two_wheelers.map(func(vehicle: Vehicle) -> String: return "%s (%s)" % [vehicle.name, vehicle.get_script().get_global_name()]))
	_check(two_wheelers.size() >= 5, "tweewielers in het verkeer (%d)" % two_wheelers.size())
	for two_wheeler in two_wheelers:
		_check_two_wheeler_parts(two_wheeler)
	# drive and walk a while: watch the pedals, the steering and the people
	var starts := {}
	for person in people:
		starts[person] = person.global_position
	var crank_start := {}
	for two_wheeler in two_wheelers:
		crank_start[two_wheeler] = two_wheeler._crank_angle
	var countersteered := {}
	var leaned := {}
	var worst_foot := 0.0
	var worst_hand := 0.0
	var claims_seen := 0
	var stuck_inside := 0
	var steered_bars := false
	for frame_index in int(seconds * 60.0):
		await physics_frame
		if frame_index % 4 != 0:
			continue
		await process_frame
		if not Pedestrians._zebra_claims.is_empty():
			claims_seen += 1
		for two_wheeler in two_wheelers:
			if two_wheeler.crashed or two_wheeler._rider == null:
				continue
			if absf(two_wheeler._lean) > deg_to_rad(4.0):
				leaned[two_wheeler] = true
			# countersteering: while it leans over faster, the bars turn the other way
			if absf(two_wheeler._lean_rate) > 0.25 and signf(two_wheeler._steering) == -signf(two_wheeler._lean_rate) \
					and absf(two_wheeler._steering) > deg_to_rad(1.0):
				countersteered[two_wheeler] = true
			if two_wheeler.bicycle and absf(two_wheeler._steering_pivot.rotation.y) > deg_to_rad(3.0):
				steered_bars = true
			if not two_wheeler.unseen:
				worst_foot = maxf(worst_foot, _foot_miss(two_wheeler))
				worst_hand = maxf(worst_hand, _hand_miss(two_wheeler))
		if frame_index % 60 == 0:
			for person in people:
				if not _stands_free(person):
					stuck_inside += 1
	await _check_zebra(walkers)
	var walked := 0
	for person in people:
		if person.global_position.distance_to(starts[person]) > 3.0:
			walked += 1
	print("gelopen (> 3 m): %d van %d, in iets vast (metingen): %d, zebra geclaimd in %d metingen" % [walked, people.size(), stuck_inside, claims_seen])
	_check(walked >= people.size() * 0.6, "de meeste voetgangers lopen rond (%d van %d)" % [walked, people.size()])
	_check(stuck_inside <= 2, "voetgangers lopen niet door de stad heen (%d keer vast)" % stuck_inside)
	var standing := 0
	for person in people:
		if _on_ground(person):
			standing += 1
	_check(standing >= people.size() - 1, "voetgangers staan op de grond (%d van %d)" % [standing, people.size()])
	var pedalled := 0
	var bicycles := 0
	for two_wheeler in two_wheelers:
		if two_wheeler.bicycle:
			bicycles += 1
			if absf(two_wheeler._crank_angle - crank_start[two_wheeler]) > 0.5:
				pedalled += 1
	print("fietsen %d, getrapt %d; hellend %d, ingestuurd %d; voet ernaast tot %.3f m, hand tot %.3f m"
			% [bicycles, pedalled, leaned.size(), countersteered.size(), worst_foot, worst_hand])
	_check(bicycles > 0 and pedalled > 0, "fietsers trappen (%d van %d)" % [pedalled, bicycles])
	_check(steered_bars, "het stuur van een fiets draait mee")
	_check(countersteered.size() > 0, "tweewielers sturen in (%d van %d die hellen)" % [countersteered.size(), leaned.size()])
	_check(worst_foot < 0.05, "voeten op de trappers en voetsteunen (%.3f m)" % worst_foot)
	_check(worst_hand < 0.12, "handen aan het stuur (%.3f m)" % worst_hand)
	# a wreck's collider is the box of everything drawn on it, rider included
	for two_wheeler in two_wheelers:
		if not two_wheeler.crashed and two_wheeler._rider:
			var box := two_wheeler._outer_box
			two_wheeler._become_wreck(Vector3.ZERO)
			var shape := (two_wheeler._wreck.get_child(0) as CollisionShape3D).shape as BoxShape3D
			_check(shape.size.distance_to(Vector3(box.size.x, box.size.y - 0.05, box.size.z)) < 0.01,
					"wrak-collider %s zo groot als %s (%s)" % [two_wheeler.name, "fiets en berijder", shape.size])
			break
	print("PROBLEMEN: %d" % _problems.size() if not _problems.is_empty() else "OK: geen problemen")
	for problem in _problems:
		print("  - ", problem)
	quit(1 if not _problems.is_empty() else 0)


## The figures by themselves: the townsperson about 1.75 m, the player figure in the town
## about as tall; a leg reaches a foot put within its reach.
func _check_figures() -> void:
	for look_seed in [1, 2, 3, 4, 5, 6]:
		var figure := TownsfolkFigure.create(TownsfolkFigure.look_for(look_seed))
		get_root().add_child(figure)
		var height := Vehicle._mesh_bounds(figure).size.y
		_check(height > 1.6 and height < 1.85, "stadsbewoner %d is %.2f m" % [look_seed, height])
		var target := figure.rest_joint("thigh_left") + Vector3(0.05, -0.6, 0.2)
		figure.aim_leg("left", target)
		var shin: Node3D = figure._joints.shin_left
		var foot := shin.position + shin.basis * Vector3(0.0, -TownsfolkFigure.shin_length(), 0.0)
		_check(foot.distance_to(target) < 0.01, "been reikt tot de voet (%.3f m)" % foot.distance_to(target))
		figure.free()
	for id: String in PlayerCharacter.ARCHETYPES.keys():
		var model: Node3D = PlayerModel.new()
		model.archetype_id = id
		model.figure_scale = PlayerController.FIGURE_SCALE
		get_root().add_child(model)
		await process_frame
		var height := PlayerController._outer_box(model).size.y
		print("speler %s: %.2f m" % [id, height])
		# Willem walks bent over (an old man): a little shorter
		_check(height > (1.5 if id == "willem" else 1.65) and height < 1.9, "speler %s is %.2f m (in verhouding)" % [id, height])
		model.free()


func _check_player_collider(player: Node3D) -> void:
	var shape := (player._body.get_child(0) as CollisionShape3D)
	var box := (shape.shape as BoxShape3D).size
	var figure := PlayerController._outer_box(player._model)
	print("speler: figuur %s, botsvorm %s" % [figure.size, box])
	_check(box.distance_to(figure.size) < 0.02 and shape.position.distance_to(figure.get_center()) < 0.02,
			"botsvorm van de speler past om de figuur")
	_check(player._walk_shape.height < figure.size.y, "loopcilinder van de speler niet hoger dan de figuur")


func _check_two_wheeler_parts(two_wheeler: TwoWheeler) -> void:
	_check(two_wheeler._rider != null, "%s heeft een berijder" % two_wheeler.name)
	if two_wheeler._rider == null:
		return
	var outer := two_wheeler._outer_box
	_check(outer.encloses(Vehicle._mesh_bounds(two_wheeler._rider, two_wheeler._rider.transform).grow(-0.01)),
			"%s: de buitenmaat (botsing, wrak) omvat de berijder" % two_wheeler.name)
	_check(outer.size.y > 1.4 and outer.size.y < 2.3, "%s: hoogte met berijder %.2f m" % [two_wheeler.name, outer.size.y])
	var hips := two_wheeler._rider.position + two_wheeler._rider.hip_middle()
	_check(hips.distance_to(two_wheeler.rider_hip) < 0.01, "%s: heupen op het zadel" % two_wheeler.name)
	print("%s: buitenmaat %s, leunt %.0f graden, %s" % [two_wheeler.name, outer.size, rad_to_deg(two_wheeler._rider_lean),
			"fiets" if two_wheeler.bicycle else "motor"])
	if two_wheeler.bicycle:
		_check(two_wheeler._steering_pivot != null and two_wheeler._crank != null, "%s: stuur en trapas" % two_wheeler.name)
		var front_wheels := two_wheeler._wheels.filter(func(wheel: Node3D) -> bool: return wheel.get_parent() == two_wheeler._steering_pivot)
		_check(front_wheels.size() == 1, "%s: het voorwiel zit in het stuur" % two_wheeler.name)
		_check(two_wheeler._headlights.all(func(lamp: Node3D) -> bool: return lamp.get_parent() == two_wheeler._steering_pivot),
				"%s: de koplamp draait mee" % two_wheeler.name)


## A pedestrian put at the kerb before a zebra crosses to the pavement on the other side: at
## a plain zebra it claims it at the kerb and waits for the traffic; at pedestrian lights it
## waits for green without claiming it, and claims it as it crosses.
func _check_zebra(walkers: Pedestrians) -> void:
	# not brought back near the player meanwhile (the zebra may be further off)
	var reach_before := walkers.reach
	walkers.reach = 100000.0
	# a kerb before a zebra with a clear way onto it (a light pole may stand in the way of some)
	var person: Pedestrian = walkers.people()[0]
	var kerb := Vector3i.ZERO
	var zebra := Vector3i.ZERO
	var headed := false
	for cell: Vector3i in walkers._walkable_cells:
		for next: Vector3i in walkers.links(cell):
			if not walkers.is_zebra(next) or not person.restart_at(cell):
				continue
			person._pause = 0.0
			if person._head_for(next):
				kerb = cell
				zebra = next
				headed = true
				break
		if headed:
			break
	_check(zebra != Vector3i.ZERO, "er is een zebrapad om over te steken")
	if zebra == Vector3i.ZERO:
		walkers.reach = reach_before
		return
	var side := zebra - kerb
	var far_side := walkers.zebra_run(zebra, side)[-1] + side
	print("zebra: van %s over %s naar %s (weg vrij: %s)" % [kerb, zebra, far_side, headed])
	_check(headed, "voetganger kan naar het zebrapad lopen")
	var lights: Node = walkers._lights
	if walkers.walk_light(zebra, side) < 0:
		_check(Pedestrians.someone_at_zebra(zebra), "voetganger claimt het zebrapad bij de stoeprand")
	else:
		# the lights held at red for it: it waits at the kerb, the zebra not claimed
		lights.set_process(false)
		lights._time = _light_moment(walkers, zebra, side, 1)
		for frame_index in 90:
			await physics_frame
		_check(not person._on_zebra and not Pedestrians.someone_at_zebra(zebra), "voetganger wacht bij rood zonder het zebrapad te claimen")
		# then green (held there): it goes
		lights._time = _light_moment(walkers, zebra, side, 0)
	var was_on := false
	var crossed := false
	for frame_index in 60 * 25:
		await physics_frame
		if Pedestrians.someone_on_zebra(zebra):
			was_on = true
		# keep it near the player so it is not brought back elsewhere
		if person.cell == far_side or (was_on and walkers.is_walkable(person.cell) and person.cell != kerb):
			crossed = true
			break
	_check(was_on, "voetganger stapt op het zebrapad")
	_check(crossed, "voetganger steekt over naar de overkant (nu op %s)" % person.cell)
	_check(not Pedestrians.someone_at_zebra(zebra), "na het oversteken is het zebrapad weer vrij")
	walkers.reach = reach_before
	if lights:
		lights.set_process(true)


## A time of the traffic lights at which the pedestrian light of this crossing shows `phase`
## (0 green, 1 red).
func _light_moment(walkers: Pedestrians, zebra: Vector3i, side: Vector3i, phase: int) -> float:
	var lights: Node = walkers._lights
	var moment := 0.0
	while moment < 60.0:
		lights._time = moment
		if walkers.walk_light(zebra, side) == phase:
			return moment
		moment += 0.5
	return 0.0


## How far the rider's feet are from their pedals or footrests (metres, the worst one).
func _foot_miss(two_wheeler: TwoWheeler) -> float:
	var worst := 0.0
	var rider := two_wheeler._rider
	for side: String in ["left", "right"]:
		var shin: Node3D = rider._joints["shin_" + side]
		var foot := rider.position + shin.position + shin.basis * Vector3(0.0, -TownsfolkFigure.shin_length(), 0.0)
		var on_vehicle := two_wheeler._vehicle_side("thigh_" + side)
		var wanted: Vector3
		if two_wheeler.bicycle:
			wanted = BicycleParts.pedal(two_wheeler._crank_angle, on_vehicle == "right")
		else:
			var rest := two_wheeler.rider_foot
			wanted = Vector3(rest.x if on_vehicle == "left" else -rest.x, rest.y, rest.z)
		worst = maxf(worst, foot.distance_to(wanted))
	return worst


## How far the rider's hands are from the grips (metres, the worst one).
func _hand_miss(two_wheeler: TwoWheeler) -> float:
	var worst := 0.0
	var rider := two_wheeler._rider
	for side: String in ["left", "right"]:
		var arm: Node3D = rider._joints["arm_" + side]
		var hand := rider.position + arm.position + arm.basis * Vector3(0.0, -TownsfolkFigure.arm_length(), 0.0)
		worst = maxf(worst, hand.distance_to(two_wheeler._grip(two_wheeler._vehicle_side("arm_" + side))))
	return worst


## True if nothing of the town (but the ground and other people) is inside a pedestrian.
func _stands_free(person: Pedestrian) -> bool:
	var space := person.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	query.shape = shape
	query.collision_mask = Pedestrian.TOWN_LAYER
	query.exclude = [person._body.get_rid()]
	for height in [0.8, 1.3]:
		query.transform = Transform3D(Basis.IDENTITY, person.global_position + Vector3.UP * height)
		for hit: Dictionary in space.intersect_shape(query, 4):
			var collider: Node = hit.collider
			if collider != person.town._ground and not collider.get_parent() is Pedestrian \
					and not collider.get_parent() is PlayerController:
				print("  vast: ", person.name, " in ", collider.name, " bij ", person.global_position)
				return false
	return true


func _on_ground(person: Pedestrian) -> bool:
	var height := person._ground_height(person.global_position, person.global_position.y)
	return not is_nan(height) and absf(height - person.global_position.y) < 0.12


func _check(ok: bool, what: String) -> void:
	if not ok:
		_problems.append(what)
		print("FOUT: ", what)
