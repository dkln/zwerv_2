@tool
extends RefCounted
## Texture atlas of a MeshLibrary (one per library and LOD level).
##
## Textured tiles (vox_mesher.gd) carry their own small colour texture (meta "albedo",
## UV points into it). To merge thousands of tiles into a few meshes (layer_baker.gd)
## they must share materials, so build() packs all tile textures of a library into one
## atlas image and returns, per tile, a copy of its mesh with the UVs moved into the
## atlas and materials that sample it. Tiles without a texture (vertex colours) are
## returned unchanged.

const ATLAS_PARAM := "albedo_atlas"   # sampler uniform in the voxel shaders
const MAX_SIZE := 16384


## meshes: {key: ArrayMesh}. Returns {"meshes": {key: ArrayMesh}, "texture": ImageTexture
## or null, "size": Vector2i}. Materials are duplicated once per base material and
## shared by every tile of this atlas.
static func build(meshes: Dictionary) -> Dictionary:
	var images := {}
	for key in meshes:
		var m: Mesh = meshes[key]
		if m != null and m.has_meta("albedo"):
			images[key] = m.get_meta("albedo")
	var out := {}
	if images.is_empty():
		for key in meshes:
			out[key] = meshes[key]
		return {"meshes": out, "texture": null, "size": Vector2i.ZERO}
	var layout := _pack(images)
	var size: Vector2i = layout.size
	var atlas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for key in images:
		var img: Image = images[key]
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), layout.positions[key])
	# no mipmaps: from afar the shader uses each face's average colour instead
	# (voxel_colour.gdshaderinc), so neighbouring tiles never bleed into each other
	var texture := ImageTexture.create_from_image(atlas)
	var materials := {}   # base material -> copy that samples this atlas
	for key in meshes:
		var m: ArrayMesh = meshes[key]
		if images.has(key):
			out[key] = _remap(m, layout.positions[key], images[key].get_size(), size, texture, materials)
		else:
			out[key] = m
	return {"meshes": out, "texture": texture, "size": size}


## Shelf packing: images sorted by height, rows left to right. Returns
## {"positions": {key: Vector2i}, "size": Vector2i}.
static func _pack(images: Dictionary) -> Dictionary:
	var keys := images.keys()
	keys.sort_custom(func(p, q): return images[p].get_height() > images[q].get_height())
	var area := 0
	var widest := 0
	for key in keys:
		area += images[key].get_width() * images[key].get_height()
		widest = maxi(widest, images[key].get_width())
	# rows about as wide as the square root of the area; exact height (no power of two)
	var width := mini(MAX_SIZE, maxi(widest, ceili(sqrt(area * 1.08))))
	var positions := {}
	var x := 0
	var y := 0
	var row := 0
	for key in keys:
		var s: Vector2i = images[key].get_size()
		if x + s.x > width:
			x = 0
			y += row
			row = 0
		positions[key] = Vector2i(x, y)
		x += s.x
		row = maxi(row, s.y)
	var height := y + row
	if height > MAX_SIZE:
		push_error("Vox Tiles: texture atlas too large (%d x %d)" % [width, height])
	return {"positions": positions, "size": Vector2i(width, height)}


## Copy of `mesh` with its UVs (0..1 within its own texture of `own` texels) moved to
## `pos` in an atlas of `atlas` texels, and materials that sample `texture`.
static func _remap(mesh: ArrayMesh, pos: Vector2i, own: Vector2i, atlas: Vector2i, texture: Texture2D,
		materials: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.resource_name = mesh.resource_name
	var offset := Vector2(pos) / Vector2(atlas)
	var scale := Vector2(own) / Vector2(atlas)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uv.size():
			uv[i] = offset + uv[i] * scale
		arrays[Mesh.ARRAY_TEX_UV] = uv
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_name(s, mesh.surface_get_name(s))
		out.surface_set_material(s, _atlas_material(mesh.surface_get_material(s), texture, materials))
	for meta in ["face_ranges", "solid_faces"]:
		if mesh.has_meta(meta):
			out.set_meta(meta, mesh.get_meta(meta))
	return out


## The copy of `base` that samples `texture` (made once per base material).
static func _atlas_material(base: Material, texture: Texture2D, materials: Dictionary) -> Material:
	if base == null:
		return null
	if not materials.has(base):
		var copy: Material = base.duplicate()
		# the copy has no path; layer_baker.gd recognises materials by their base path
		copy.set_meta("base_path", base.resource_path)
		if copy is ShaderMaterial:
			copy.set_shader_parameter(ATLAS_PARAM, texture)
			copy.set_shader_parameter("use_atlas", true)
		materials[base] = copy
	return materials[base]
