@tool
extends RefCounted
## Reads a MagicaVoxel .vox file into a voxel model (voxel_model.gd): the first model,
## the palette and, as rule 4 of the materials, what the MATL chunks say (glass,
## emit, metal). Zwervr's tiles are Goxel files (gox_parser.gd); .vox stays readable
## for tiles made in MagicaVoxel and for tools/voxgen/convert_vox.py.

const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")


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
	var out = Model.new()
	out.indexed = true
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
		match matl_types.get(i, "_diffuse"):
			"_glass", "_blend":
				out.file_materials[i] = Model.MAT_GLASS
			"_emit":
				out.file_materials[i] = Model.MAT_EMIT
			"_metal":
				out.file_materials[i] = Model.MAT_PANEL if float(matl_rough.get(i, 1.0)) < 0.15 else Model.MAT_METAL
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
