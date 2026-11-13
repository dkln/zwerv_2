extends "res://tests/integration/support/town_test.gd"
## The rucksacks in the town (scripts/world/backpacks.gd, the node "Rugzakken" of
## scenes/stad.tscn): they lie on open ground once the player is placed, one near the start;
## the player starts without one and with only the pockets (Items.BASE_SLOTS); walking onto
## one puts it on (more room, worn on the figure: PlayerModel.backpack), it is gone from the
## street, and the others stay lying.
##   tests/run_integration_tests.sh backpack

const Items = preload("res://scripts/player/items.gd")


## The node with the rucksacks, once they have been laid out (null if the town has none).
func _backpacks() -> Node:
	var backpacks: Node = scene.get_node_or_null("Rugzakken")
	if backpacks:
		await wait_until(func() -> bool: return backpacks._laid, 10.0)
		await physics_frames(1)
	return backpacks


## Whether the canvas of a rucksack (its green-grey) is among the colours of the player's figure.
func _backpack_on_figure() -> bool:
	for mesh_node in player._model.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = (mesh_node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			for colour: Color in mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
				if colour.g > colour.b * 1.2 and absf(colour.r - colour.g) < 0.12 and colour.g > 0.2:
					return true
	return false


## Rucksacks lie in the street, one of them close to where the player starts.
func test_rucksacks_lie_in_the_street_one_near_the_start(test) -> void:
	var backpacks := await _backpacks()
	test.check(backpacks != null, "rugzakken in de stad")
	if backpacks == null:
		return
	var nearest := INF
	for backpack: Node3D in backpacks._backpacks:
		nearest = minf(nearest, backpack.global_position.distance_to(player.global_position))
		print("rugzak bij ", backpack.global_position)
	print("rugzakken op straat: %d, dichtstbij %.1f m" % [backpacks.backpacks_left(), nearest])
	test.check(backpacks.backpacks_left() >= 2, "rugzakken op straat")
	test.check(nearest < backpacks.near + 5.0, "een rugzak vlak bij het begin")


## The player starts without a rucksack: none on the figure, only the pockets to carry in.
func test_player_starts_without_a_rucksack(test) -> void:
	test.check(not player.has_backpack and not player._model.backpack and player.inventory_slots() == Items.BASE_SLOTS, "begint zonder rugzak")


## Walking onto a rucksack puts it on: more room, to be seen on the figure, gone from the
## street while the others stay lying. (The one furthest from the start, so the one near
## the start stays for the other tests; the reset takes it off the player again.)
func test_walking_onto_one_puts_it_on(test) -> void:
	var backpacks := await _backpacks()
	test.check(backpacks != null and backpacks.backpacks_left() >= 1, "een rugzak om op te pakken")
	if backpacks == null or backpacks.backpacks_left() < 1:
		return
	var lying: int = backpacks.backpacks_left()
	var target: Node3D = backpacks._backpacks[0]
	for backpack: Node3D in backpacks._backpacks:
		if backpack.global_position.distance_to(player.global_position) > target.global_position.distance_to(player.global_position):
			target = backpack
	set_for_test(player, "has_backpack", false)
	set_for_test(player._model, "backpack", false)
	player.global_position = target.global_position
	await physics_frames(5)
	test.check(player.has_backpack and player._model.backpack, "rugzak opgepakt en om")
	test.check(player.inventory_slots() == Items.BASE_SLOTS + Items.BACKPACK_SLOTS, "meer ruimte (%d vakjes)" % player.inventory_slots())
	test.check(backpacks.backpacks_left() == lying - 1, "weg van de straat, de andere blijven liggen")
	test.check(_backpack_on_figure(), "rugzak te zien op het figuur")
