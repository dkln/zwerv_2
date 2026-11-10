extends SceneTree
## The player figures (scripts/player/player_model.gd) and the townspeople
## (scripts/world/townsfolk_figure.gd): few details (colours, lone voxels), Martin's jacket one
## colour, nobody with a rucksack; the run (walking above 1) a run of its own and not the
## walk sped up: leaning forward, the knees driven up and bent deep, the elbows bent, off the
## ground between the steps, the feet never under the ground; the rucksack (picked up:
## PlayerController.pick_up_backpack) on the back clear of the figure, more room in the
## inventory, and the collider grown round it.
## usage: tools/godot.sh --headless --script tools/check/figure_run_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const Items = preload("res://scripts/player/items.gd")
const Backpacks = preload("res://scripts/world/backpacks.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 120)
	await process_frame   # nodes added to the root get _ready from the first frame on
	_check_details()
	_check_backpack_voxels()
	for archetype_id: String in PlayerCharacter.ORDER:
		await _check_run(archetype_id)
	await _check_inventory()
	print("figuren ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check_details() -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var figure := PlayerModel.voxels_for(archetype_id)
		var colours := {}
		for cell: Vector3i in figure.cells:
			colours[figure.cells[cell]] = true
		print("%s: %d voxels, %d kleuren, %d losse" % [archetype_id, figure.cells.size(), colours.size(), _lone(figure)])
		_check(colours.size() <= 15, "%s weinig kleuren (%d)" % [archetype_id, colours.size()])
		_check(_lone(figure) <= 4, "%s geen losse detailvoxels (%d)" % [archetype_id, _lone(figure)])
		_check(not colours.has(PlayerModel.BACKPACK_CANVAS), "%s heeft standaard geen rugzak" % archetype_id)
	# Martin's jacket: the chest, the collar and the sleeves one colour
	var martin := PlayerModel.voxels_for("martin")
	var jacket := {}
	for cell: Vector3i in martin.cells:
		var colour: Color = martin.cells[cell]
		if cell.y >= 15 and cell.y <= 25 and martin.kind_of(colour) not in ["skin", "eye", "hair"]:
			jacket[colour] = true
	_check(jacket.size() == 1, "Martins jas een kleur (%s)" % [jacket.keys()])
	# the townspeople: few colours, no rucksacks
	var with_bag := 0
	var most_colours := 0
	for look_seed in 60:
		var look := TownsfolkFigure.look_for(look_seed)
		with_bag += int(look.get("rucksack", false))
		var figure := PlayerModel.VoxelFigure.new()
		TownsfolkFigure._build_voxels(figure, look)
		var colours := {}
		for cell: Vector3i in figure.cells:
			colours[figure.cells[cell]] = true
		most_colours = maxi(most_colours, colours.size())
	print("voetgangers: hooguit %d kleuren, %d met rugzak" % [most_colours, with_bag])
	_check(with_bag == 0, "geen voetganger met een rugzak")
	_check(most_colours <= 11, "voetgangers weinig kleuren (%d)" % most_colours)


func _check_backpack_voxels() -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var bare := PlayerModel.voxels_for(archetype_id)
		var packed := PlayerModel.voxels_for(archetype_id, true)
		var place: Vector3i = PlayerModel.BACKPACK[archetype_id]
		var volume := 6 * (place.z - place.y + 1) * PlayerModel.BACKPACK_DEPTH
		var overlapping := 0
		for cell: Vector3i in bare.cells:
			if packed.cells[cell] != bare.cells[cell]:
				overlapping += 1
		_check(packed.cells.size() - bare.cells.size() == volume and overlapping == 0,
				"%s: rugzak los van het figuur (%d nieuw, %d overlap)" % [archetype_id, packed.cells.size() - bare.cells.size(), overlapping])
		# against the back: a voxel of the figure right in front of the rucksack
		var touching := false
		for y in range(place.y, place.z + 1):
			for x in range(4, 10):
				touching = touching or bare.has(x, y, place.x - 1)
		_check(touching, "%s: rugzak tegen de rug" % archetype_id)
		# not in an arm (it would swing with it)
		var parts := PlayerModel.parts_for(archetype_id, true, true)
		var bare_parts := PlayerModel.parts_for(archetype_id, true)
		for limb: String in PlayerModel.LIMBS:
			var with_pack: AABB = (parts.meshes[limb] as ArrayMesh).get_aabb()
			var without: AABB = (bare_parts.meshes[limb] as ArrayMesh).get_aabb()
			_check(with_pack.is_equal_approx(without), "%s: rugzak niet aan %s" % [archetype_id, limb])


## Runs the figure (walking 1.7, as the player's run) and walks it (1.0) for a few seconds:
## the extremes of its pose.
func _check_run(archetype_id: String) -> void:
	var model := PlayerModel.new()
	model.archetype_id = archetype_id
	model.simple = true
	model.idle = false
	get_root().add_child(model)
	await process_frame
	var walk := _sample(model, 1.0)
	var run := _sample(model, 1.7)
	print("%s lopen: %s" % [archetype_id, walk])
	print("%s rennen: %s" % [archetype_id, run])
	_check(walk.lean < 0.5 and walk.knee < 30.0 and walk.elbow > -5.0, "%s loopt rechtop, knieen licht gebogen" % archetype_id)
	_check(run.lean > 8.0, "%s leunt voorover bij het rennen" % archetype_id)
	_check(run.thigh_forward < -50.0 and run.knee > 90.0, "%s heft de knieen hoog en buigt ze diep" % archetype_id)
	_check(run.elbow < -70.0, "%s rent met gebogen ellebogen" % archetype_id)
	_check(run.bob > 0.06 and run.bob > walk.bob * 1.5, "%s komt los van de grond tussen de passen" % archetype_id)
	_check(run.steps > walk.steps * 1.3, "%s zet sneller passen" % archetype_id)
	_check(run.lowest > -0.03 and walk.lowest > -0.03, "%s voeten niet door de grond (%.3f, %.3f)" % [archetype_id, run.lowest, walk.lowest])
	model.queue_free()


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


## The inventory: only the pockets at first; a rucksack picked up gives more room, is worn,
## and the collider grows round it (and matches the figure).
func _check_inventory() -> void:
	PlayerCharacter.choose("martin")   # a slim one: the rucksack sticks out behind him
	var player: PlayerController = PlayerController.new()
	get_root().add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.set_process(false)
	player._model.idle = false
	player._model.set_process(false)
	_check(not player.has_backpack and player.inventory_slots() == Items.BASE_SLOTS, "zonder rugzak %d vakjes" % player.inventory_slots())
	player.inventory = {}
	for item_id: String in ["brood", "appel", "water", "bier"]:
		player.add_item(item_id)
	_check(not player.add_item("vis") and not player.inventory.has("vis"), "zakken vol: geen vijfde soort")
	_check(player.add_item("brood") and int(player.inventory.brood) == 2, "wel meer van wat je al hebt")
	var before: AABB = player._figure_box
	_check(_collider_matches(player), "botsvorm om het figuur zonder rugzak (%s)" % [before])
	_check(player.pick_up_backpack() and player.has_backpack and player._model.backpack, "rugzak opgepakt en om")
	_check(not player.pick_up_backpack(), "geen tweede rugzak")
	_check(player.inventory_slots() == Items.BASE_SLOTS + Items.BACKPACK_SLOTS, "met rugzak %d vakjes" % player.inventory_slots())
	_check(player.add_item("vis"), "met rugzak past er meer in")
	await process_frame
	var after: AABB = player._figure_box
	print("botsvorm zonder rugzak ", before, ", met ", after)
	_check(after.position.z <= before.position.z + 0.001 and is_equal_approx(after.size.y, before.size.y), "botsvorm niet kleiner met de rugzak")
	_check(_collider_matches(player), "botsvorm om het figuur met rugzak (%s)" % [after])
	# the rucksack lying in the town: the size of the one worn
	var lying: AABB = Backpacks.backpack_mesh().get_aabb()
	print("rugzak op straat ", lying)
	_check(lying.size.y > 0.3 and lying.size.y < 0.5, "rugzak op straat zo groot als op de rug (%.2f m)" % lying.size.y)
	player.queue_free()


## True if the collider box (Botsvorm) is the box round all meshes of the figure at rest.
func _collider_matches(player: PlayerController) -> bool:
	var shape: CollisionShape3D = player._body_shape
	var box := shape.shape as BoxShape3D
	var collider := AABB(shape.position - box.size * 0.5, box.size)
	var meshes: AABB = PlayerController._outer_box(player._model)
	print("  botsvorm ", collider, " mesh ", meshes)
	return collider.position.distance_to(meshes.position) < 0.02 and collider.size.distance_to(meshes.size) < 0.02


static func _lone(figure: PlayerModel.VoxelFigure) -> int:
	var count := 0
	for cell: Vector3i in figure.cells:
		var colour: Color = figure.cells[cell]
		var same := 0
		var other := 0
		for side: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if figure.cells.has(cell + side):
				if figure.cells[cell + side] == colour:
					same += 1
				else:
					other += 1
		if same == 0 and other >= 3:
			count += 1
	return count


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
