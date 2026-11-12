extends RefCounted
## A glowing outline round every thing in the world you can pick up (the loose change, the
## rucksacks, the cans in the waste bins, the lost bank cards), so it stands out from the
## street: a pulsing rim (quest_outline.gdshader) as the item's material_overlay, and as its
## next pass a soft glow round it (quest_outline_glow.gdshader, GLOW_GROW times as wide,
## added onto what is behind). One material per mesh, grow and colour, shared.
##   QuestOutline.add(coin_instance, 0.025)

const SHADER := preload("res://scripts/effects/quest_outline.gdshader")
const GLOW_SHADER := preload("res://scripts/effects/quest_outline_glow.gdshader")
const COLOUR := Color("#FFB830")
## How much wider the glow is than the rim, and at least (metres).
const GLOW_GROW := 3.0
const GLOW_AT_LEAST := 0.06

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
		var glow := ShaderMaterial.new()
		glow.shader = GLOW_SHADER
		glow.set_shader_parameter("colour", colour)
		glow.set_shader_parameter("centre", instance.mesh.get_aabb().get_center())
		glow.set_shader_parameter("grow", maxf(grow * GLOW_GROW, GLOW_AT_LEAST))
		material.next_pass = glow
		_materials[key] = material
	instance.material_overlay = _materials[key]
