extends RefCounted
## Unit tests of the figures of the characters to choose from (PlayerModel.parts_for for
## every archetype of PlayerCharacter.ORDER): each has all its limbs and enough detail.

const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
## Triangles a figure has at least.
const LEAST_TRIANGLES := 500


## Every character's figure has a mesh for every limb.
func test_every_character_has_all_its_limbs(test) -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var parts := PlayerModel.parts_for(archetype_id)
		for limb: String in PlayerModel.LIMBS:
			test.check(parts.meshes.has(limb), "%s heeft een %s" % [archetype_id, limb])


## Every character's figure is detailed: at least LEAST_TRIANGLES triangles over its parts.
func test_every_character_is_detailed_enough(test) -> void:
	for archetype_id: String in PlayerCharacter.ORDER:
		var parts := PlayerModel.parts_for(archetype_id)
		var triangles := 0
		for part: String in parts.meshes:
			var mesh: ArrayMesh = parts.meshes[part]
			for surface in mesh.get_surface_count():
				triangles += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		test.check(triangles >= LEAST_TRIANGLES, "%s heeft genoeg detail (%d driehoeken, %.2f m hoog)" % [archetype_id, triangles, parts.height])
