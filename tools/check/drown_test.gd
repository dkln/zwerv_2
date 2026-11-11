extends SceneTree
## Falling into the water (scripts/player/player_controller.gd): next to a canal the player
## finds the water there (_water_point), and once in it, splashes (WaterSplash), sinks and
## drowns ("verdronken", the HUD's death text).
## usage: tools/godot.sh --headless --script tools/check/drown_test.gd

const Common = preload("res://tools/tool_common.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 200)
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	for frame_index in 240:
		await physics_frame
		if player._placed:
			break
	player._sleeping = false
	# a cell of open water in the ground layer
	var ground: GridMap = scene.get_node("Grond")
	var water_cell := Vector3i.MAX
	for cell in ground.get_used_cells():
		var item_name := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
		if item_name.begins_with("water/") and not item_name.contains("kademuur"):
			water_cell = cell
			break
	_check(water_cell != Vector3i.MAX, "water in de stad")
	var over_water := ground.to_global(ground.map_to_local(water_cell))
	player.global_position = over_water + Vector3.UP * 1.0
	await physics_frame
	var water: Vector3 = player._water_point(over_water)
	print("water bij ", water_cell, ": ", water)
	_check(water != Vector3.INF, "water gevonden onder de speler")
	var causes := []
	player.died.connect(func(cause: String) -> void: causes.append(cause))
	# jumping in: in the air over the water it comes down in it by itself
	player.global_position = over_water + Vector3.UP * 2.0
	player._takeoff_height = player.global_position.y
	player._airborne = true
	player._vertical_speed = 0.0
	for frame_index in 90:
		await physics_frame
		if player._drowning:
			break
	_check(player._drowning, "in het water gesprongen: erin")
	if not player._drowning:
		player._fall_into_water(water if water != Vector3.INF else over_water)
	await create_timer(0.6).timeout
	_check(scene.find_children("*", "CPUParticles3D", true, false).size() > 0, "plons: druppels en bellen")
	await create_timer(player.drown_time + 0.5).timeout
	print("doodsoorzaak: ", causes)
	_check(causes == ["verdronken"], "verdronken")
	_check(scene.get_node("HUD").DEATH_CAUSES.has("verdronken"), "doodstekst voor verdrinken")
	print("verdrinken ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
