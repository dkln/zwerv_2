extends RefCounted
## Unit tests of the figures with fewer details that walk in the town
## (PlayerModel.VoxelFigure.simplify, scripts/player/player_model.gd): fewer colours and no
## lone voxels of another colour, the same shape (cells) and their eyes.

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const SIDES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## The simplified voxels of character `id`.
static func _simplified(id: String) -> PlayerModel.VoxelFigure:
	var simple := PlayerModel.voxels_for(id)
	simple.simplify()
	return simple


## The colours `figure` has: {colour: true}.
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
		for side in SIDES:
			if figure.cells.has(cell + side):
				if figure.cells[cell + side] == colour:
					same += 1
				else:
					other += 1
		if same == 0 and other >= 3:
			count += 1
	return count


## Simplified, no character has more colours than in full, and no lone specks but its eyes.
func test_simple_has_no_more_colours_and_no_specks(test) -> void:
	for id: String in PlayerCharacter.ORDER:
		var full := PlayerModel.voxels_for(id)
		var simple := _simplified(id)
		var full_colours := _colours(full).size()
		var simple_colours := _colours(simple).size()
		print("%s: %d kleuren -> %d, losse voxels %d -> %d" % [id, full_colours, simple_colours, _lone(full), _lone(simple)])
		test.check(simple_colours <= full_colours and _lone(simple) <= 4, "%s heeft eenvoudig niet meer kleuren en geen losse spikkels (alleen de ogen)" % id)


## Simplifying only recolours: every character keeps all its cells.
func test_simple_keeps_its_shape(test) -> void:
	for id: String in PlayerCharacter.ORDER:
		test.check(_simplified(id).cells.size() == PlayerModel.voxels_for(id).cells.size(), "%s houdt zijn vorm" % id)


## The dark of the eyes survives simplifying.
func test_simple_keeps_its_eyes(test) -> void:
	for id: String in PlayerCharacter.ORDER:
		test.check(_colours(_simplified(id)).has(PlayerModel.EYE_DARK) == _colours(PlayerModel.voxels_for(id)).has(PlayerModel.EYE_DARK), "%s houdt zijn ogen" % id)


## The parts of a figure can be built simplified (a body mesh comes out).
func test_simple_figure_is_built(test) -> void:
	for id: String in PlayerCharacter.ORDER:
		test.check(PlayerModel.parts_for(id, true).meshes.has("body"), "%s wordt eenvoudig gebouwd" % id)
