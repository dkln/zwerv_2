@tool
extends RefCounted
## The picture of the tint map (graphics; docs/CODE_LAGEN.md): the small texture with one
## pixel per cell that the voxel shader samples, and the global shader parameters that hand
## it over: `zwervr_tint_map` (RGB = tint * 0.5, A = strength; grey/transparent = no tint),
## `zwervr_tint_area` (x, z, width, depth of the covered area in metres) and
## `zwervr_variation`. tint_map.gd says which cells get which tint (start, show_tint,
## publish); this script decides nothing.
##   const TintMapView = preload("res://scripts/world/town/tint_map_view.gd")

## No tint: grey (the tint is stored at half intensity) and no strength.
const NO_TINT := Color(0.5, 0.5, 0.5, 0.0)
## A tint is stored at this share of its intensity, so brightness up to 2 fits in 8 bits.
const STORED_SHARE := 0.5

var _image: Image
var _texture: ImageTexture


## A new, empty map of `map_cells` pixels (no tint anywhere).
func start(map_cells: Vector2i) -> void:
	_image = Image.create(map_cells.x, map_cells.y, false, Image.FORMAT_RGBA8)
	_image.fill(NO_TINT)


## Gives `cells` (pixels of the map) the tint `colour` times `brightness`, applied for `strength`.
func show_tint(cells: Array[Vector2i], colour: Color, brightness: float, strength: float) -> void:
	var stored := stored_tint(colour, brightness, strength)
	for cell in cells:
		_image.set_pixel(cell.x, cell.y, stored)


## A tint as it is stored in a pixel: at half intensity, the strength in the alpha.
static func stored_tint(colour: Color, brightness: float, strength: float) -> Color:
	return Color(clampf(colour.r * brightness * STORED_SHARE, 0, 1),
		clampf(colour.g * brightness * STORED_SHARE, 0, 1),
		clampf(colour.b * brightness * STORED_SHARE, 0, 1), strength)


## The pixel of the map at `cell` as it is now (for the checks).
func tint_at(cell: Vector2i) -> Color:
	return _image.get_pixelv(cell)


## The size of the map in pixels (zero before start).
func map_size() -> Vector2i:
	return _image.get_size() if _image else Vector2i.ZERO


## Hands the map as it is now, the area it covers and the variation to the voxel shaders.
func publish(area: Vector4, variation: float) -> void:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	RenderingServer.global_shader_parameter_set("zwervr_tint_map", _texture)
	RenderingServer.global_shader_parameter_set("zwervr_tint_area", area)
	RenderingServer.global_shader_parameter_set("zwervr_variation", variation)
