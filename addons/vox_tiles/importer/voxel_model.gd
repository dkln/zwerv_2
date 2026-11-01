@tool
extends RefCounted
## A voxel tile in memory, whatever file it came from: a Goxel .gox (gox_parser.gd,
## the tile format of Zwervr) or a MagicaVoxel .vox (vox_parser.gd, still readable).
## The mesher (vox_mesher.gd) and slopes.gd only see this model.
##
## Every voxel holds a colour index (1..255) into `palette`; `materials` gives the
## material (MAT_*) per index. load_file() works the material of every colour out, the
## first rule that applies wins:
##   1. the tile metadata "materials" (tile_metadata.gd): "#rrggbb", or for a .vox
##      also a palette index;
##   2. a material layer: a Goxel layer (or the Goxel material of a layer) named after
##      a material in MATERIAL_NAMES, e.g. a layer "glass";
##   3. the colour table of the project (COLOUR_TABLE, written by tools/voxgen from the
##      palette): every palette colour has one material, so a tile only stores colours;
##   4. what the file says itself: a MagicaVoxel MATL (glass, emit, metal);
##   5. opaque.

const MAT_OPAQUE := 0
const MAT_METAL := 1
const MAT_GLASS := 2
const MAT_EMIT := 3
const MAT_WATER := 4
const MAT_FLAG := 5
## shiny metal, e.g. solar panels (MagicaVoxel: metal with _rough < 0.15)
const MAT_PANEL := 6
## road surface: grain, wear patches and a slight sheen
const MAT_ASPHALT := 7
## paving, cobbles, natural stone
const MAT_STONE := 8
## brickwork: brick bond with mortar joints in the lighting
const MAT_BRICK := 9
## gravel: small round pebbles
const MAT_GRAVEL := 10
## painted metal: semi-gloss paint with a slight metallic sheen, e.g. lamp posts and
## road signs
const MAT_PAINTED := 11
## paving tiles of 3 x 3 voxels
const MAT_PAVING := 12
## cobbles: domed stones of 2 x 2 voxels
const MAT_COBBLE := 13
## plaster / stucco walls: hairline cracks and pits
const MAT_PLASTER := 14

## Names of the materials, indexed by MAT_*; used in the colour table, the tile
## metadata, as Goxel layer names and as surface names.
const MATERIAL_NAMES := ["opaque", "metal", "glass", "emit", "water", "flag", "panel", "asphalt", "stone", "brick", "gravel", "painted", "paving", "cobble", "plaster"]

## "#rrggbb" -> material name for every palette colour that is not plain opaque
## (tools/voxgen/vox.py write_material_table).
const COLOUR_TABLE := "res://assets/tiles/materialen.json"
## File extensions of a tile model, preferred first.
const EXTENSIONS := ["gox", "vox"]

var size := Vector3i.ZERO
var voxels := PackedByteArray()   # x, y, z, colour index (4 bytes per voxel)
var palette := PackedColorArray()  # index 0..255 (0 = empty)
var materials := PackedByteArray() # material per colour index
## Per colour index, filled by the parsers: the material of a material layer (rule 2)
## or -1, and the material the file gives itself (rule 4) or -1.
var layer_materials := PackedInt32Array()
var file_materials := PackedInt32Array()
## True for a .vox: metadata keys may be palette indices.
var indexed := false

static var _table := {}
static var _table_time := -1


func _init() -> void:
	palette.resize(256)
	materials.resize(256)
	layer_materials.resize(256)
	layer_materials.fill(-1)
	file_materials.resize(256)
	file_materials.fill(-1)


## True for materials you can't see through (everything except glass and water).
## Opaque voxels hide neighbouring faces and count as closed for merging.
static func is_opaque(material: int) -> bool:
	return material != MAT_GLASS and material != MAT_WATER


## True for a file the importer reads as a tile model (.gox or .vox).
static func is_model_file(path: String) -> bool:
	return path.get_extension() in EXTENSIONS


## Reads a tile model and resolves its materials (see the top of this file) with
## the tile metadata `meta`; returns null (and reports an error) if it can't be read.
static func load_file(path: String, meta := {}) -> RefCounted:
	var model: RefCounted = null
	match path.get_extension():
		"gox":
			model = load("res://addons/vox_tiles/importer/gox_parser.gd").load_file(path)
		"vox":
			model = load("res://addons/vox_tiles/importer/vox_parser.gd").load_file(path)
		_:
			push_error("voxel: %s is not a .gox or .vox file" % path)
	if model != null:
		model.resolve_materials(meta, path)
	return model


## Fills `materials` from the rules at the top of this file.
func resolve_materials(meta: Dictionary, path := "") -> void:
	var table := colour_table()
	var by_colour := {}
	var by_index := {}
	var mats = meta.get("materials", {})
	if mats is Dictionary:
		for key in mats:
			var mat := MATERIAL_NAMES.find(str(mats[key]))
			var k := str(key)
			if mat < 0:
				push_warning("voxel: %s: unknown material '%s' (use %s)" % [path.get_basename() + ".tile.json", mats[key], ", ".join(MATERIAL_NAMES)])
			elif k.begins_with("#"):
				by_colour[Color.html(k).to_html(false)] = mat
			elif indexed and k.is_valid_int() and int(k) >= 1 and int(k) <= 255:
				by_index[int(k)] = mat
			else:
				push_warning("voxel: %s: material key '%s' is not a \"#rrggbb\" colour" % [path.get_basename() + ".tile.json", k])
	for i in range(1, 256):
		var html := palette[i].to_html(false)
		var m := MAT_OPAQUE
		if by_index.has(i):
			m = by_index[i]
		elif by_colour.has(html):
			m = by_colour[html]
		elif layer_materials[i] >= 0:
			m = layer_materials[i]
		elif table.has(html):
			m = table[html]
		elif file_materials[i] >= 0:
			m = file_materials[i]
		materials[i] = m


## The colour table (COLOUR_TABLE) as "rrggbb" -> MAT_*; read again when the file changed.
static func colour_table() -> Dictionary:
	var t := FileAccess.get_modified_time(COLOUR_TABLE) if FileAccess.file_exists(COLOUR_TABLE) else 0
	if t == _table_time:
		return _table
	_table_time = t
	_table = {}
	if t == 0:
		push_warning("voxel: %s is missing; colours get their material from the tile files only (run tools/voxgen/generate.py)" % COLOUR_TABLE)
		return _table
	var data = JSON.parse_string(FileAccess.get_file_as_string(COLOUR_TABLE))
	if not data is Dictionary:
		push_warning("voxel: %s is not a valid JSON object, ignored" % COLOUR_TABLE)
		return _table
	for key in data:
		var mat := MATERIAL_NAMES.find(str(data[key]))
		if mat < 0:
			push_warning("voxel: %s: unknown material '%s' for %s" % [COLOUR_TABLE, data[key], key])
			continue
		_table[Color.html(str(key)).to_html(false)] = mat
	return _table
