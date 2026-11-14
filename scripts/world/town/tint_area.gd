@tool
class_name TintArea
extends Node3D
## A rectangle (in 4 m cells, centred on this node) that gives everything beneath it a
## tint (behaviour; docs/CODE_LAGEN.md). Must be a child of a TintMap (tint_map.gd), which
## rasterises the areas. White = no change; brightness > 1 makes it lighter, < 1 darker.
## In the editor a translucent box shows the covered area (tint_area_view.gd; its size:
## tint_map_layout.gd).

const TintAreaView = preload("res://scripts/world/town/tint_area_view.gd")
const TintMapLayout = preload("res://scripts/world/town/tint_map_layout.gd")

## Tint colour multiplied onto the tiles (white = unchanged).
@export var color: Color = TintAreaView.DEFAULT_TINT:
	set(v):
		color = v
		_update_preview()
## Multiplier on the colour (0 to 2).
@export_range(0.0, 2.0) var brightness := 1.0
## How much of the tint is applied (0 = none, 1 = full).
@export_range(0.0, 1.0) var strength := 1.0
## Size in 4 m cells along x and z (at least 1x1).
@export var size := Vector2i(1, 1):
	set(v):
		size = Vector2i(maxi(1, v.x), maxi(1, v.y))
		_update_preview()

var _preview: TintAreaView


func _ready() -> void:
	_update_preview()


## Editor only: creates or updates the translucent preview box (size and colour).
func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = TintAreaView.new()
		add_child(_preview)
	_preview.show_area(TintMapLayout.preview_size(size), color)
