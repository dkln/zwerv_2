@tool
class_name TintMap
extends Node3D
## Adjust the colour/tint of tiles without changing the tile files (the "TintKaart" node;
## behaviour, docs/CODE_LAGEN.md).
##
## Put TintArea nodes (tint_area.gd) as children of this node and slide them over
## buildings or ground: everything inside an area gets that tint (works live in the
## editor). The areas are rasterised into a small texture with one pixel per 4x4 m cell,
## which the voxel shader samples via global shader parameters (tint_map_view.gd); which
## cells an area covers: tint_map_layout.gd.

const TintMapLayout = preload("res://scripts/world/town/tint_map_layout.gd")
const TintMapView = preload("res://scripts/world/town/tint_map_view.gd")

## Size of one map cell in metres (one texture pixel).
const CELL := TintMapLayout.CELL
## Seconds between two bakes in the editor.
const EDITOR_BAKE_INTERVAL := 0.25

@export var area_start := Vector2(0, 0)            ## world position (x, z) of the corner of the map, metres
@export var area_cells := Vector2i(96, 80)        ## number of 4 m cells in x and z
@export_range(0.0, 1.0) var variation := 0.25:
	set(v):
		variation = v
		_dirty = true

## Its picture: the texture and the shader parameters.
var view := TintMapView.new()

var _dirty := true
var _time := 0.0


func _ready() -> void:
	_bake()


## In the editor: rebakes four times per second (areas may have moved) or on change.
## In game the map is baked once in _ready.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_time += delta
	if _time > EDITOR_BAKE_INTERVAL or _dirty:
		_time = 0.0
		_dirty = false
		_bake()


## Rasterises the visible TintArea children (in child order, later ones on top) into
## the tint texture and publishes it plus the area and variation as shader globals.
func _bake() -> void:
	var map_cells := TintMapLayout.map_size(area_cells)
	view.start(map_cells)
	for child in get_children():
		if child is TintArea and child.visible:
			var area: TintArea = child
			var at := area.global_position
			var cells := TintMapLayout.covered_cells(Vector2(at.x, at.z), TintMapLayout.half_extent(area.size), area_start, map_cells)
			view.show_tint(cells, area.color, area.brightness, area.strength)
	view.publish(TintMapLayout.map_area(area_start, map_cells), variation)
