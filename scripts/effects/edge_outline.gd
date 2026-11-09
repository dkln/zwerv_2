extends MeshInstance3D
## The outlines of the town (edge_outline.gdshader): a full-screen quad hung on the camera
## (FollowCamera adds it to the camera it drives), drawn after everything else, that puts a
## thin ink line where one thing ends and the next begins, so buildings, pavement, figures
## and cars stand apart instead of running into each other. `strength` sets how dark.

const SHADER := preload("res://scripts/effects/edge_outline.gdshader")

@export_range(0.0, 1.0) var strength := 0.6:
	set(value):
		strength = value
		if _material:
			_material.set_shader_parameter("strength", value)

var _material: ShaderMaterial


func _ready() -> void:
	name = "Randjes"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.flip_faces = true
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = 127   # after the other see-through things
	_material.set_shader_parameter("strength", strength)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# never culled: it covers the screen wherever the camera looks
	extra_cull_margin = 16384.0
	ignore_occlusion_culling = true
