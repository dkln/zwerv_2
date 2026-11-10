extends SceneTree
## The figures in the town have fewer details (PlayerModel.VoxelFigure.simplify): fewer
## colours and no lone voxels of another colour, the same shape (cells, height) and their eyes.
## usage: tools/godot.sh --headless --script tools/check/simple_figure_test.gd

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	for id: String in PlayerCharacter.ORDER:
		var full := PlayerModel.voxels_for(id)
		var simple := PlayerModel.voxels_for(id)
		simple.simplify()
		var full_colours := _colours(full)
		var simple_colours := _colours(simple)
		print("%s: %d kleuren -> %d, losse voxels %d -> %d" % [id, full_colours.size(), simple_colours.size(), _lone(full), _lone(simple)])
		_check(simple_colours.size() <= full_colours.size() and _lone(simple) <= 4, "%s heeft eenvoudig niet meer kleuren en geen losse spikkels (alleen de ogen)" % id)
		_check(simple.cells.size() == full.cells.size(), "%s houdt zijn vorm" % id)
		_check(simple_colours.has(PlayerModel.EYE_DARK) == full_colours.has(PlayerModel.EYE_DARK), "%s houdt zijn ogen" % id)
		var parts := PlayerModel.parts_for(id, true)
		_check(parts.meshes.has("body"), "%s wordt eenvoudig gebouwd" % id)
	print("eenvoudige figuren ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


static func _colours(figure: PlayerModel.VoxelFigure) -> Dictionary:
	var found := {}
	for cell: Vector3i in figure.cells:
		found[figure.cells[cell]] = true
	return found


## Voxels whose colour none of their six neighbours share, but three or more others do.
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
