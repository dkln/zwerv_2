extends "res://tests/integration/support/town_test.gd"
## The townspeople: the figures (TownsfolkFigure) and the player figure are in proportion,
## the riders sit on their two-wheelers (hips on the seat, feet on the pedals or footrests,
## hands on the grips), a cyclist pedals with the rear wheel and its bars turn with the
## front wheel, the two-wheelers countersteer into their corners, the pedestrians walk
## round on the ground without walking into the town and cross at the zebras, and every
## collider is the size of what it stands for (player, pedestrians, the two-wheelers and
## their wrecks). The town with its traffic.
##   tests/run_integration_tests.sh townsfolk [-- <seconds watched>]

const PlayerModel = preload("res://scripts/player/player_model.gd")
## Seconds of game time the traffic and the people are watched (argument 0).
const WATCH_SECONDS := 24.0


static func world_options() -> Dictionary:
	return {"traffic": true}


## The passers-by of the town.
func _walkers() -> Pedestrians:
	return scene.get_node("Voetgangers")


## The two-wheelers in the traffic.
func _two_wheelers() -> Array[TwoWheeler]:
	var found: Array[TwoWheeler] = []
	for vehicle in Vehicle.all_vehicles:
		if vehicle is TwoWheeler:
			found.append(vehicle)
	return found


## Seconds of game time to watch: argument 0 of the run, or WATCH_SECONDS.
func _watch_seconds() -> float:
	return float(argument(0, str(WATCH_SECONDS)))


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
	for height: float in [0.8, 1.3]:
		query.transform = Transform3D(Basis.IDENTITY, person.global_position + Vector3.UP * height)
		for hit: Dictionary in space.intersect_shape(query, 4):
			var collider: Node = hit.collider
			if collider != person.town._ground and not collider.get_parent() is Pedestrian \
					and not collider.get_parent() is PlayerController:
				print("  vast: ", person.name, " in ", collider.name, " bij ", person.global_position)
				return false
	return true


## True if `person` stands at the height of the ground under them.
func _on_ground(person: Pedestrian) -> bool:
	var height := person._ground_height(person.global_position, person.global_position.y)
	return not is_nan(height) and absf(height - person.global_position.y) < 0.12


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


## A townsperson is about 1.75 m tall, and a leg reaches a foot put within its reach.
func test_townspeople_are_in_proportion_and_their_legs_reach(test) -> void:
	for look_seed: int in [1, 2, 3, 4, 5, 6]:
		var figure := TownsfolkFigure.create(TownsfolkFigure.look_for(look_seed))
		add_to_root(figure)
		var height := Vehicle._mesh_bounds(figure).size.y
		test.check(height > 1.6 and height < 1.85, "stadsbewoner %d is %.2f m" % [look_seed, height])
		var target := figure.rest_joint("thigh_left") + Vector3(0.05, -0.6, 0.2)
		figure.aim_leg("left", target)
		var shin: Node3D = figure._joints.shin_left
		var foot := shin.position + shin.basis * Vector3(0.0, -TownsfolkFigure.shin_length(), 0.0)
		test.check(foot.distance_to(target) < 0.01, "been reikt tot de voet (%.3f m)" % foot.distance_to(target))
		figure.free()


## Every player figure at its size in the town is about as tall as a townsperson (Willem,
## bent over, a little shorter).
func test_player_figures_are_in_proportion(test) -> void:
	for id: String in PlayerCharacter.ARCHETYPES.keys():
		var model: Node3D = PlayerModel.new()
		model.archetype_id = id
		model.figure_scale = PlayerController.FIGURE_SCALE
		add_to_root(model)
		await frames(1)
		var height := PlayerController._outer_box(model).size.y
		print("speler %s: %.2f m" % [id, height])
		test.check(height > (1.5 if id == "willem" else 1.65) and height < 1.9, "speler %s is %.2f m (in verhouding)" % [id, height])
		model.free()


## The player's collider is the figure's box at rest with room for its moves standing
## still (breathing, the arms): the figure stays inside it, it is not much bigger, and the
## walking cylinder is not taller than the figure.
func test_player_collider_fits_the_figure(test) -> void:
	test.check(player._placed, "speler staat")
	var shape := (player._body.get_child(0) as CollisionShape3D)
	var box := (shape.shape as BoxShape3D).size
	var collider := AABB(shape.position - box * 0.5, box)
	var rest: AABB = player._model.rest_bounds()
	var widest := rest
	for frame_index in 240:
		await tree.process_frame
		widest = widest.merge(PlayerController._outer_box(player._model))
	print("speler: figuur in rust %s, stilstaand tot %s, botsvorm %s" % [rest, widest, collider])
	test.check(collider.grow(0.02).encloses(widest), "botsvorm van de speler past om de figuur, ook als die beweegt")
	test.check(collider.size.x - rest.size.x < 0.15 and collider.size.z - rest.size.z < 0.2, "en is niet veel groter dan de figuur")
	test.check(player._walk_shape.height < rest.size.y, "loopcilinder van de speler niet hoger dan de figuur")


## As many pedestrians walk in the town as this hour and this district ask for.
func test_all_pedestrians_are_placed(test) -> void:
	var walkers := _walkers()
	var people := walkers.people()
	print("voetgangers: %d, beloopbare cellen %d, zebra-overgangen %d" % [people.size(), walkers._walkable_cells.size(),
		walkers._links.keys().filter(func(cell: Vector3i) -> bool: return walkers.is_zebra(cell)).size()])
	test.check(people.size() == walkers.wanted_count(), "alle voetgangers geplaatst (%d van %d voor dit uur en deze wijk)" % [people.size(), walkers.wanted_count()])


## The traffic has two-wheelers, each with a rider inside its outer box, the hips on the
## saddle; a bicycle has its bars and crank, the front wheel and the headlight in the bars.
func test_two_wheelers_carry_their_riders(test) -> void:
	var two_wheelers := _two_wheelers()
	print("tweewielers: ", two_wheelers.map(func(vehicle: Vehicle) -> String: return "%s (%s)" % [vehicle.name, vehicle.get_script().get_global_name()]))
	test.check(two_wheelers.size() >= 5, "tweewielers in het verkeer (%d)" % two_wheelers.size())
	for two_wheeler in two_wheelers:
		var label := String(two_wheeler.name)
		test.check(two_wheeler._rider != null, "%s heeft een berijder" % label)
		if two_wheeler._rider == null:
			continue
		var outer := two_wheeler._outer_box
		var rider_bounds := Vehicle._mesh_bounds(two_wheeler._rider, two_wheeler._rider.transform)
		test.check(outer.encloses(rider_bounds.grow(-0.01)),
			"%s: de buitenmaat (botsing, wrak) omvat de berijder (buitenmaat %s .. %s, berijder %s .. %s)" % [label,
				outer.position, outer.end, rider_bounds.position, rider_bounds.end])
		test.check(outer.size.y > 1.4 and outer.size.y < 2.3, "%s: hoogte met berijder %.2f m" % [label, outer.size.y])
		var hips := two_wheeler._rider.position + two_wheeler._rider.hip_middle()
		test.check(hips.distance_to(two_wheeler.rider_hip) < 0.01, "%s: heupen op het zadel" % label)
		print("%s: buitenmaat %s, leunt %.0f graden, %s" % [label, outer.size, rad_to_deg(two_wheeler._rider_lean),
			"fiets" if two_wheeler.bicycle else "motor"])
		if two_wheeler.bicycle:
			test.check(two_wheeler._steering_pivot != null and two_wheeler._crank != null, "%s: stuur en trapas" % label)
			var front_wheels := two_wheeler._wheels.filter(func(wheel: Node3D) -> bool: return wheel.get_parent() == two_wheeler._steering_pivot)
			test.check(front_wheels.size() == 1, "%s: het voorwiel zit in het stuur" % label)
			test.check(two_wheeler._headlights.all(func(lamp: Node3D) -> bool: return lamp.get_parent() == two_wheeler._steering_pivot),
				"%s: de koplamp draait mee" % label)


## Watched riding a while (no camera: nothing is out of sight, so every vehicle steers and
## pedals as when seen): cyclists pedal, a bicycle's bars turn, the two-wheelers
## countersteer, and feet and hands stay on the pedals, footrests and grips.
func test_riders_pedal_steer_and_hold_on(test) -> void:
	camera_off()
	var two_wheelers := _two_wheelers()
	var crank_start := {}
	for two_wheeler in two_wheelers:
		crank_start[two_wheeler] = two_wheeler._crank_angle
	var countersteered := {}
	var leaned := {}
	var worst_foot := 0.0
	var worst_hand := 0.0
	var steered_bars := false
	for frame_index in int(_watch_seconds() * 60.0):
		await tree.physics_frame
		if frame_index % 4 != 0:
			continue
		await tree.process_frame
		for two_wheeler in two_wheelers:
			if not is_instance_valid(two_wheeler) or two_wheeler.crashed or two_wheeler._rider == null:
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
	var pedalled := 0
	var bicycles := 0
	for two_wheeler in two_wheelers:
		if is_instance_valid(two_wheeler) and two_wheeler.bicycle:
			bicycles += 1
			if absf(two_wheeler._crank_angle - crank_start[two_wheeler]) > 0.5:
				pedalled += 1
	print("fietsen %d, getrapt %d; hellend %d, ingestuurd %d; voet ernaast tot %.3f m, hand tot %.3f m"
		% [bicycles, pedalled, leaned.size(), countersteered.size(), worst_foot, worst_hand])
	test.check(bicycles > 0 and pedalled > 0, "fietsers trappen (%d van %d)" % [pedalled, bicycles])
	test.check(steered_bars, "het stuur van een fiets draait mee")
	test.check(countersteered.size() > 0, "tweewielers sturen in (%d van %d die hellen)" % [countersteered.size(), leaned.size()])
	test.check(worst_foot < 0.05, "voeten op de trappers en voetsteunen (%.3f m)" % worst_foot)
	test.check(worst_hand < 0.12, "handen aan het stuur (%.3f m)" % worst_hand)


## Watched walking a while: most pedestrians get somewhere, they do not end up inside the
## town (walls, props), and they stand on the ground.
func test_pedestrians_walk_round_on_the_ground(test) -> void:
	camera_off()
	var people := _walkers().people()
	var starts := {}
	for person in people:
		starts[person] = person.global_position
	var claims_seen := 0
	var stuck_inside := 0
	for frame_index in int(_watch_seconds() * 60.0):
		await tree.physics_frame
		if frame_index % 4 != 0:
			continue
		if not Pedestrians._zebra_claims.is_empty():
			claims_seen += 1
		if frame_index % 60 == 0:
			for person in people:
				if is_instance_valid(person) and not _stands_free(person):
					stuck_inside += 1
	var walked := 0
	var standing := 0
	for person in people:
		if not is_instance_valid(person):
			continue
		if starts.has(person) and person.global_position.distance_to(starts[person]) > 3.0:
			walked += 1
		if _on_ground(person):
			standing += 1
	print("gelopen (> 3 m): %d van %d, in iets vast (metingen): %d, zebra geclaimd in %d metingen" % [walked, starts.size(), stuck_inside, claims_seen])
	test.check(walked >= starts.size() * 0.6, "de meeste voetgangers lopen rond (%d van %d)" % [walked, starts.size()])
	test.check(stuck_inside <= 2, "voetgangers lopen niet door de stad heen (%d keer vast)" % stuck_inside)
	test.check(standing >= people.size() - 1, "voetgangers staan op de grond (%d van %d)" % [standing, people.size()])


## A pedestrian put at the kerb before a zebra crosses to the pavement on the other side: at
## a plain zebra it claims it at the kerb and waits for the traffic; at pedestrian lights it
## waits for green without claiming it, and claims it as it crosses.
func test_pedestrian_crosses_at_a_zebra(test) -> void:
	camera_off()
	var walkers := _walkers()
	# not brought back near the player meanwhile (the zebra may be further off)
	set_for_test(walkers, "reach", 100000.0)
	# a kerb before a zebra with a clear way onto it (a light pole may stand in the way of some)
	var person: Pedestrian = walkers.people()[0]
	var kerb := Vector3i.ZERO
	var zebra := Vector3i.ZERO
	for cell: Vector3i in walkers._walkable_cells:
		for next: Vector3i in walkers.links(cell):
			if not walkers.is_zebra(next) or not person.restart_at(cell):
				continue
			person._pause = 0.0
			if person._head_for(next):
				kerb = cell
				zebra = next
				break
		if zebra != Vector3i.ZERO:
			break
	test.check(zebra != Vector3i.ZERO, "er is een zebrapad om over te steken")
	if zebra == Vector3i.ZERO:
		return
	var side := zebra - kerb
	var far_side := walkers.zebra_run(zebra, side)[-1] + side
	print("zebra: van %s over %s naar %s" % [kerb, zebra, far_side])
	test.check(true, "voetganger kan naar het zebrapad lopen")
	var lights: Node = walkers._lights
	var with_lights := walkers.walk_light(zebra, side) >= 0
	var light_time_before: float = lights._time if with_lights else 0.0
	if not with_lights:
		test.check(Pedestrians.someone_at_zebra(zebra), "voetganger claimt het zebrapad bij de stoeprand")
	else:
		# the lights held at red for it: it waits at the kerb, the zebra not claimed
		lights.set_process(false)
		lights._time = _light_moment(walkers, zebra, side, 1)
		await physics_frames(90)
		test.check(not person._on_zebra and not Pedestrians.someone_at_zebra(zebra), "voetganger wacht bij rood zonder het zebrapad te claimen")
		# then green (held there): it goes
		lights._time = _light_moment(walkers, zebra, side, 0)
	var was_on := false
	var crossed := false
	for frame_index in 60 * 25:
		await tree.physics_frame
		if Pedestrians.someone_on_zebra(zebra):
			was_on = true
		if person.cell == far_side or (was_on and walkers.is_walkable(person.cell) and person.cell != kerb):
			crossed = true
			break
	test.check(was_on, "voetganger stapt op het zebrapad")
	test.check(crossed, "voetganger steekt over naar de overkant (nu op %s)" % person.cell)
	test.check(not Pedestrians.someone_at_zebra(zebra), "na het oversteken is het zebrapad weer vrij")
	if with_lights:
		lights._time = light_time_before
		lights.set_process(true)


## A two-wheeler's wreck has a collider the size of everything drawn on it, rider included.
func test_wreck_collider_is_the_size_of_bike_and_rider(test) -> void:
	var checked := false
	for two_wheeler in _two_wheelers():
		if not two_wheeler.crashed and two_wheeler._rider:
			var box := two_wheeler._outer_box
			two_wheeler._become_wreck(Vector3.ZERO)
			var shape := (two_wheeler._wreck.get_child(0) as CollisionShape3D).shape as BoxShape3D
			test.check(shape.size.distance_to(Vector3(box.size.x, box.size.y - 0.05, box.size.z)) < 0.01,
				"wrak-collider %s zo groot als %s (%s)" % [two_wheeler.name, "fiets en berijder", shape.size])
			# back in the traffic for the suites that share this town
			two_wheeler._tow()
			checked = true
			break
	test.check(checked, "een tweewieler met berijder om een wrak van te maken")
