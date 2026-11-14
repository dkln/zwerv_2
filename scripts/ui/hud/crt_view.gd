extends ColorRect
## What the CRT look of the HUD looks like (the node "CRT"; graphics, docs/CODE_LAGEN.md):
## a layer over the whole window whose shader (UiStyle.CRT_SHADER) bulges the world like
## the glass of a tube, its edges bending in to black rounded corners, and lays the
## picture of the HUD (show_picture) over it, bent a little less. It shows the numbers it
## is handed (show_crt; worked out with crt_rules.gd).
##   const CrtView = preload("res://scripts/ui/hud/crt_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")


func _init() -> void:
	name = "CRT"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = UiStyle.CRT_SHADER
	material = shader_material
	# outside the scaled design: always the whole window, in real screen lines
	set_anchors_preset(Control.PRESET_FULL_RECT)


## The picture of the HUD, laid over the world.
func show_picture(picture: Texture2D) -> void:
	(material as ShaderMaterial).set_shader_parameter("ui_texture", picture)


## The bulge of the world and of the HUD, the rounding of the corners and the size of the
## screen in real lines.
func show_crt(curvature: float, ui_curvature: float, corner: float, screen_size: Vector2) -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("curvature", curvature)
	shader_material.set_shader_parameter("ui_curvature", ui_curvature)
	shader_material.set_shader_parameter("corner", corner)
	shader_material.set_shader_parameter("screen_size", screen_size)


## What the shader was last handed for `parameter` ("curvature", "ui_curvature", "corner",
## "screen_size", "ui_texture").
func shown(parameter: String) -> Variant:
	return (material as ShaderMaterial).get_shader_parameter(parameter)
