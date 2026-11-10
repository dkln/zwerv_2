extends RefCounted
## An outline round a quest item in the world (the loose change of mission 1, the rucksacks),
## so it stands out a little more from the street (quest_outline.gdshader: a pulsing rim as
## the item's material_overlay). One material per mesh and grow, shared.
##   QuestOutline.add(coin_instance, 0.025)

const SHADER := preload("res://scripts/effects/quest_outline.gdshader")
const COLOUR := Color("#FFB830")

static var _materials := {}   # [mesh instance id, grow] -> ShaderMaterial


## Puts the outline on `instance` (its mesh), `grow` metres wide.
static func add(instance: MeshInstance3D, grow: float, colour := COLOUR) -> void:
	if instance == null or instance.mesh == null:
		return
	var key := [instance.mesh.get_instance_id(), grow, colour]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("colour", colour)
		material.set_shader_parameter("centre", instance.mesh.get_aabb().get_center())
		material.set_shader_parameter("grow", grow)
		_materials[key] = material
	instance.material_overlay = _materials[key]
