@tool
class_name GroundMap
extends Node
## Ground types (the "GrondKaart" node): one texture pixel per 4 x 4 m cell of the Grond
## GridMap at street level, R = the cell's kind of ground (the main material of its top
## and its colour group, so red asphalt (cycle path) differs from grey asphalt (road);
## or grass), G = a fake height rank (RANK). The voxel shader draws a border wherever a
## ground tile meets another kind of ground: a rounded, lighter edge on the higher side,
## a contact shadow on the lower side and a dark joint (voxel.gdshader,
## `zwervr_ground_edges`).
## Global shader parameters: `zwervr_ground_types` and `zwervr_ground_area` (x, z,
## width, depth in metres). Built in _ready, and again with rebuild() when the map changes
## (the tour loads another map part, scripts/world_parts.gd); in the editor every
## couple of seconds, so it follows editing.

## Size of one map cell in metres (one texture pixel).
const CELL := 4.0
## Material names as the mesher names a tile's surfaces (vox_parser.gd MATERIAL_NAMES).
const MATERIALS := preload("res://addons/vox_tiles/vox_parser.gd").MATERIAL_NAMES

## The ground types were rebuilt (grass_cells changed).
signal rebuilt

@export var ground_path := NodePath("../Grond")

## Ground type of a grass cell in the type map (the others: material index + 1 +
## 20 x colour group, see _type).
const TYPE_GRASS := 200
## Lowest height (m, tile-local) of grass that counts for the mask: the top of a grass
## tile is at 0.375 m.
const GRASS_LEVEL := 0.3
## Blade height factors (scripts/grass_blades.gd blade_height): short and tall grass.
const SHORT_GRASS := 0.45
const TALL_GRASS := 1.5
## Resolution of a tile's grass mask (one per voxel of a 4 m tile).
const MASK := 32
## mesh -> grass mask (see grass_cells)
static var _masks := {}
## Fake height of each kind of ground (0 = lowest): the road lowest, the cycle path just
## above it, then cobbles and pavers, gravel and earth, grass, and the pavement highest.
## Keys: material name, "asphalt_red" for red asphalt, "grass"; others use DEFAULT_RANK.
const RANK := {"asphalt": 0.0, "asphalt_red": 0.5, "cobble": 1.0, "stone": 1.0, "gravel": 1.2,
	"opaque": 1.2, "grass": 1.5, "brick": 1.5, "paving": 2.0}
const DEFAULT_RANK := 1.5

## mesh -> [ground type, rank, grass share of the top]
static var _tiles := {}

var _types: ImageTexture
## Cells at street level with grass on top, after the last rebuild: Vector2i(x, z) ->
## [mask, basis, height]: mask = PackedByteArray of MASK x MASK (1 = grass at that spot of
## the tile's top, in tile-local voxels), basis = the cell's rotation, height = blade
## height factor (TALL_GRASS on tiles named "gras_hoog", else SHORT_GRASS). The grass blades grow
## only on the grass parts (scripts/grass_blades.gd), so also along paths and banks but
## never through gravel or water.
var grass_cells := {}
var _time := 0.0


func _ready() -> void:
	rebuild()


## In the editor: rebuilds every two seconds (the map may have been edited).
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_time += delta
	if _time > 2.0:
		_time = 0.0
		rebuild()


## Rasterises the ground types of the Grond GridMap into the texture and publishes it.
func rebuild() -> void:
	var gm := get_node_or_null(ground_path) as GridMap
	if gm == null or gm.mesh_library == null:
		return
	# the top cell of every column (x, z), at street level only
	var top := {}
	for c in gm.get_used_cells():
		var k := Vector2i(c.x, c.z)
		if not top.has(k) or c.y > top[k].y:
			top[k] = c
	if top.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for k in top:
		lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
		hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
	var size := hi - lo + Vector2i.ONE
	var types := Image.create(size.x, size.y, false, Image.FORMAT_RG8)   # R = type (0 = none), G = rank / 4
	var grass := {}
	for k in top:
		var c: Vector3i = top[k]
		if c.y != 0:
			continue
		var info := _tile(gm.mesh_library.get_item_mesh(gm.get_cell_item(c)))
		if info[2] > 0.02:
			var mesh := gm.mesh_library.get_item_mesh(gm.get_cell_item(c))
			var tall := gm.mesh_library.get_item_name(gm.get_cell_item(c)).contains("gras_hoog")
			grass[k] = [_grass_mask(mesh), gm.get_basis_with_orthogonal_index(gm.get_cell_item_orientation(c)),
				TALL_GRASS if tall else SHORT_GRASS]
		types.set_pixel(k.x - lo.x, k.y - lo.y, Color(info[0] / 255.0, info[1] / 4.0, 0))
	if _types == null or _types.get_size() != Vector2(size):
		_types = ImageTexture.create_from_image(types)
	else:
		_types.update(types)
	# cell (x, z) spans x*4 .. x*4+4 (the Grond GridMap centres its tiles)
	var origin := Vector2(lo) * CELL + Vector2(gm.position.x, gm.position.z)
	RenderingServer.global_shader_parameter_set("zwervr_ground_types", _types)
	grass_cells = grass
	rebuilt.emit()
	RenderingServer.global_shader_parameter_set("zwervr_ground_area", Vector4(origin.x, origin.y, size.x * CELL, size.y * CELL))


## [ground type, rank, share of the top that is grass] of a tile mesh, from its vertex colours (the faces' average
## colours) and its surfaces (one per material, named after it): TYPE_GRASS when at
## least half of the top is grass, else the material with the largest top area and the
## colour group of that material's top. Cached per mesh.
static func _tile(mesh: Mesh) -> Array:
	if mesh == null:
		return [0, 0.0, 0.0]
	if _tiles.has(mesh):
		return _tiles[mesh]
	var total := 0.0
	var grass := 0.0
	var per_material := {}   # material index -> top area
	var colour := {}         # material index -> area-weighted colour of its top
	for s in mesh.get_surface_count():
		var material := MATERIALS.find(mesh.surface_get_name(s))
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var col = a[Mesh.ARRAY_COLOR]
		if col == null or (col as PackedColorArray).size() != v.size():
			continue
		for i in range(0, v.size() - 2, 3):
			if n[i].y < 0.9:
				continue
			var area := (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).length() * 0.5
			total += area
			per_material[material] = per_material.get(material, 0.0) + area
			var k: Color = col[i]
			colour[material] = colour.get(material, Color(0, 0, 0)) + k * area
			if _is_grass(k):
				grass += area
	var info := [0, 0.0, grass / total if total > 0.0 else 0.0]
	var best := -1
	for m in per_material:
		if m >= 0 and (best < 0 or per_material[m] > per_material[best]):
			best = m
	if total > 0.0 and grass >= total * 0.5:
		info = [TYPE_GRASS, RANK["grass"], grass / total]
	elif best >= 0:
		var c: Color = colour[best] / per_material[best]
		var group := _colour_group(c)
		info[0] = mini(best + 1 + 20 * group, TYPE_GRASS - 1)
		var key: String = MATERIALS[best]
		if key == "asphalt" and group == 1:
			key = "asphalt_red"
		info[1] = RANK.get(key, DEFAULT_RANK)
	_tiles[mesh] = info
	return info


## Where the top of a tile mesh is grass: MASK x MASK bytes over the tile's 4 x 4 m
## (x then z, from -2 m), from its up-facing triangles with a grass colour. Cached.
static func _grass_mask(mesh: Mesh) -> PackedByteArray:
	if _masks.has(mesh):
		return _masks[mesh]
	var mask := PackedByteArray()
	mask.resize(MASK * MASK)
	var step := CELL / MASK
	for s in mesh.get_surface_count():
		# not on floating things (water lilies): their material bobs on the water
		var mat := mesh.surface_get_material(s)
		if mat and str(mat.get_meta("base_path", mat.resource_path)).contains("drijf"):
			continue
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var col = a[Mesh.ARRAY_COLOR]
		if col == null or (col as PackedColorArray).size() != v.size():
			continue
		for i in range(0, v.size() - 2, 3):
			# only grass at street level (not under water or down a bank)
			if n[i].y < 0.9 or not _is_grass(col[i]) or v[i].y < GRASS_LEVEL:
				continue
			var lo := v[i].min(v[i + 1]).min(v[i + 2])
			var hi := v[i].max(v[i + 1]).max(v[i + 2])
			for mz in range(clampi(floori((lo.z + 2.0) / step), 0, MASK), clampi(ceili((hi.z + 2.0) / step), 0, MASK)):
				for mx in range(clampi(floori((lo.x + 2.0) / step), 0, MASK), clampi(ceili((hi.x + 2.0) / step), 0, MASK)):
					mask[mz * MASK + mx] = 1
	_masks[mesh] = mask
	return mask


## Colour group of a (linear) colour: 0 = neutral grey, 1 = red, 2 = yellow/brown,
## 3 = green, 4 = blue.
static func _colour_group(c: Color) -> int:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	if mx <= 0.0 or mx - mn < 0.25 * mx:
		return 0
	if mx == c.r:
		return 1 if c.g < c.r * 0.75 else 2
	return 3 if mx == c.g else 4


## Same test as is_grass() in voxel.gdshader.
static func _is_grass(k: Color) -> bool:
	return k.g > k.r * 1.15 and k.g > k.b * 1.4 and k.g > 0.02
