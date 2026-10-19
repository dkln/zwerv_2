@tool
extends RefCounted
## Reads a MagicaVoxel .vox file: the first model, the palette and a material per
## palette index. Materials come from the MATL chunks MagicaVoxel writes (diffuse,
## metal, glass, emit) plus two reserved palette ranges (water, flag); the tile
## metadata can override them afterwards (tile_metadata.gd).

const MAT_OPAQUE := 0
const MAT_METAL := 1
const MAT_GLASS := 2
const MAT_EMIT := 3
const MAT_WATER := 4
const MAT_FLAG := 5
## shiny metal (MagicaVoxel: metal with _rough < 0.15), e.g. solar panels
const MAT_PANEL := 6
## road surface: grain, wear patches and a slight sheen (only via tile metadata)
const MAT_ASPHALT := 7
## paving, cobbles, natural stone (only via tile metadata)
const MAT_STONE := 8

## Names of the materials, indexed by MAT_*; used in tile metadata and as surface names.
const MATERIAL_NAMES := ["opaque", "metal", "glass", "emit", "water", "flag", "panel", "asphalt", "stone"]

## Palette indices treated as water (glass material in MagicaVoxel).
const WATER_START := 225
const WATER_END := 232
## Palette indices treated as a waving flag.
const FLAG_START := 233
const FLAG_END := 248

var size := Vector3i.ZERO
var voxels := PackedByteArray()   # x, y, z, colour index (4 bytes per voxel)
var palette := PackedColorArray()  # index 0..255 (0 = empty)
var materials := PackedByteArray() # material per colour index


## True for materials you can't see through (everything except glass and water).
## Opaque voxels hide neighbouring faces and count as closed for merging.
static func is_opaque(material: int) -> bool:
	return material != MAT_GLASS and material != MAT_WATER


## Parses a .vox file; returns null (and reports an error) if it can't be read.
static func load_file(path: String) -> RefCounted:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("vox: cannot open %s" % path)
		return null
	if f.get_buffer(4).get_string_from_ascii() != "VOX ":
		push_error("vox: %s is not a MagicaVoxel file" % path)
		return null
	f.get_32() # version
	var out = load("res://addons/vox_tiles/vox_parser.gd").new()
	out.palette.resize(256)
	out.materials.resize(256)
	for i in 256:
		out.palette[i] = Color(0.6, 0.6, 0.6)
	var got_size := false
	var got_xyzi := false
	var matl_types := {}
	var matl_rough := {}
	while f.get_position() < f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var content := f.get_32()
		var children := f.get_32()
		var start := f.get_position()
		match id:
			"MAIN":
				continue # children follow directly
			"SIZE":
				if not got_size:
					out.size = Vector3i(f.get_32(), f.get_32(), f.get_32())
					got_size = true
			"XYZI":
				if not got_xyzi:
					var n := f.get_32()
					out.voxels = f.get_buffer(n * 4)
					got_xyzi = true
			"RGBA":
				for i in range(1, 257):
					var r := f.get_8()
					var g := f.get_8()
					var b := f.get_8()
					f.get_8()
					if i < 256:
						out.palette[i] = Color8(r, g, b)
			"MATL":
				var mid := f.get_32()
				var d := _read_dict(f)
				matl_types[mid] = d.get("_type", "_diffuse")
				matl_rough[mid] = float(d.get("_rough", "1"))
		f.seek(start + content + children)
	for i in range(1, 256):
		var t: String = matl_types.get(i, "_diffuse")
		var m := MAT_OPAQUE
		if t == "_glass" or t == "_blend":
			m = MAT_WATER if (i >= WATER_START and i <= WATER_END) else MAT_GLASS
		elif t == "_emit":
			m = MAT_EMIT
		elif t == "_metal":
			m = MAT_PANEL if float(matl_rough.get(i, 1.0)) < 0.15 else MAT_METAL
		if i >= FLAG_START and i <= FLAG_END:
			m = MAT_FLAG
		out.materials[i] = m
	if not got_size:
		push_error("vox: %s contains no model" % path)
		return null
	return out


## Reads a MagicaVoxel DICT: a count followed by length-prefixed key/value strings.
static func _read_dict(f: FileAccess) -> Dictionary:
	var d := {}
	var n := f.get_32()
	for i in n:
		var k := f.get_buffer(f.get_32()).get_string_from_utf8()
		var v := f.get_buffer(f.get_32()).get_string_from_utf8()
		d[k] = v
	return d
