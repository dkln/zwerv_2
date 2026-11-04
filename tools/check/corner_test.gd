extends SceneTree
## Checks every square road corner of the city (tools/voxgen/tiles/ground_corners.py): a lane
## leads into it where the tile is entered, one lane leads on where it comes out, and it
## is not taken for a crossing.
##   tools/godot.sh --headless --script tools/check/corner_test.gd

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self, 120)
	var scene: Node = (load("res://scenes/stad.tscn") as PackedScene).instantiate()
	var network := RoadNetwork.new(scene.get_node("Grond") as GridMap)
	var corners := 0
	var problems := 0
	for cell: Vector3i in network.cells():
		if not network.tile_name(cell).contains("_hoek_"):
			continue
		corners += 1
		var entering := network.heading_of_side(cell, "N")
		var leaving: Array[Vector2i] = network.lanes(cell)
		var before := network.step(cell, -entering)
		var problem := ""
		if leaving.size() != 1:
			problem = "has %d lanes" % leaving.size()
		elif network.is_crossing(cell):
			problem = "counts as a crossing"
		elif before == RoadNetwork.NONE or not network.lanes(before).has(entering):
			problem = "no lane leads into it, heading %s" % entering
		else:
			var after := network.step(cell, leaving[0])
			if after == RoadNetwork.NONE or not network.lanes(after).has(leaving[0]):
				problem = "no lane leads on, heading %s" % leaving[0]
		if problem != "":
			problems += 1
			print("FAIL ", cell, " ", network.tile_name(cell), ": ", problem)
	print("corners: %d, problems: %d" % [corners, problems])
	scene.free()
	quit(1 if problems > 0 or corners == 0 else 0)
