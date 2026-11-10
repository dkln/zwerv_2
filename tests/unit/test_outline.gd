extends RefCounted
## Unit tests of Outline.apply (scripts/effects/outline.gd): the hard outline on the meshes of
## what moves about, but not twice, not on a character (it has its own) and not on glass.

const Outline = preload("res://scripts/effects/outline.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")


func test_a_plain_mesh_gets_the_outline(test) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = BoxMesh.new()
	Outline.apply(instance)
	var overlay := instance.material_overlay as ShaderMaterial
	test.check(overlay != null and overlay.shader == PlayerModel.OUTLINE_SHADER, "omlijning als overlay")
	test.check(overlay != null and bool(overlay.get_shader_parameter("from_centre")), "vanuit het midden naar buiten")
	instance.free()


func test_a_character_and_glass_are_left_alone(test) -> void:
	var character := MeshInstance3D.new()
	character.mesh = BoxMesh.new()
	character.material_override = PlayerModel.material_for("skin", true)
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	var see_through := StandardMaterial3D.new()
	see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = see_through
	Outline.apply(character)
	Outline.apply(glass)
	test.check(character.material_overlay == null, "een karakter heeft zijn eigen omlijning")
	test.check(glass.material_overlay == null, "glas niet")
	character.free()
	glass.free()
