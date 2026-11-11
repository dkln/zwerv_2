extends SceneTree
## The rucksacks in the town (scripts/world/backpacks.gd, the node "Rugzakken" of
## scenes/stad.tscn): they lie on open ground once the player is placed, one near the start;
## the player starts without one and with only the pockets (Items.BASE_SLOTS); walking onto
## one puts it on (more room, worn on the figure: PlayerModel.backpack), it is gone from the
## street, and the others stay lying.
## usage: tools/godot.sh --headless --script tools/check/backpack_test.gd [-- <archetype>]

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Items = preload("res://scripts/player/items.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose(Common.arg(0, "martin"))
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var backpacks: Node = scene.get_node_or_null("Rugzakken")
	_check(backpacks != null, "rugzakken in de stad")
	if backpacks == null:
		quit(1)
		return
	for frame_index in 600:
		await physics_frame
		if backpacks._laid:
			break
	await physics_frame
	var lying: int = backpacks.backpacks_left()
	var nearest := INF
	for backpack: Node3D in backpacks._backpacks:
		nearest = minf(nearest, backpack.global_position.distance_to(player.global_position))
		print("rugzak bij ", backpack.global_position)
	print("rugzakken op straat: %d, dichtstbij %.1f m" % [lying, nearest])
	_check(lying >= 2, "rugzakken op straat")
	_check(nearest < backpacks.near + 5.0, "een rugzak vlak bij het begin")
	_check(not player.has_backpack and not player._model.backpack and player.inventory_slots() == Items.BASE_SLOTS, "begint zonder rugzak")
	# walk onto the nearest (put the player on it)
	var target: Node3D = backpacks._backpacks[0]
	for backpack: Node3D in backpacks._backpacks:
		if backpack.global_position.distance_to(player.global_position) < target.global_position.distance_to(player.global_position):
			target = backpack
	player._sleeping = false
	player.global_position = target.global_position
	for frame_index in 5:
		await physics_frame
	_check(player.has_backpack and player._model.backpack, "rugzak opgepakt en om")
	_check(player.inventory_slots() == Items.BASE_SLOTS + Items.BACKPACK_SLOTS, "meer ruimte (%d vakjes)" % player.inventory_slots())
	_check(backpacks.backpacks_left() == lying - 1, "weg van de straat, de andere blijven liggen")
	var worn := false
	for mesh_node in player._model.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = (mesh_node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			for colour: Color in mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
				worn = worn or (colour.g > colour.b * 1.2 and absf(colour.r - colour.g) < 0.12 and colour.g > 0.2)
	_check(worn, "rugzak te zien op het figuur")
	print("rugzak ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
