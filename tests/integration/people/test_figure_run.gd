extends "res://tests/integration/support/town_test.gd"
## The player figures (scripts/player/player_model.gd) and the townspeople
## (scripts/world/townsfolk_figure.gd): few details (colours, lone voxels), Martin's jacket one
## colour, nobody with a rucksack; the run (walking above 1) a run of its own and not the
## walk sped up: leaning forward, the knees driven up and bent deep, the elbows bent, off the
## ground between the steps, the feet never under the ground; the rucksack (picked up:
## PlayerController.pick_up_backpack) on the back clear of the figure, more room in the
## inventory, and the collider grown round it. Without the town: a figure or a player on
## its own in the tree.
##   tests/run_integration_tests.sh figure_run

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const Items = preload("res://scripts/player/items.gd")
const Backpacks = preload("res://scripts/world/backpacks.gd")
const NEIGHBOURS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


static func world_options() -> Dictionary:
	return {"town": false}


## The colours of `figure` (colour -> true).
static func _colours(figure: PlayerModel.VoxelFigure) -> Dictionary:
	var colours := {}
	for cell: Vector3i in figure.cells:
		colours[figure.cells[cell]] = true
	return colours


## How many voxels of `figure` stand alone: no neighbour of their colour, three or more of
## another (a loose detail).
static func _lone(figure: PlayerModel.VoxelFigure) -> int:
	var count := 0
	for cell: Vector3i in figure.cells:
		var colour: Color = figure.cells[cell]
		var same := 0
		var other := 0
		for side: Vector3i in NEIGHBOURS:
			if figure.cells.has(cell + side):
				if figure.cells[cell + side] == colour:
					same += 1
				else:
					other += 1
		if same == 0 and other >= 3:
			count += 1
	return count


## The extremes of the pose of `model` over three seconds at `walking` (1.0 the walk, 1.7
## the player's run): lean, thigh forward, knee and elbow (degrees), bob and lowest point
## of any mesh (metres), and the steps taken per second.
func _sample(model: PlayerModel, walking: float) -> Dictionary:
	model.walking = walking
	var result := {"lean": 0.0, "thigh_forward": 0.0, "knee": 0.0, "elbow": 0.0, "bob": 0.0, "lowest": INF, "steps": 0.0}
	var start_clock: float = model._walk_clock
	var figure: Node3D = model._figure
	for frame_index in 180:
		model._process(1.0 / 60.0)
		result.lean = maxf(result.lean, figure.rotation_degrees.x)
		result.thigh_forward = minf(result.thigh_forward, (model._joints.leg_left as Node3D).rotation_degrees.x)
		result.knee = maxf(result.knee, (model._joints.shin_left as Node3D).rotation_degrees.x)
		result.elbow = minf(result.elbow, (model._joints.forearm_left as Node3D).rotation_degrees.x)
		result.bob = maxf(result.bob, figure.position.y)
		for mesh_node in figure.find_children("*", "MeshInstance3D", true, false):
			var piece := mesh_node as MeshInstance3D
			var box := (model.global_transform.affine_inverse() * piece.global_transform) * piece.mesh.get_aabb()
			result.lowest = minf(result.lowest, box.position.y)
	result.steps = (model._walk_clock - start_clock) / PI / 3.0
	return result


## The figure of `archetype_id` in the tree (simple, not idling), ready to be posed.
func _model_of(archetype_id: String) -> PlayerModel:
	var model := PlayerModel.new()
	model.archetype_id = archetype_id
	model.simple = true
	model.idle = false
	add_to_root(model)
	await frames(1)
	return model


## A player (Martin: a slim one, the rucksack sticks out behind him) on his own in the
## tree, standing still (no physics, no processing), with empty pockets.
func _player_alone() -> PlayerController:
	PlayerCharacter.choose("martin")
	var lone_player: PlayerController = PlayerController.new()
	add_to_root(lone_player)
	await frames(1)
	lone_player.set_physics_process(false)
	lone_player.set_process(false)
	lone_player._model.idle = false
	lone_player._model.set_process(false)
	lone_player.inventory = {}
	return lone_player


## True if the collider box (Botsvorm) of `lone_player` is the box round all meshes of the
## figure at rest with the room for its idle movement (PlayerController._with_pose_room).
func _collider_matches(lone_player: PlayerController) -> bool:
	var shape: CollisionShape3D = lone_player._body_shape
	var box := shape.shape as BoxShape3D
	var collider := AABB(shape.position - box.size * 0.5, box.size)
	var meshes: AABB = PlayerController._outer_box(lone_player._model)
	print("  botsvorm ", collider, " mesh ", meshes)
	var wanted := PlayerController._with_pose_room(meshes)
	return collider.position.distance_to(wanted.position) < 0.02 and collider.size.distance_to(wanted.size) < 0.02


## Every player figure has few colours, hardly any lone detail voxels and no rucksack.
func test_player_figures_have_few_details(test) -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var figure := PlayerModel.voxels_for(archetype_id)
		var colours := _colours(figure)
		print("%s: %d voxels, %d kleuren, %d losse" % [archetype_id, figure.cells.size(), colours.size(), _lone(figure)])
		test.check(colours.size() <= 15, "%s weinig kleuren (%d)" % [archetype_id, colours.size()])
		test.check(_lone(figure) <= 4, "%s geen losse detailvoxels (%d)" % [archetype_id, _lone(figure)])
		test.check(not colours.has(PlayerModel.BACKPACK_CANVAS), "%s heeft standaard geen rugzak" % archetype_id)


## Martin's jacket: the chest, the collar and the sleeves are one colour.
func test_martins_jacket_is_one_colour(test) -> void:
	var martin := PlayerModel.voxels_for("martin")
	var jacket := {}
	for cell: Vector3i in martin.cells:
		var colour: Color = martin.cells[cell]
		if cell.y >= 15 and cell.y <= 25 and martin.kind_of(colour) not in ["skin", "eye", "hair"]:
			jacket[colour] = true
	test.check(jacket.size() == 1, "Martins jas een kleur (%s)" % [jacket.keys()])


## The townspeople (sixty looks): few colours, and none of them with a rucksack.
func test_townspeople_few_colours_and_no_rucksacks(test) -> void:
	var with_bag := 0
	var most_colours := 0
	for look_seed in 60:
		var look := TownsfolkFigure.look_for(look_seed)
		with_bag += int(look.get("rucksack", false))
		var figure := PlayerModel.VoxelFigure.new()
		TownsfolkFigure._build_voxels(figure, look)
		most_colours = maxi(most_colours, _colours(figure).size())
	print("voetgangers: hooguit %d kleuren, %d met rugzak" % [most_colours, with_bag])
	test.check(with_bag == 0, "geen voetganger met een rugzak")
	test.check(most_colours <= 11, "voetgangers weinig kleuren (%d)" % most_colours)


## The rucksack of every player figure: a block of its own that overlaps no voxel of the
## figure, right against the back, and in no limb (it would swing with it).
func test_rucksack_sits_on_the_back_clear_of_the_figure(test) -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var bare := PlayerModel.voxels_for(archetype_id)
		var packed := PlayerModel.voxels_for(archetype_id, true)
		var place: Vector3i = PlayerModel.BACKPACK[archetype_id]
		var volume := 6 * (place.z - place.y + 1) * PlayerModel.BACKPACK_DEPTH
		var overlapping := 0
		for cell: Vector3i in bare.cells:
			if packed.cells[cell] != bare.cells[cell]:
				overlapping += 1
		test.check(packed.cells.size() - bare.cells.size() == volume and overlapping == 0,
				"%s: rugzak los van het figuur (%d nieuw, %d overlap)" % [archetype_id, packed.cells.size() - bare.cells.size(), overlapping])
		# against the back: a voxel of the figure right in front of the rucksack
		var touching := false
		for y in range(place.y, place.z + 1):
			for x in range(4, 10):
				touching = touching or bare.has(x, y, place.x - 1)
		test.check(touching, "%s: rugzak tegen de rug" % archetype_id)
		var parts := PlayerModel.parts_for(archetype_id, true, true)
		var bare_parts := PlayerModel.parts_for(archetype_id, true)
		for limb: String in PlayerModel.LIMBS:
			var with_pack: AABB = (parts.meshes[limb] as ArrayMesh).get_aabb()
			var without: AABB = (bare_parts.meshes[limb] as ArrayMesh).get_aabb()
			test.check(with_pack.is_equal_approx(without), "%s: rugzak niet aan %s" % [archetype_id, limb])


## Every player figure run (walking 1.7) against walked (1.0): the walk upright, the run
## leaning forward with the knees high and bent deep, the elbows bent, off the ground
## between quicker steps, and the feet never under the ground.
func test_the_run_is_a_run_of_its_own(test) -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var model := await _model_of(archetype_id)
		var walk := _sample(model, 1.0)
		var run := _sample(model, 1.7)
		print("%s lopen: %s" % [archetype_id, walk])
		print("%s rennen: %s" % [archetype_id, run])
		test.check(walk.lean < 0.5 and walk.knee < 30.0 and walk.elbow > -5.0, "%s loopt rechtop, knieen licht gebogen" % archetype_id)
		test.check(run.lean > 8.0, "%s leunt voorover bij het rennen" % archetype_id)
		test.check(run.thigh_forward < -50.0 and run.knee > 90.0, "%s heft de knieen hoog en buigt ze diep" % archetype_id)
		test.check(run.elbow < -70.0, "%s rent met gebogen ellebogen" % archetype_id)
		test.check(run.bob > 0.06 and run.bob > walk.bob * 1.5, "%s komt los van de grond tussen de passen" % archetype_id)
		test.check(run.steps > walk.steps * 1.3, "%s zet sneller passen" % archetype_id)
		test.check(run.lowest > -0.03 and walk.lowest > -0.03, "%s voeten niet door de grond (%.3f, %.3f)" % [archetype_id, run.lowest, walk.lowest])
		model.queue_free()


## Without a rucksack only the pockets: four kinds of things and no fifth, but more of a
## kind you already have.
func test_pockets_hold_four_kinds(test) -> void:
	var lone_player := await _player_alone()
	test.check(not lone_player.has_backpack and lone_player.inventory_slots() == Items.BASE_SLOTS, "zonder rugzak %d vakjes" % lone_player.inventory_slots())
	for item_id: String in ["brood", "appel", "water", "bier"]:
		lone_player.add_item(item_id)
	test.check(not lone_player.add_item("vis") and not lone_player.inventory.has("vis"), "zakken vol: geen vijfde soort")
	test.check(lone_player.add_item("brood") and int(lone_player.inventory.brood) == 2, "wel meer van wat je al hebt")


## A rucksack picked up is worn (only one), gives more room in the inventory, and the
## collider grows round it and still matches the figure.
func test_rucksack_picked_up_gives_room_and_a_bigger_collider(test) -> void:
	var lone_player := await _player_alone()
	for item_id: String in ["brood", "appel", "water", "bier"]:
		lone_player.add_item(item_id)
	var before: AABB = lone_player._figure_box
	test.check(_collider_matches(lone_player), "botsvorm om het figuur zonder rugzak (%s)" % [before])
	test.check(lone_player.pick_up_backpack() and lone_player.has_backpack and lone_player._model.backpack, "rugzak opgepakt en om")
	test.check(not lone_player.pick_up_backpack(), "geen tweede rugzak")
	test.check(lone_player.inventory_slots() == Items.BASE_SLOTS + Items.BACKPACK_SLOTS, "met rugzak %d vakjes" % lone_player.inventory_slots())
	test.check(lone_player.add_item("vis"), "met rugzak past er meer in")
	await frames(1)
	var after: AABB = lone_player._figure_box
	print("botsvorm zonder rugzak ", before, ", met ", after)
	test.check(after.position.z <= before.position.z + 0.001 and is_equal_approx(after.size.y, before.size.y), "botsvorm niet kleiner met de rugzak")
	test.check(_collider_matches(lone_player), "botsvorm om het figuur met rugzak (%s)" % [after])


## The rucksack lying in the town is the size of the one worn.
func test_rucksack_on_the_street_is_as_big_as_on_the_back(test) -> void:
	var lying: AABB = Backpacks.backpack_mesh().get_aabb()
	print("rugzak op straat ", lying)
	test.check(lying.size.y > 0.3 and lying.size.y < 0.5, "rugzak op straat zo groot als op de rug (%.2f m)" % lying.size.y)
