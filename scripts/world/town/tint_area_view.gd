@tool
extends MeshInstance3D
## What a tint area looks like in the editor (graphics; docs/CODE_LAGEN.md): a flat
## translucent box over the covered area, in the colour of the tint. tint_area.gd says how
## big and which colour (show_area); in the game there is none.
##   const TintAreaView = preload("res://scripts/world/town/tint_area_view.gd")

## The tint of a new area (white = no change).
const DEFAULT_TINT := Color(1, 0.85, 0.75)
## How see-through the box is.
const ALPHA := 0.25


func _init() -> void:
	mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material_override = material


## The box `box_size` metres big, in `tint` (see-through).
func show_area(box_size: Vector3, tint: Color) -> void:
	(mesh as BoxMesh).size = box_size
	(material_override as StandardMaterial3D).albedo_color = Color(tint.r, tint.g, tint.b, ALPHA)
