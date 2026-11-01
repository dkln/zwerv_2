@tool
extends RefCounted
## Reads a Goxel .gox file (the tile format of Zwervr) into a voxel model
## (voxel_model.gd). The format is that of Goxel's src/formats/gox.c, version 2:
## "GOX " + int32 version, then chunks of 4 bytes type, int32 length, the data and an
## int32 CRC (Goxel writes 0). Used chunks:
##   IMG   dict; "box": the image box (float[4][4], column-major: half sizes on the
##         diagonal, centre in column 3). It is the model size of the tile: voxel
##         positions count from its minimum corner, like the Size of a MagicaVoxel model.
##   BL16  16 x 16 x 16 RGBA voxels as a 64 x 64 PNG; voxel (x, y, z) of the block is
##         pixel x + 16 y + 256 z. Alpha below 127 is empty (as in Goxel's exports).
##   MATE  dict with the "name" of a Goxel material (index = order in the file).
##   LAYR  int32 block count, per block int32 BL16 index, x, y, z, 0; then a dict:
##         "name", "id", "base_id" (a clone of another layer), "mat" (the clone's
##         float[4][4] transform), "material" (MATE index), "visible", "shape".
## A dict is a list of int32 key length, key, int32 value length, value; a key
## length of 0 or the end of the chunk ends it.
##
## The visible layers are merged in file order, later layers on top (as Goxel does).
## A layer named after a material (voxel_model.gd MATERIAL_NAMES, e.g. "glass"), or
## whose Goxel material has such a name, forces that material on its voxels; other
## voxels get their material from their colour. Clone layers are supported, shape
## layers are not (turn them into a normal layer in Goxel).

const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")

const BLOCK := 16
const ALPHA_MIN := 127
## Model coordinates are stored in bytes (voxel_model.gd voxels).
const MAX_SIZE := 256


## Parses a .gox file; returns null (and reports an error) if it can't be read.
static func load_file(path: String) -> RefCounted:
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < 8 or data.slice(0, 4).get_string_from_ascii() != "GOX ":
		push_error("gox: %s is not a Goxel file" % path)
		return null
	var version := data.decode_s32(4)
	var blocks: Array[PackedByteArray] = []
	var mates: Array[String] = []
	var layers := []   # [refs (index, x, y, z per block), dict]
	var has_box := false
	var lo := Vector3i.ZERO
	var size := Vector3i.ZERO
	var pos := 8
	while pos + 8 <= data.size():
		var kind := data.slice(pos, pos + 4).get_string_from_ascii()
		var length := data.decode_s32(pos + 4)
		var body := data.slice(pos + 8, pos + 8 + length)
		pos += 12 + length
		match kind:
			"BL16":
				var img := Image.new()
				if img.load_png_from_buffer(body) != OK or img.get_width() != 64 or img.get_height() != 64:
					push_error("gox: %s: unreadable voxel block" % path)
					return null
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				blocks.append(img.get_data())
			"MATE":
				mates.append(_dict(body, 0).get("name", PackedByteArray()).get_string_from_utf8())
			"IMG ":
				var b: PackedByteArray = _dict(body, 0).get("box", PackedByteArray())
				if b.size() == 64 and b.decode_float(60) != 0.0:
					var c := Vector3(b.decode_float(48), b.decode_float(52), b.decode_float(56))
					var h := Vector3(absf(b.decode_float(0)), absf(b.decode_float(20)), absf(b.decode_float(40)))
					lo = Vector3i((c - h).round())
					size = Vector3i((c + h).round()) - lo
					has_box = size.x > 0 and size.y > 0 and size.z > 0
			"LAYR":
				var n := body.decode_s32(0)
				var refs := PackedInt32Array()
				var shift := 8 if version == 1 else 0   # version 1 stored block centres
				for k in n:
					var o := 4 + k * 20
					refs.append_array([body.decode_s32(o), body.decode_s32(o + 4) - shift,
						body.decode_s32(o + 8) - shift, body.decode_s32(o + 12) - shift])
				layers.append([refs, _dict(body, 4 + n * 20)])

	# voxels per layer: x, y, z, rgb (0xRRGGBB) in Goxel coordinates
	var by_id := {}
	var layer_voxels := []
	for layer in layers:
		var refs: PackedInt32Array = layer[0]
		var d: Dictionary = layer[1]
		var vox := PackedInt32Array()
		for k in range(0, refs.size(), 4):
			if refs[k] < 0 or refs[k] >= blocks.size():
				push_error("gox: %s: a layer refers to a missing block" % path)
				return null
			_append_block(vox, blocks[refs[k]], refs[k + 1], refs[k + 2], refs[k + 3])
		layer_voxels.append(vox)
		var id := _int(d, "id", 0)
		if id != 0 and _int(d, "base_id", 0) == 0:
			by_id[id] = vox
	var visible := []   # [voxels, forced material]
	for li in layers.size():
		var d: Dictionary = layers[li][1]
		var name: String = d.get("name", PackedByteArray()).get_string_from_utf8()
		var vox: PackedInt32Array = layer_voxels[li]
		var base := _int(d, "base_id", 0)
		if base != 0:
			vox = _clone(by_id.get(base, PackedInt32Array()), d.get("mat", PackedByteArray()))
		if d.has("shape"):
			push_warning("gox: %s: layer '%s' is a shape layer, skipped (make it a normal layer in Goxel)" % [path, name])
			continue
		var shown: PackedByteArray = d.get("visible", PackedByteArray([1]))
		if shown.size() > 0 and shown[0] == 0:
			continue
		var forced := Model.MATERIAL_NAMES.find(name)
		var mi := _int(d, "material", -1)
		if forced < 0 and mi >= 0 and mi < mates.size():
			forced = Model.MATERIAL_NAMES.find(mates[mi])
		visible.append([vox, forced])

	if not has_box:
		# no image box: the bounds of the voxels
		var first := true
		var hi := Vector3i.ZERO
		for v in visible:
			var vox: PackedInt32Array = v[0]
			for k in range(0, vox.size(), 4):
				var p := Vector3i(vox[k], vox[k + 1], vox[k + 2])
				lo = p if first else lo.min(p)
				hi = p if first else hi.max(p)
				first = false
		if first:
			push_error("gox: %s contains no voxels" % path)
			return null
		size = hi - lo + Vector3i.ONE
		push_warning("gox: %s has no image box; using the bounds of the voxels" % path)
	if size.x > MAX_SIZE or size.y > MAX_SIZE or size.z > MAX_SIZE:
		push_error("gox: %s: model of %s voxels is too big (at most %d per side)" % [path, size, MAX_SIZE])
		return null

	# merge the visible layers into one grid of keys (colour + forced material)
	var grid := PackedInt32Array()
	grid.resize(size.x * size.y * size.z)
	grid.fill(-1)
	var key_index := {}
	var keys := PackedInt32Array()
	var outside := 0
	for v in visible:
		var vox: PackedInt32Array = v[0]
		var forced: int = v[1]
		for k in range(0, vox.size(), 4):
			var x := vox[k] - lo.x
			var y := vox[k + 1] - lo.y
			var z := vox[k + 2] - lo.z
			if x < 0 or y < 0 or z < 0 or x >= size.x or y >= size.y or z >= size.z:
				outside += 1
				continue
			var key := vox[k + 3] * 16 + forced + 1
			var ki: int = key_index.get(key, -1)
			if ki < 0:
				ki = keys.size()
				key_index[key] = ki
				keys.append(key)
			grid[x + size.x * (y + size.y * z)] = ki
	if outside > 0:
		push_warning("gox: %s: %d voxels outside the image box, skipped" % [path, outside])

	# colour indices in order of first appearance (z, y, x), like a MagicaVoxel model
	var out = Model.new()
	out.size = size
	var slot_of := PackedInt32Array()
	slot_of.resize(keys.size())
	slot_of.fill(0)
	var slots := 0
	var too_many := 0
	var voxels := PackedByteArray()
	var i := 0
	for z in size.z:
		for y in size.y:
			for x in size.x:
				var ki := grid[i]
				i += 1
				if ki < 0:
					continue
				if slot_of[ki] == 0:
					var key := keys[ki]
					var rgb := key >> 4
					var col := Color8(rgb >> 16, (rgb >> 8) & 0xff, rgb & 0xff)
					var forced := (key & 15) - 1
					if slots < 255:
						slots += 1
						slot_of[ki] = slots
						out.palette[slots] = col
						out.layer_materials[slots] = forced
					else:
						slot_of[ki] = _nearest(out, slots, col, forced)
						too_many += 1
				voxels.append_array([x, y, z, slot_of[ki]])
	if too_many > 0:
		push_warning("gox: %s uses more than 255 colours; %d colours were replaced by the nearest one" % [path, too_many])
	out.voxels = voxels
	return out


## Appends the voxels of one BL16 block at Goxel position (bx, by, bz) to vox.
static func _append_block(vox: PackedInt32Array, block: PackedByteArray, bx: int, by: int, bz: int) -> void:
	for k in BLOCK * BLOCK * BLOCK:
		var o := k * 4
		if block[o + 3] >= ALPHA_MIN:
			vox.append_array([bx + (k & 15), by + ((k >> 4) & 15), bz + (k >> 8),
				(block[o] << 16) | (block[o + 1] << 8) | block[o + 2]])


## Voxels of a clone layer: those of its base layer, moved by the layer matrix (voxel
## centres are transformed; whole-voxel moves and quarter turns are exact).
static func _clone(src: PackedInt32Array, mat: PackedByteArray) -> PackedInt32Array:
	if mat.size() != 64:
		return src.duplicate()
	var f := func(k: int) -> float: return mat.decode_float(k * 4)
	var t := Transform3D(Vector3(f.call(0), f.call(1), f.call(2)), Vector3(f.call(4), f.call(5), f.call(6)),
		Vector3(f.call(8), f.call(9), f.call(10)), Vector3(f.call(12), f.call(13), f.call(14)))
	var out := PackedInt32Array()
	for k in range(0, src.size(), 4):
		var p := Vector3i((t * (Vector3(src[k], src[k + 1], src[k + 2]) + Vector3(0.5, 0.5, 0.5))).floor())
		out.append_array([p.x, p.y, p.z, src[k + 3]])
	return out


## The colour index (1..count) nearest to col with the same forced material, or 1.
static func _nearest(model, count: int, col: Color, forced: int) -> int:
	var best := 1
	var best_d := INF
	for s in range(1, count + 1):
		if model.layer_materials[s] != forced:
			continue
		var c: Color = model.palette[s]
		var d := (c.r - col.r) ** 2 + (c.g - col.g) ** 2 + (c.b - col.b) ** 2
		if d < best_d:
			best_d = d
			best = s
	return best


## An int32 dict value, or `default`.
static func _int(d: Dictionary, key: String, default: int) -> int:
	var v: PackedByteArray = d.get(key, PackedByteArray())
	return v.decode_s32(0) if v.size() == 4 else default


## Reads a Goxel dict from `pos`: key -> raw value bytes.
static func _dict(body: PackedByteArray, pos: int) -> Dictionary:
	var d := {}
	while pos + 4 <= body.size():
		var n := body.decode_s32(pos)
		if n <= 0:
			break
		var key := body.slice(pos + 4, pos + 4 + n).get_string_from_utf8()
		pos += 4 + n
		if pos + 4 > body.size():
			break
		var m := body.decode_s32(pos)
		d[key] = body.slice(pos + 4, pos + 4 + m)
		pos += 4 + m
	return d
