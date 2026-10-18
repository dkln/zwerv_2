@tool
extends RefCounted
## Leest een MagicaVoxel .vox bestand (eerste model + palet + materialen).

const MAT_OPAQUE := 0
const MAT_METAL := 1
const MAT_GLASS := 2
const MAT_EMIT := 3
const MAT_WATER := 4
const MAT_FLAG := 5

## Palet-indices die als water worden behandeld (glas-materiaal in MagicaVoxel).
const WATER_START := 225
const WATER_END := 232
## Palet-indices die als wapperende vlag worden behandeld.
const FLAG_START := 233
const FLAG_END := 248

var size := Vector3i.ZERO
var voxels := PackedByteArray()   # x, y, z, kleurindex (4 bytes per voxel)
var palette := PackedColorArray()  # index 0..255 (0 = leeg)
var materials := PackedByteArray() # materiaal per kleurindex


static func load_file(path: String) -> RefCounted:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("vox: kan %s niet openen" % path)
		return null
	if f.get_buffer(4).get_string_from_ascii() != "VOX ":
		push_error("vox: %s is geen MagicaVoxel bestand" % path)
		return null
	f.get_32() # versie
	var out = load("res://addons/vox_tiles/vox_parser.gd").new()
	out.palette.resize(256)
	out.materials.resize(256)
	for i in 256:
		out.palette[i] = Color(0.6, 0.6, 0.6)
	var got_size := false
	var got_xyzi := false
	var matl_types := {}
	while f.get_position() < f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var content := f.get_32()
		var children := f.get_32()
		var start := f.get_position()
		match id:
			"MAIN":
				continue # kinderen volgen direct
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
		f.seek(start + content + children)
	for i in range(1, 256):
		var t: String = matl_types.get(i, "_diffuse")
		var m := MAT_OPAQUE
		if t == "_glass" or t == "_blend":
			m = MAT_WATER if (i >= WATER_START and i <= WATER_END) else MAT_GLASS
		elif t == "_emit":
			m = MAT_EMIT
		elif t == "_metal":
			m = MAT_METAL
		if i >= FLAG_START and i <= FLAG_END:
			m = MAT_FLAG
		out.materials[i] = m
	if not got_size:
		push_error("vox: %s bevat geen model" % path)
		return null
	return out


static func _read_dict(f: FileAccess) -> Dictionary:
	var d := {}
	var n := f.get_32()
	for i in n:
		var k := f.get_buffer(f.get_32()).get_string_from_utf8()
		var v := f.get_buffer(f.get_32()).get_string_from_utf8()
		d[k] = v
	return d
