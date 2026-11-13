extends RefCounted
## Unit tests of importing a Goxel tile (.gox) into a Godot mesh: the parser
## (addons/vox_tiles/importer/gox_parser.gd, via voxel_model.gd load_file) and the mesher
## (vox_mesher.gd). Each test writes a small .gox of its own (write_gox, the format of
## Goxel's gox.c version 2: an image box, 16^3 blocks as PNG, layers), so it does not hang on
## the tiles in the game.
## The merging: neighbouring voxel faces with the same colour and material (and the same
## ambient occlusion in their corners) become one face; faces between two voxels are not
## drawn; another material is never merged in; textured tiles merge regardless of colour.

const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")
const Mesher = preload("res://addons/vox_tiles/importer/vox_mesher.gd")

const VOXEL_SIZE := 0.125
## Colours that are not in the colour table (assets/tiles/materialen.json): plain opaque.
const PURPLE := Color8(0x7B, 0x3F, 0x91)
const GREEN := Color8(0x2E, 0x8B, 0x57)
## Within the mesher's colour merging of PURPLE (14 of 255 per channel), and far from it.
const PURPLE_NEARLY := Color8(0x7F, 0x42, 0x94)
const TEST_FILE := "user://unit_test_tile.gox"
const TILES := "res://assets/tiles/"


# ------------------------------------------------------------------ reading

## A .gox is read: the size from the image box, the voxels at their places in their
## colours, a plain colour opaque.
func test_the_voxels_are_read_with_their_colours(test) -> void:
	var model := _load({"": {Vector3i(0, 0, 0): PURPLE, Vector3i(2, 1, 3): GREEN}}, Vector3i(4, 2, 4))
	test.check(model != null, "het bestand is te lezen")
	if model == null:
		return
	test.check(model.size == Vector3i(4, 2, 4), "de maat uit het beeldvak (%s)" % model.size)
	var found := _voxels_of(model)
	test.check(found.size() == 2, "twee voxels (%d)" % found.size())
	test.check(found.get(Vector3i(0, 0, 0), Color.BLACK) == PURPLE, "paars op 0,0,0")
	test.check(found.get(Vector3i(2, 1, 3), Color.BLACK) == GREEN, "groen op 2,1,3")
	test.check(model.materials[_index_of(model, PURPLE)] == Model.MAT_OPAQUE, "een gewone kleur is dicht")


## The voxels of a layer named glass become glass, those of other layers do not.
func test_a_layer_named_glass_makes_its_voxels_glass(test) -> void:
	var model := _load({"": {Vector3i(0, 0, 0): PURPLE}, "glass": {Vector3i(1, 0, 0): GREEN}}, Vector3i(2, 1, 1))
	test.check(model != null, "het bestand is te lezen")
	if model == null:
		return
	test.check(model.materials[_index_of(model, GREEN)] == Model.MAT_GLASS, "de laag glass maakt glas")
	test.check(model.materials[_index_of(model, PURPLE)] == Model.MAT_OPAQUE, "de andere laag niet")


## A hidden layer is not read: only the voxels of the visible one.
func test_a_hidden_layer_is_left_out(test) -> void:
	var model := _load({"": {Vector3i(0, 0, 0): PURPLE}, "verborgen": {Vector3i(1, 0, 0): GREEN}},
		Vector3i(2, 1, 1), ["verborgen"])
	test.check(model != null and _voxels_of(model).size() == 1, "alleen de zichtbare laag")


## Where two layers have a voxel in the same place the later layer wins.
func test_a_later_layer_lies_on_top(test) -> void:
	var model := _load({"": {Vector3i(0, 0, 0): PURPLE}, "erover": {Vector3i(0, 0, 0): GREEN}}, Vector3i(1, 1, 1))
	test.check(model != null and _voxels_of(model).get(Vector3i(0, 0, 0)) == GREEN, "de latere laag wint")


## A model wider than one 16^3 block is read whole, across the blocks.
func test_voxels_in_more_blocks_are_all_read(test) -> void:
	# 20 voxels wide: two blocks of 16
	var row := {}
	for x in 20:
		row[Vector3i(x, 0, 0)] = PURPLE
	var model := _load({"": row}, Vector3i(20, 1, 1))
	test.check(model != null and _voxels_of(model).size() == 20, "20 voxels over twee blokken")


## A file without the GOX header is not read.
func test_not_a_gox_file_is_refused(test) -> void:
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_string("geen goxel")
	file.close()
	test.check(Model.load_file(TEST_FILE) == null, "geen GOX-kop: niet gelezen")


# ------------------------------------------------------------------ into a Godot mesh

## The mesh is turned from Goxel's z-up to Godot's y-up, centred in x and z and standing
## on y = 0, one opaque surface.
func test_the_mesh_stands_on_the_ground_centred(test) -> void:
	var mesh := _mesh(_box(Vector3i(0, 0, 0), Vector3i(3, 1, 1), PURPLE), Vector3i(4, 2, 2), false)
	var bounds := mesh.get_aabb()
	# Goxel x, y, z-up -> Godot x, z, -y; centred in x and z, standing on y = 0
	test.check(bounds.position.is_equal_approx(Vector3(-0.25, 0.0, -0.125)), "de hoek (%s)" % bounds.position)
	test.check(bounds.size.is_equal_approx(Vector3(4, 2, 2) * VOXEL_SIZE), "de maat (%s)" % bounds.size)
	test.check(mesh.get_surface_count() == 1 and mesh.surface_get_name(0) == "opaque", "één vlak, dicht")


## Every face's normal points away from the middle and its triangles wind so that it is
## seen from outside.
func test_the_faces_point_outwards(test) -> void:
	var mesh := _mesh(_box(Vector3i(0, 0, 0), Vector3i(1, 1, 1), PURPLE), Vector3i(2, 2, 2), false)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var middle := mesh.get_aabb().get_center()
	var outward := true
	for triangle in range(0, vertices.size(), 3):
		var centre := (vertices[triangle] + vertices[triangle + 1] + vertices[triangle + 2]) / 3.0
		var drawn := (vertices[triangle + 1] - vertices[triangle]).cross(vertices[triangle + 2] - vertices[triangle])
		var normal := normals[triangle]
		# the normal points away from the middle; Godot draws clockwise triangles as the front
		outward = outward and normal.dot(centre - middle) > 0.0 and drawn.dot(normal) < 0.0
	test.check(outward, "elk vlak wijst naar buiten en is van buiten te zien")


# ------------------------------------------------------------------ merging

## A block of one colour merges into six faces, one per side.
func test_a_block_of_one_colour_is_six_faces(test) -> void:
	# 4 x 3 x 2 voxels of one colour: each side one face, nothing inside
	var voxels := _box(Vector3i(0, 0, 0), Vector3i(3, 2, 1), PURPLE)
	for textured in [false, true]:
		var mesh := _mesh(voxels, Vector3i(4, 3, 2), textured)
		test.check(_faces(mesh) == 6, "6 vlakken (%s: %d)" % ["textuur" if textured else "kleur", _faces(mesh)])


## No face is drawn between two voxels: none through the middle of a block.
func test_faces_between_voxels_are_not_drawn(test) -> void:
	var mesh := _mesh(_box(Vector3i(0, 0, 0), Vector3i(1, 1, 1), PURPLE), Vector3i(2, 2, 2), false, false)
	var arrays := mesh.surface_get_arrays(0)
	var middle := mesh.get_aabb().get_center()
	var inside := false
	for vertex in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		inside = inside or vertex.is_equal_approx(middle)
	test.check(not inside, "geen vlak door het midden van het blok")
	test.check(_faces(mesh) == 6, "6 vlakken (%d)" % _faces(mesh))


## With vertex colours two colours are not merged: a row of two colours splits its long
## sides in two.
func test_two_colours_stay_apart_in_vertex_colours(test) -> void:
	# a row of 4: two purple, two green; the top, bottom and long sides split in two
	var voxels := _box(Vector3i(0, 0, 0), Vector3i(1, 0, 0), PURPLE)
	voxels.merge(_box(Vector3i(2, 0, 0), Vector3i(3, 0, 0), GREEN))
	var mesh := _mesh(voxels, Vector3i(4, 1, 1), false)
	test.check(_faces(mesh) == 10, "4 zijden in twee, 2 kopse kanten: 10 vlakken (%d)" % _faces(mesh))


## A textured tile merges faces whatever their colours: one per side, the colours per
## voxel in a texture.
func test_textured_tiles_merge_whatever_the_colour(test) -> void:
	var voxels := _box(Vector3i(0, 0, 0), Vector3i(1, 0, 0), PURPLE)
	voxels.merge(_box(Vector3i(2, 0, 0), Vector3i(3, 0, 0), GREEN))
	var mesh := _mesh(voxels, Vector3i(4, 1, 1), true)
	test.check(_faces(mesh) == 6, "één vlak per zijde, de kleuren in de textuur (%d)" % _faces(mesh))
	var albedo: Image = mesh.get_meta("albedo", null)
	test.check(albedo != null, "de kleuren per voxel in een textuur")


## Colours within the colour margin of each other merge into one face per side.
func test_nearly_the_same_colour_merges(test) -> void:
	var voxels := _box(Vector3i(0, 0, 0), Vector3i(1, 0, 0), PURPLE)
	voxels.merge(_box(Vector3i(2, 0, 0), Vector3i(3, 0, 0), PURPLE_NEARLY))
	var mesh := _mesh(voxels, Vector3i(4, 1, 1), false)
	test.check(_faces(mesh) == 6, "binnen de kleurmarge één vlak per zijde (%d)" % _faces(mesh))


## Glass next to the same colour opaque is never merged in: a surface of its own, and the
## opaque half keeps its side against the glass.
func test_another_material_is_never_merged_in(test) -> void:
	# the same colour, the right half in a glass layer
	var model := _load({"": _box(Vector3i(0, 0, 0), Vector3i(1, 0, 0), PURPLE),
		"glass": _box(Vector3i(2, 0, 0), Vector3i(3, 0, 0), PURPLE)}, Vector3i(4, 1, 1))
	test.check(model != null, "het bestand is te lezen")
	if model == null:
		return
	for textured in [false, true]:
		var mesh := Mesher.build(model, VOXEL_SIZE, true, 14, "", Vector3.ZERO, textured)
		var names := []
		for surface in mesh.get_surface_count():
			names.append(mesh.surface_get_name(surface))
		test.check("opaque" in names and "glass" in names, "een eigen vlak voor glas (%s)" % [names])
		var opaque_faces := 0
		for surface in mesh.get_surface_count():
			if mesh.surface_get_name(surface) == "opaque":
				opaque_faces += mesh.surface_get_array_len(surface) / 6
		# against glass the opaque half still shows its side: 5 faces, each one piece
		test.check(opaque_faces == 6, "de dichte helft: 6 vlakken (%d)" % opaque_faces)


## Faces whose corners differ in ambient occlusion are not merged: more pieces with AO
## than without.
func test_different_shading_in_a_corner_is_not_merged(test) -> void:
	# a slab of 4 x 4 with a voxel standing on it: the slab's top darkens round its foot
	var voxels := _box(Vector3i(0, 0, 0), Vector3i(3, 3, 0), PURPLE)
	voxels[Vector3i(1, 1, 1)] = PURPLE
	var with_shading := _mesh(voxels, Vector3i(4, 4, 2), false, true)
	var without := _mesh(voxels, Vector3i(4, 4, 2), false, false)
	test.check(_faces(with_shading) > _faces(without), "met AO meer stukken (%d > %d)" % [_faces(with_shading), _faces(without)])
	# without AO: the slab's top round the foot in 4 pieces, its other 5 sides one each, the
	# voxel on top 5 faces
	test.check(_faces(without) == 14, "zonder AO 14 vlakken (%d)" % _faces(without))


## Real tiles of the game (one per kind) read and merge into at most half as many faces
## as they have voxel sides against the air.
func test_real_tiles_have_far_fewer_faces_than_voxel_sides(test) -> void:
	# a tile from each kind of tile (assets/tiles/<kind>/): merged into at most half as many
	# faces as there are voxel sides against the air
	var paths := _some_tiles()
	test.check(not paths.is_empty(), "er zijn tiles in assets/tiles")
	for path in paths:
		var model := Model.load_file(path)
		test.check(model != null, "%s is te lezen" % path.get_file())
		if model == null:
			continue
		var mesh := Mesher.build(model, VOXEL_SIZE, true, 14, "", Vector3.ZERO, true)
		var open_sides := _open_sides(model)
		test.check(_faces(mesh) * 2 <= open_sides, "%s: %d vlakken voor %d open voxelzijden" % [path.get_file(), _faces(mesh), open_sides])


# ------------------------------------------------------------------ helpers

## Writes a .gox (Goxel 2) with these layers (name -> {Vector3i: Color}; "" a plain layer) in an
## image box of `size` from 0, `hidden` layers not visible, and loads it (voxel_model.gd).
func _load(layers: Dictionary, size: Vector3i, hidden: Array = []) -> RefCounted:
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_buffer(write_gox(layers, size, hidden))
	file.close()
	return Model.load_file(TEST_FILE)


func _mesh(voxels: Dictionary, size: Vector3i, textured: bool, ambient_occlusion := true) -> ArrayMesh:
	var model := _load({"": voxels}, size)
	return Mesher.build(model, VOXEL_SIZE, ambient_occlusion, 14, "", Vector3.ZERO, textured)


## The rectangles drawn (two triangles, six vertices each).
func _faces(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += mesh.surface_get_array_len(surface) / 6
	return count


func _box(from: Vector3i, to: Vector3i, colour: Color) -> Dictionary:
	var voxels := {}
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			for z in range(from.z, to.z + 1):
				voxels[Vector3i(x, y, z)] = colour
	return voxels


func _voxels_of(model) -> Dictionary:
	var found := {}
	var data: PackedByteArray = model.voxels
	for at in range(0, data.size(), 4):
		found[Vector3i(data[at], data[at + 1], data[at + 2])] = model.palette[data[at + 3]]
	return found


func _index_of(model, colour: Color) -> int:
	for index in range(1, 256):
		if model.palette[index] == colour:
			return index
	return 0


## Voxel sides against empty space: what a mesh without merging would draw.
func _open_sides(model) -> int:
	var cells := _voxels_of(model)
	var sides := 0
	for cell: Vector3i in cells:
		for step: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]:
			if not cells.has(cell + step):
				sides += 1
	return sides


## The first tile (not a hand-made coarse version) of each kind, in assets/tiles/<kind>/ or
## the folders under it.
func _some_tiles() -> Array[String]:
	var paths: Array[String] = []
	for kind in DirAccess.get_directories_at(TILES):
		var path := _first_tile(TILES + kind + "/")
		if path != "":
			paths.append(path)
	return paths


func _first_tile(folder: String) -> String:
	for file_name in DirAccess.get_files_at(folder):
		if (file_name.ends_with(".vox") or file_name.ends_with(".gox")) and not file_name.get_basename().ends_with(".lod"):
			return folder + file_name
	for sub in DirAccess.get_directories_at(folder):
		var path := _first_tile(folder + sub + "/")
		if path != "":
			return path
	return ""


## A Goxel file (version 2): the image box, one BL16 block (a 64 x 64 PNG) per 16^3 of
## voxels used, and per layer its blocks and a dict with its name and whether it is visible.
static func write_gox(layers: Dictionary, size: Vector3i, hidden: Array = []) -> PackedByteArray:
	var out := PackedByteArray("GOX ".to_ascii_buffer())
	out.append_array(_int32(2))
	var box := PackedByteArray()
	box.resize(64)
	box.encode_float(0, size.x * 0.5)
	box.encode_float(20, size.y * 0.5)
	box.encode_float(40, size.z * 0.5)
	box.encode_float(48, size.x * 0.5)
	box.encode_float(52, size.y * 0.5)
	box.encode_float(56, size.z * 0.5)
	box.encode_float(60, 1.0)
	out.append_array(_chunk("IMG ", _dict({"box": box})))
	var block_count := 0
	var layer_chunks := []
	for layer_name: String in layers:
		var by_block := {}   # block corner -> 16^3 RGBA bytes
		for cell: Vector3i in layers[layer_name]:
			var corner := Vector3i(floori(cell.x / 16.0), floori(cell.y / 16.0), floori(cell.z / 16.0)) * 16
			if not by_block.has(corner):
				var empty := PackedByteArray()
				empty.resize(16 * 16 * 16 * 4)
				by_block[corner] = empty
			var local := cell - corner
			var offset := (local.x + 16 * local.y + 256 * local.z) * 4
			var colour: Color = layers[layer_name][cell]
			var bytes: PackedByteArray = by_block[corner]
			bytes[offset] = colour.r8
			bytes[offset + 1] = colour.g8
			bytes[offset + 2] = colour.b8
			bytes[offset + 3] = 255
			by_block[corner] = bytes
		var layer := _int32(by_block.size())
		for corner: Vector3i in by_block:
			var image := Image.create_from_data(64, 64, false, Image.FORMAT_RGBA8, by_block[corner])
			out.append_array(_chunk("BL16", image.save_png_to_buffer()))
			for number in [block_count, corner.x, corner.y, corner.z, 0]:
				layer.append_array(_int32(number))
			block_count += 1
		layer.append_array(_dict({"name": (layer_name if layer_name != "" else "laag").to_utf8_buffer(),
			"visible": PackedByteArray([0 if layer_name in hidden else 1])}))
		layer_chunks.append(_chunk("LAYR", layer))
	for layer_chunk: PackedByteArray in layer_chunks:
		out.append_array(layer_chunk)
	return out


static func _chunk(kind: String, body: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray(kind.to_ascii_buffer())
	out.append_array(_int32(body.size()))
	out.append_array(body)
	out.append_array(_int32(0))   # the CRC: Goxel writes 0 too
	return out


static func _dict(entries: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	for key: String in entries:
		var value: PackedByteArray = entries[key]
		out.append_array(_int32(key.length()))
		out.append_array(key.to_ascii_buffer())
		out.append_array(_int32(value.size()))
		out.append_array(value)
	out.append_array(_int32(0))
	return out


static func _int32(number: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, number)
	return out
