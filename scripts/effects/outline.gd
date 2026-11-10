extends RefCounted
## The hard outline of everything that moves about: the vehicles (cars, buses, trams, trains,
## bicycles, the helicopter) and what the townspeople ride, as the characters have one
## (scripts/player/figure_outline.gdshader). The characters' own meshes have it already, as the
## next pass of their materials (PlayerModel.material_for, outlined); every other mesh under a
## node gets it here as its material_overlay, pushed out from the middle of its mesh (one
## material per mesh, kept on the mesh itself as meta OUTLINE_META, so it goes with it).
## Transparent meshes (glass discs, blurs) are left out.
##   Outline.apply(self)   # after the node has built its meshes

const PlayerModel = preload("res://scripts/player/player_model.gd")

const OUTLINE_META := "outline_material"


## The outline on every mesh under `root` (and `root` itself) that has none yet.
static func apply(root: Node) -> void:
	if root == null:
		return
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var instance := node as MeshInstance3D
		if instance.mesh == null or instance.material_overlay != null or _outlined(instance) or _transparent(instance):
			continue
		instance.material_overlay = _material_for(instance.mesh)


static func _material_for(mesh: Mesh) -> ShaderMaterial:
	if not mesh.has_meta(OUTLINE_META):
		var material := PlayerModel.outline_material().duplicate() as ShaderMaterial
		material.set_shader_parameter("from_centre", true)
		material.set_shader_parameter("centre", mesh.get_aabb().get_center())
		mesh.set_meta(OUTLINE_META, material)
	return mesh.get_meta(OUTLINE_META)


## A character's mesh: its materials have the outline as their next pass.
static func _outlined(instance: MeshInstance3D) -> bool:
	for surface in instance.mesh.get_surface_count():
		var material := instance.get_active_material(surface)
		if material and material.next_pass == PlayerModel.outline_material():
			return true
	return false


static func _transparent(instance: MeshInstance3D) -> bool:
	for surface in instance.mesh.get_surface_count():
		var material := instance.get_active_material(surface) as BaseMaterial3D
		if material and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false
