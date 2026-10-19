@tool
class_name TintMap
extends Node3D
## Adjust the colour/tint of tiles without changing the .vox (the "TintKaart" node).
##
## Put TintArea nodes (tint_area.gd) as children of this node and slide them over
## buildings or ground: everything inside an area gets that tint (works live in the
## editor). The areas are rasterised into a small texture with one pixel per 4x4 m cell,
## which the voxel shader samples via global shader parameters:
## `zwervr_tint_kaart` (RGB = tint * 0.5, A = strength; grey/transparent = no tint),
## `zwervr_tint_gebied` (x, z, width, depth of the covered area in metres) and
## `zwervr_variatie` ("variation": gives each cell a slightly different colour).

## Size of one map cell in metres (one texture pixel).
const CELL := 4.0

@export var area_start := Vector2(0, 0)            ## world position (x, z) of the corner of the map, metres
@export var area_cells := Vector2i(96, 80)        ## number of 4 m cells in x and z
@export_range(0.0, 1.0) var variation := 0.25:
	set(v):
		variation = v
		_dirty = true

var _dirty := true
var _time := 0.0
var _tex: ImageTexture


func _ready() -> void:
	_bake()


## In the editor: rebakes four times per second (areas may have moved) or on change.
## In game the map is baked once in _ready.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_time += delta
	if _time > 0.25 or _dirty:
		_time = 0.0
		_dirty = false
		_bake()


## Rasterises the visible TintArea children (in child order, later ones on top) into
## the tint texture and publishes it plus the area and variation as shader globals.
func _bake() -> void:
	var w := maxi(1, area_cells.x)
	var h := maxi(1, area_cells.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.0))
	for c in get_children():
		if c is TintArea and c.visible:
			var area: TintArea = c
			var p := area.global_position
			var half := Vector2(area.size) * CELL * 0.5   # half extent in metres
			# stored at half intensity so brightness up to 2 fits in 8 bits
			var col := Color(clampf(area.color.r * area.brightness * 0.5, 0, 1),
				clampf(area.color.g * area.brightness * 0.5, 0, 1),
				clampf(area.color.b * area.brightness * 0.5, 0, 1), area.strength)
			# only visit the cells near the area; the exact test below decides
			var x0 := maxi(0, floori((p.x - half.x - area_start.x) / CELL) - 1)
			var x1 := mini(w, ceili((p.x + half.x - area_start.x) / CELL) + 1)
			var z0 := maxi(0, floori((p.z - half.y - area_start.y) / CELL) - 1)
			var z1 := mini(h, ceili((p.z + half.y - area_start.y) / CELL) + 1)
			for x in range(x0, x1):
				for z in range(z0, z1):
					# cell centre inside the area?
					var cx := area_start.x + (x + 0.5) * CELL
					var cz := area_start.y + (z + 0.5) * CELL
					if absf(cx - p.x) <= half.x and absf(cz - p.z) <= half.y:
						img.set_pixel(x, z, col)
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	RenderingServer.global_shader_parameter_set("zwervr_tint_kaart", _tex)
	RenderingServer.global_shader_parameter_set("zwervr_tint_gebied", Vector4(area_start.x, area_start.y, w * CELL, h * CELL))
	RenderingServer.global_shader_parameter_set("zwervr_variatie", variation)
